const {
  onCall,
  onRequest,
  HttpsError,
} = require("firebase-functions/v2/https");

const REGION = "us-central1";
const MODEL = "gemini-2.5-flash";
const SUPPORTED_SPOKEN_LANGUAGES =
  "Arabic, including Palestinian or Levantine dialects, Hebrew, English, " +
  "and code-switched mixtures of these languages";

exports.aiTranscribeAndParse = onCall(
  {
    region: REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    secrets: ["GEMINI_API_KEY"],
  },
  async (request) => handleAiTranscribeAndParse(request.data)
);

exports.aiTranscribeAndParseHttp = onRequest(
  {
    region: REGION,
    timeoutSeconds: 120,
    memory: "512MiB",
    secrets: ["GEMINI_API_KEY"],
  },
  async (request, response) => {
    response.set("Access-Control-Allow-Origin", "*");
    response.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    response.set("Access-Control-Allow-Methods", "POST, OPTIONS");

    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    if (request.method !== "POST") {
      response.status(405).json({ error: "Method not allowed." });
      return;
    }

    try {
      const result = await handleAiTranscribeAndParse(request.body || {});
      response.status(200).json(result);
    } catch (error) {
      const message =
        error instanceof HttpsError ? error.message : String(error.message || error);
      response.status(400).json({ error: message });
    }
  }
);

async function handleAiTranscribeAndParse(data) {
  const audioBase64 = data?.audioBase64;
  const mimeType = data?.mimeType || "audio/mp4";
  const languageHint =
    typeof data?.languageHint === "string" && data.languageHint.trim()
      ? data.languageHint.trim()
      : null;

  if (!audioBase64 || typeof audioBase64 !== "string") {
    throw new HttpsError("invalid-argument", "Missing audioBase64.");
  }

  const geminiApiKey = process.env.GEMINI_API_KEY;
  if (!geminiApiKey) {
    throw new HttpsError(
      "failed-precondition",
      "GEMINI_API_KEY is not configured on the server."
    );
  }

  const languageContext = languageHint
    ? `The app UI language is ${languageHint}; use it only as weak UI context, ` +
      "not as proof of the spoken language. "
    : "";

  const prompt =
    "You receive spoken gift-event audio. First infer the spoken language from " +
    `the audio itself. Supported speech may be ${SUPPORTED_SPOKEN_LANGUAGES}. ` +
    languageContext +
    "Do not translate the transcript; write it in the original spoken language " +
    "and script. Preserve Arabic names in Arabic script when spoken in Arabic, " +
    "Hebrew names in Hebrew script when spoken in Hebrew, and English names in " +
    "Latin script when spoken in English. If the speaker mixes Arabic, Hebrew, " +
    "and English, preserve the mixed-language transcript and still extract the " +
    "gift fields. Return strict JSON only with keys: transcript, entries, guest, " +
    "gift_description, amount, currency_code, money_items, occasion, event_date. " +
    "If the audio mentions multiple gift givers, put one object per giver in " +
    "entries. Each entries object uses the same field names: guest, " +
    "gift_description, amount, currency_code, money_items, occasion, event_date. " +
    "For example, 'Yossi gave 500, Danny 300, and Ronit a mixer' should produce " +
    "three entries. Also fill the top-level guest/gift fields with the first " +
    "entry for backward compatibility. " +
    "Rules: guest is the gift giver name only when a clear giver name was " +
    "actually spoken. Do not infer, invent, or use placeholders such as Unknown; " +
    "if no giver name is spoken, set guest to an empty string. " +
    "gift_description is the gift or note. " +
    "If there is one monetary amount, set amount and currency_code. If there " +
    "are multiple monetary amounts, set money_items to an array of objects " +
    "with amount and currency_code for each amount, and set amount/currency_code " +
    "to the first item for backward compatibility. amount values must be numeric. " +
    "If a monetary amount is spoken without an explicit currency, default " +
    "currency_code to ILS. " +
    "Normalize spoken currencies to currency_code only ILS, USD, EUR, or null, including shekel/shekels, " +
    "שקל/שקלים, شيكل/شواكل, dollar/dollars, دولار, euro/euros, and يورو. " +
    "event_date must be YYYY-MM-DD or null. occasion should be a short event " +
    "context or empty string.";

  const geminiResponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiApiKey,
      },
      body: JSON.stringify({
        generationConfig: {
          temperature: 0.1,
          responseMimeType: "application/json",
        },
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inlineData: {
                  mimeType,
                  data: audioBase64,
                },
              },
            ],
          },
        ],
      }),
    }
  );

  const responseBody = await geminiResponse.json();
  if (!geminiResponse.ok) {
    throw new HttpsError(
      "internal",
      `Gemini request failed: ${JSON.stringify(responseBody)}`
    );
  }

  const content =
    responseBody?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || "";
  if (!content) {
    throw new HttpsError("internal", "Gemini returned empty content.");
  }

  let parsedJson;
  try {
    parsedJson = JSON.parse(content);
  } catch (error) {
    throw new HttpsError(
      "internal",
      `Gemini returned invalid JSON: ${content}`
    );
  }

  const transcript = String(parsedJson.transcript || "").trim();
  const entries = parseGiftEntries(parsedJson);
  const parsed = entries[0] || parseGiftFields(parsedJson);
  if (!transcript && !parsed && entries.length === 0) {
    throw new HttpsError(
      "internal",
      "Gemini returned no usable transcript or structured fields."
    );
  }

  return {
    provider: "Gemini",
    transcript,
    parsed,
    entries,
  };
}

function parseGiftEntries(raw) {
  if (!raw || typeof raw !== "object" || !Array.isArray(raw.entries)) {
    return [];
  }

  return raw.entries
    .map((entry) => parseGiftFields(entry))
    .filter((entry) => {
      if (!entry) return false;
      const hasGift =
        entry.gift_description ||
        entry.amount !== null ||
        entry.money_items.length > 0;
      return entry.guest || hasGift;
    });
}

function parseGiftFields(raw) {
  if (!raw || typeof raw !== "object") {
    return null;
  }

  const amount =
    raw.amount === null || raw.amount === undefined || raw.amount === ""
      ? null
      : Number(raw.amount);
  const normalizedAmount = Number.isFinite(amount) ? amount : null;

  const currencyCode = normalizeCurrency(raw.currency_code);
  const eventDate = normalizeDate(raw.event_date);
  const moneyItems = normalizeMoneyItems(raw.money_items);

  return {
    guest: String(raw.guest || "").trim(),
    gift_description: String(raw.gift_description || "").trim(),
    amount: normalizedAmount,
    currency_code: currencyCode,
    money_items: moneyItems,
    occasion: String(raw.occasion || "").trim(),
    event_date: eventDate,
  };
}

function normalizeMoneyItems(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => {
      if (!item || typeof item !== "object") {
        return null;
      }
      const amount =
        item.amount === null || item.amount === undefined || item.amount === ""
          ? null
          : Number(item.amount);
      const normalizedAmount = Number.isFinite(amount) ? amount : null;
      const currencyCode = normalizeCurrency(item.currency_code);
      if (normalizedAmount === null || !currencyCode) {
        return null;
      }
      return {
        amount: normalizedAmount,
        currency_code: currencyCode,
      };
    })
    .filter(Boolean);
}

function normalizeCurrency(value) {
  const normalized = String(value || "")
    .trim()
    .toUpperCase();
  return ["ILS", "USD", "EUR"].includes(normalized) ? normalized : null;
}

function normalizeDate(value) {
  if (value === null || value === undefined) {
    return null;
  }
  const normalized = String(value).trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(normalized) ? normalized : null;
}

const {
  onCall,
  onRequest,
  HttpsError,
} = require("firebase-functions/v2/https");

const REGION = "us-central1";
const MODEL = "gemini-2.0-flash";

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

  const prompt =
    "You receive spoken gift-event audio. Return strict JSON only with keys: " +
    "transcript, guest, gift_description, amount, currency_code, occasion, event_date. " +
    "Rules: guest is giver name. amount numeric or null. " +
    "currency_code only ILS, USD, EUR, or null. " +
    "event_date must be YYYY-MM-DD or null. " +
    "occasion should be a short event context or empty string. " +
    "Keep person names in their original language. " +
    "Languages may include Arabic, Hebrew, or English." +
    (languageHint ? ` Prefer language hint: ${languageHint}.` : "");

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
  const parsed = parseGiftFields(parsedJson);
  if (!transcript && !parsed) {
    throw new HttpsError(
      "internal",
      "Gemini returned no usable transcript or structured fields."
    );
  }

  return {
    provider: "Gemini",
    transcript,
    parsed,
  };
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

  return {
    guest: String(raw.guest || "").trim(),
    gift_description: String(raw.gift_description || "").trim(),
    amount: normalizedAmount,
    currency_code: currencyCode,
    occasion: String(raw.occasion || "").trim(),
    event_date: eventDate,
  };
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:csv/csv.dart' show ListToCsvConverter;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

final List<String> _supportedInterfaceLanguageCodes = (() {
  final set = <String>{};
  for (final code in kMaterialSupportedLanguages) {
    set.add(code);
  }
  final list = set.toList()..sort();
  return list;
})();

final List<Locale> _supportedMaterialLocales = _supportedInterfaceLanguageCodes
    .map(Locale.new)
    .toList();

bool _isRtlLanguage(String code) {
  switch (code) {
    case 'ar':
    case 'fa':
    case 'he':
    case 'ps':
    case 'ur':
      return true;
    default:
      return false;
  }
}

String _languageDisplayName(String code) {
  const names = <String, String>{
    'af': 'Afrikaans',
    'am': 'አማርኛ',
    'ar': 'العربية',
    'as': 'অসমীয়া',
    'az': 'Azərbaycanca',
    'be': 'Беларуская',
    'bg': 'Български',
    'bn': 'বাংলা',
    'bs': 'Bosanski',
    'ca': 'Català',
    'cs': 'Čeština',
    'da': 'Dansk',
    'de': 'Deutsch',
    'el': 'Ελληνικά',
    'en': 'English',
    'es': 'Español',
    'et': 'Eesti',
    'eu': 'Euskara',
    'fa': 'فارسی',
    'fi': 'Suomi',
    'fil': 'Filipino',
    'fr': 'Français',
    'gl': 'Galego',
    'gsw': 'Schwiizertüütsch',
    'gu': 'ગુજરાતી',
    'he': 'עברית',
    'hi': 'हिन्दी',
    'hr': 'Hrvatski',
    'hu': 'Magyar',
    'hy': 'Հայերեն',
    'id': 'Indonesia',
    'is': 'Íslenska',
    'it': 'Italiano',
    'ja': '日本語',
    'ka': 'ქართული',
    'kk': 'Қазақша',
    'km': 'ខ្មែរ',
    'kn': 'ಕನ್ನಡ',
    'ko': '한국어',
    'ky': 'Кыргызча',
    'lo': 'ລາວ',
    'lt': 'Lietuvių',
    'lv': 'Latviešu',
    'mk': 'Македонски',
    'ml': 'മലയാളം',
    'mn': 'Монгол',
    'mr': 'मराठी',
    'ms': 'Melayu',
    'my': 'မြန်မာ',
    'nb': 'Norsk bokmål',
    'ne': 'नेपाली',
    'nl': 'Nederlands',
    'no': 'Norsk',
    'or': 'ଓଡ଼ିଆ',
    'pa': 'ਪੰਜਾਬੀ',
    'pl': 'Polski',
    'ps': 'پښتو',
    'pt': 'Português',
    'ro': 'Română',
    'ru': 'Русский',
    'si': 'සිංහල',
    'sk': 'Slovenčina',
    'sl': 'Slovenščina',
    'sq': 'Shqip',
    'sr': 'Српски',
    'sv': 'Svenska',
    'sw': 'Kiswahili',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'th': 'ไทย',
    'tl': 'Tagalog',
    'tr': 'Türkçe',
    'uk': 'Українська',
    'ur': 'اردو',
    'uz': 'Oʻzbek',
    'vi': 'Tiếng Việt',
    'zh': '中文',
    'zu': 'IsiZulu',
  };
  return names[code] ?? code.toUpperCase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (error, stackTrace) {
    debugPrint('Firebase init failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (firebaseReady) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
      return true;
    };
  }

  final model = GiftListModel();
  await model.loadFromStorage();
  final settings = AppSettings();
  await settings.loadFromStorage();
  final plan = AppPlanModel();
  await plan.loadFromStorage();
  runApp(GiftVoiceApp(model: model, settings: settings, plan: plan));
}

class GiftVoiceApp extends StatelessWidget {
  const GiftVoiceApp({
    required this.model,
    required this.settings,
    required this.plan,
    super.key,
  });

  final GiftListModel model;
  final AppSettings settings;
  final AppPlanModel plan;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0A9396);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFF8F2),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => model),
        ChangeNotifierProvider(create: (_) => settings),
        ChangeNotifierProvider(create: (_) => plan),
      ],
      child: Consumer<AppSettings>(
        builder: (context, appSettings, _) {
          final lang = appSettings.resolvedUiLanguageCode;
          final copy = AppText(lang);
          final rtl = _isRtlLanguage(lang);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: copy.appTitle,
            locale: appSettings.usesSystemLanguage ? null : Locale(lang),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: _supportedMaterialLocales,
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();
              return Directionality(
                textDirection: rtl
                    ? ui.TextDirection.rtl
                    : ui.TextDirection.ltr,
                child: child,
              );
            },
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: scheme,
              scaffoldBackgroundColor: const Color(0xFFFFF4EA),
              fontFamily: 'Palatino',
              textTheme: ThemeData.light().textTheme.apply(
                bodyColor: const Color(0xFF14323A),
                displayColor: const Color(0xFF14323A),
              ),
              cardTheme: CardThemeData(
                elevation: 10,
                color: Colors.white.withValues(alpha: 0.97),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
              ),
            ),
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AppSettings extends ChangeNotifier {
  static const String _uiLanguageKey = 'ui_language_code';
  static const String systemLanguageCode = 'system';
  String _uiLanguageCode = systemLanguageCode;

  String get uiLanguageCode => _uiLanguageCode;
  bool get usesSystemLanguage => _uiLanguageCode == systemLanguageCode;

  String get resolvedUiLanguageCode {
    if (!usesSystemLanguage) return _uiLanguageCode;
    return _sanitizeLanguage(
      ui.PlatformDispatcher.instance.locale.languageCode,
    );
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_uiLanguageKey) ?? systemLanguageCode;
    _uiLanguageCode = _sanitizeLanguage(code);
  }

  Future<void> setUiLanguage(String code) async {
    final normalized = _sanitizeLanguage(code);
    if (normalized == _uiLanguageCode) return;
    _uiLanguageCode = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uiLanguageKey, normalized);
  }

  String _sanitizeLanguage(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized == systemLanguageCode) {
      return systemLanguageCode;
    }
    if (_supportedInterfaceLanguageCodes.contains(normalized)) {
      return normalized;
    }
    return systemLanguageCode;
  }
}

enum PlanLimitReason { giftLimit, aiLimit, export }

class AppPlanModel extends ChangeNotifier {
  static const _isPremiumKey = 'plan_is_premium';
  static const _aiUsageMonthKey = 'plan_ai_usage_month';
  static const _aiUsageCountKey = 'plan_ai_usage_count';
  static const freeEventLimit = 2;
  static const freeGiftLimit = 50;
  static const freeAiUsesPerMonth = 20;

  bool _isPremium = false;
  String _aiUsageMonth = _currentMonthKey();
  int _aiUsageCount = 0;

  bool get isPremium => _isPremium;
  int get aiUsageCount {
    _rollMonthIfNeeded();
    return _aiUsageCount;
  }

  int get remainingFreeAiUses {
    if (_isPremium) return 999999;
    return (freeAiUsesPerMonth - aiUsageCount).clamp(0, freeAiUsesPerMonth);
  }

  bool canAddGiftEntries(int currentGiftCount, int incomingGiftCount) {
    if (_isPremium) return true;
    return currentGiftCount + incomingGiftCount <= freeGiftLimit;
  }

  bool get canUseAi => _isPremium || remainingFreeAiUses > 0;
  bool get canUseAdvancedExport => _isPremium;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_isPremiumKey) ?? false;
    _aiUsageMonth = prefs.getString(_aiUsageMonthKey) ?? _currentMonthKey();
    _aiUsageCount = prefs.getInt(_aiUsageCountKey) ?? 0;
    await _persistMonthIfRolled();
  }

  Future<void> recordAiUse() async {
    if (_isPremium) return;
    _rollMonthIfNeeded();
    _aiUsageCount += 1;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiUsageMonthKey, _aiUsageMonth);
    await prefs.setInt(_aiUsageCountKey, _aiUsageCount);
  }

  Future<void> setPremiumForTesting(bool value) async {
    if (_isPremium == value) return;
    _isPremium = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPremiumKey, value);
  }

  static String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  void _rollMonthIfNeeded() {
    final current = _currentMonthKey();
    if (_aiUsageMonth == current) return;
    _aiUsageMonth = current;
    _aiUsageCount = 0;
  }

  Future<void> _persistMonthIfRolled() async {
    final beforeMonth = _aiUsageMonth;
    final beforeCount = _aiUsageCount;
    _rollMonthIfNeeded();
    if (beforeMonth == _aiUsageMonth && beforeCount == _aiUsageCount) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiUsageMonthKey, _aiUsageMonth);
    await prefs.setInt(_aiUsageCountKey, _aiUsageCount);
  }
}

class AppText {
  const AppText(this.code);

  final String code;

  static AppText of(BuildContext context) {
    final language = context.watch<AppSettings>().resolvedUiLanguageCode;
    return AppText(language);
  }

  static AppText read(BuildContext context) {
    final language = context.read<AppSettings>().resolvedUiLanguageCode;
    return AppText(language);
  }

  bool get _he => code == 'he';
  bool get _ar => code == 'ar';

  String pick({required String en, required String he, required String ar}) {
    if (_he) return he;
    if (_ar) return ar;
    return en;
  }

  String get appTitle =>
      pick(en: 'Event Gift Keeper', he: 'מעקב מתנות', ar: 'متابعة الهدايا');

  String get signInSubtitle => pick(
    en: 'Speak and save every gift.',
    he: 'מדברים ושומרים כל מתנה.',
    ar: 'تحدث واحفظ كل هدية.',
  );

  String get continueWithGoogle => pick(
    en: 'Continue with Google',
    he: 'המשך עם Google',
    ar: 'المتابعة مع Google',
  );

  String get signingIn =>
      pick(en: 'Signing in...', he: 'מתחבר...', ar: 'جارٍ تسجيل الدخول...');

  String get firebaseNotReady => pick(
    en: 'Firebase is not configured correctly on this device.',
    he: 'Firebase לא מוגדר כראוי במכשיר הזה.',
    ar: 'Firebase غير مضبوط بشكل صحيح على هذا الجهاز.',
  );

  String get signInCanceled => pick(
    en: 'Sign-in was canceled.',
    he: 'ההתחברות בוטלה.',
    ar: 'تم إلغاء تسجيل الدخول.',
  );

  String get signInFailed => pick(
    en: 'Sign-in failed. Please try again.',
    he: 'ההתחברות נכשלה. נא לנסות שוב.',
    ar: 'فشل تسجيل الدخول. الرجاء المحاولة مرة أخرى.',
  );

  String get settings => pick(en: 'Settings', he: 'הגדרות', ar: 'الإعدادات');

  String get appLanguage =>
      pick(en: 'App language', he: 'שפת האפליקציה', ar: 'لغة التطبيق');

  String get searchLanguage =>
      pick(en: 'Search language', he: 'חיפוש שפה', ar: 'البحث عن لغة');

  String get systemDefault =>
      pick(en: 'System default', he: 'ברירת המחדל של המערכת', ar: 'لغة النظام');

  String get signOut => pick(en: 'Sign out', he: 'התנתק', ar: 'تسجيل الخروج');

  String get deleteEntryTitle =>
      pick(en: 'Delete entry?', he: 'למחוק רשומה?', ar: 'حذف السجل؟');

  String removeEntry(String guest, String description) => pick(
    en: 'Remove $guest - $description?',
    he: 'למחוק את $guest - $description?',
    ar: 'حذف $guest - $description؟',
  );

  String get cancel => pick(en: 'Cancel', he: 'ביטול', ar: 'إلغاء');

  String get delete => pick(en: 'Delete', he: 'מחק', ar: 'حذف');

  String deleted(String guest) =>
      pick(en: 'Deleted $guest.', he: '$guest נמחק.', ar: 'تم حذف $guest.');

  String deleteFailed(Object error) => pick(
    en: 'Delete failed: $error',
    he: 'המחיקה נכשלה: $error',
    ar: 'فشل الحذف: $error',
  );

  String get deleteAllTitle => pick(
    en: 'Delete All Entries',
    he: 'מחיקת כל הרשומות',
    ar: 'حذف كل السجلات',
  );

  String get deleteAllBody => pick(
    en: 'This will remove all gifts. Enter the protection code to continue.',
    he: 'פעולה זו תמחק את כל המתנות. הכנס קוד הגנה כדי להמשיך.',
    ar: 'سيتم حذف كل الهدايا. أدخل رمز الحماية للمتابعة.',
  );

  String get protectionCodeHint => pick(
    en: 'Enter protection code',
    he: 'הכנס קוד הגנה',
    ar: 'أدخل رمز الحماية',
  );

  String get deleteAllCodeHint => pick(
    en: 'Protection code: 2400',
    he: 'קוד הגנה: 2400',
    ar: 'رمز الحماية: 2400',
  );

  String get confirmDelete =>
      pick(en: 'Confirm Delete', he: 'אישור מחיקה', ar: 'تأكيد الحذف');

  String get wrongProtectionCode => pick(
    en: 'Wrong protection code. Nothing was deleted.',
    he: 'קוד הגנה שגוי. שום דבר לא נמחק.',
    ar: 'رمز الحماية غير صحيح. لم يتم حذف أي شيء.',
  );

  String get allEntriesDeleted => pick(
    en: 'All entries deleted.',
    he: 'כל הרשומות נמחקו.',
    ar: 'تم حذف كل السجلات.',
  );

  String deleteAllFailed(Object error) => pick(
    en: 'Delete all failed: $error',
    he: 'מחיקת הכל נכשלה: $error',
    ar: 'فشل حذف الكل: $error',
  );

  String get moneySummary => pick(
    en: 'Monetary gifts summary',
    he: 'סיכום מתנות כספיות',
    ar: 'ملخص الهدايا النقدية',
  );

  String get noMoneyGifts => pick(
    en: 'No monetary gifts yet',
    he: 'אין עדיין מתנות כספיות',
    ar: 'لا توجد هدايا نقدية بعد',
  );

  String countSummary(int money, int regular, int total) => pick(
    en: '$money monetary · $regular regular · $total total',
    he: '$money כספיות · $regular רגילות · $total סה״כ',
    ar: '$money نقدية · $regular عادية · $total المجموع',
  );

  String get aiIdle => pick(
    en: 'AI mode is active. Tap mic to record and analyze.',
    he: 'מצב AI פעיל. לחץ על המיקרופון כדי להקליט ולנתח.',
    ar: 'وضع الذكاء الاصطناعي فعال. اضغط على الميكروفون للتسجيل والتحليل.',
  );

  String get recording => pick(
    en: 'Recording for AI... it will auto-stop after 8 seconds.',
    he: 'מקליט ל־AI... העצירה תהיה אוטומטית אחרי 8 שניות.',
    ar: 'يتم التسجيل للذكاء الاصطناعي... سيتوقف تلقائياً بعد 8 ثوانٍ.',
  );

  String transcribing(int seconds) => pick(
    en: seconds <= 0
        ? 'AI is transcribing your speech...'
        : 'AI is transcribing $seconds seconds of audio...',
    he: seconds <= 0
        ? 'ה־AI מתמלל את ההקלטה...'
        : 'ה־AI מתמלל $seconds שניות של הקלטה...',
    ar: seconds <= 0
        ? 'يقوم الذكاء الاصطناعي بتفريغ التسجيل...'
        : 'يقوم الذكاء الاصطناعي بتفريغ $seconds ثوانٍ من الصوت...',
  );

  String get noAudio => pick(
    en: 'No audio captured. Please try again.',
    he: 'לא נקלט אודיו. נא לנסות שוב.',
    ar: 'لم يتم التقاط صوت. الرجاء المحاولة مرة أخرى.',
  );

  String get microphoneMissing => pick(
    en: 'Microphone permission is missing. Please allow microphone access.',
    he: 'חסרה הרשאת מיקרופון. נא לאפשר גישה למיקרופון.',
    ar: 'إذن الميكروفون غير موجود. الرجاء السماح بالوصول إلى الميكروفون.',
  );

  String capturedGifts(String provider, int count) => pick(
    en: 'AI ($provider) captured $count gifts.',
    he: 'AI ($provider) זיהה $count מתנות.',
    ar: 'AI ($provider) تعرّف على $count هدايا.',
  );

  String aiFailed(Object error) => pick(
    en: 'AI transcription failed: $error',
    he: 'תמלול ה־AI נכשל: $error',
    ar: 'فشل تفريغ الذكاء الاصطناعي: $error',
  );

  String get missingGiftName => pick(
    en: 'Incomplete recognition: one gift is missing a giver name. Please record again.',
    he: 'זיהוי לא מלא: חסר שם לאחת המתנות. נא להקליט שוב.',
    ar: 'التعرّف غير مكتمل: هناك هدية بدون اسم صاحبها. الرجاء التسجيل مرة أخرى.',
  );

  String get incompleteRecognition => pick(
    en: 'Incomplete or incorrect recognition. Please record again with the giver name and gift.',
    he: 'זיהוי לא מלא או שגוי. נא להקליט שוב עם שם נותן המתנה ומה הוא הביא.',
    ar: 'التعرّف غير مكتمل أو غير صحيح. الرجاء التسجيل مرة أخرى مع اسم صاحب الهدية وما أحضره.',
  );

  String get moneyGift =>
      pick(en: 'Monetary gift', he: 'מתנה כספית', ar: 'هدية نقدية');

  String get freePlan =>
      pick(en: 'Free plan', he: 'מסלול חינם', ar: 'الخطة المجانية');

  String get premiumPlan => pick(en: 'Premium', he: 'Premium', ar: 'Premium');

  String get upgradeTitle => pick(
    en: 'Upgrade to Premium',
    he: 'שדרוג ל־Premium',
    ar: 'الترقية إلى Premium',
  );

  String get upgradeCta => pick(
    en: r'Premium $1.99/month',
    he: r'Premium ב־$1.99 לחודש',
    ar: r'Premium بسعر $1.99 شهرياً',
  );

  String get upgradeComingSoon => pick(
    en: 'Payments are not connected yet. This screen is ready for in-app purchases.',
    he: 'התשלום עדיין לא מחובר. המסך הזה מוכן לחיבור רכישות בתוך האפליקציה.',
    ar: 'الدفع غير متصل بعد. هذه الشاشة جاهزة للربط مع الشراء داخل التطبيق.',
  );

  String get maybeLater =>
      pick(en: 'Maybe later', he: 'אולי אחר כך', ar: 'ربما لاحقاً');

  String get freePlanDetails => pick(
    en: 'Free: 2 events, 50 gifts, basic AI.',
    he: 'חינם: 2 אירועים, 50 מתנות, AI בסיסי.',
    ar: 'مجاني: حدثان، 50 هدية، ذكاء اصطناعي أساسي.',
  );

  String get premiumPlanDetails => pick(
    en: 'Premium: unlimited events, unlimited gifts, unlimited AI, full backup, designed PDF, advanced export, family sharing.',
    he: 'Premium: אירועים ללא הגבלה, מתנות ללא הגבלה, AI ללא הגבלה, גיבוי מלא, PDF מעוצב, ייצוא מתקדם ושיתוף משפחתי.',
    ar: 'Premium: أحداث غير محدودة، هدايا غير محدودة، ذكاء اصطناعي غير محدود، نسخ احتياطي كامل، PDF مصمم، تصدير متقدم ومشاركة عائلية.',
  );

  String get freeGiftLimitReached => pick(
    en: 'The free plan supports up to 50 gifts. Upgrade to add more.',
    he: 'מסלול החינם תומך עד 50 מתנות. שדרג כדי להוסיף עוד.',
    ar: 'الخطة المجانية تدعم حتى 50 هدية. قم بالترقية لإضافة المزيد.',
  );

  String freeAiLimitReached(int limit) => pick(
    en: 'You used the $limit free AI recordings for this month. Upgrade for unlimited AI.',
    he: 'ניצלת את $limit הקלטות ה־AI החינמיות לחודש הזה. שדרג ל־AI ללא הגבלה.',
    ar: 'استخدمت $limit تسجيلات ذكاء اصطناعي مجانية لهذا الشهر. قم بالترقية للاستخدام غير المحدود.',
  );

  String get premiumExportOnly => pick(
    en: 'Advanced export is available in Premium.',
    he: 'ייצוא מתקדם זמין במסלול Premium.',
    ar: 'التصدير المتقدم متاح في Premium.',
  );

  String planUsage(int gifts, int remainingAi) => pick(
    en: 'Free usage: $gifts/50 gifts · $remainingAi AI left this month',
    he: 'שימוש חינמי: $gifts/50 מתנות · נשארו $remainingAi פעולות AI החודש',
    ar: 'الاستخدام المجاني: $gifts/50 هدية · تبقى $remainingAi استخدامات AI هذا الشهر',
  );

  String get noGiftsYet =>
      pick(en: 'No gifts yet', he: 'אין מתנות עדיין', ar: 'لا توجد هدايا بعد');

  String get emptyGiftsHint => pick(
    en: 'Add an entry manually or capture one with voice.',
    he: 'הוסף רשומה ידנית או הקלט מתנה בקול.',
    ar: 'أضف سجلاً يدوياً أو التقط هدية بالصوت.',
  );

  String get stopRecording =>
      pick(en: 'Stop Recording', he: 'עצור הקלטה', ar: 'إيقاف التسجيل');

  String get voiceCapture =>
      pick(en: 'Voice Capture', he: 'הקלטה קולית', ar: 'التقاط صوتي');

  String get processing =>
      pick(en: 'Processing...', he: 'מעבד...', ar: 'جارٍ المعالجة...');
}

class GiftMoneyItem {
  const GiftMoneyItem({required this.amount, required this.currencyCode});

  final double amount;
  final String currencyCode;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'amount': amount, 'currencyCode': currencyCode};
  }

  static GiftMoneyItem? fromMap(Map<dynamic, dynamic> raw) {
    final amountRaw = raw['amount'];
    final amount = amountRaw == null
        ? null
        : double.tryParse(amountRaw.toString().replaceAll(',', '.'));
    final currencyCode = (raw['currencyCode'] ?? raw['currency_code'])
        ?.toString()
        .toUpperCase();
    if (amount == null || amount <= 0 || currencyCode == null) return null;
    return GiftMoneyItem(amount: amount, currencyCode: currencyCode);
  }
}

class GiftEntry {
  GiftEntry({
    this.id,
    required this.guest,
    required this.description,
    this.amount,
    this.currencyCode,
    List<GiftMoneyItem>? moneyItems,
    DateTime? created,
  }) : moneyItems = List.unmodifiable(
         moneyItems ?? _fallbackMoneyItems(amount, currencyCode),
       ),
       created = created ?? DateTime.now();

  final String? id;
  final String guest;
  final String description;
  final double? amount;
  final String? currencyCode;
  final List<GiftMoneyItem> moneyItems;
  final DateTime created;

  bool get isMonetary => moneyItems.isNotEmpty;

  static List<GiftMoneyItem> _fallbackMoneyItems(
    double? amount,
    String? currencyCode,
  ) {
    if (amount == null || amount <= 0) return const [];
    return [GiftMoneyItem(amount: amount, currencyCode: currencyCode ?? 'ILS')];
  }

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'guest': guest,
      'description': description,
      'amount': amount,
      'currencyCode': currencyCode,
      'moneyItems': moneyItems.map((item) => item.toMap()).toList(),
      'created': Timestamp.fromDate(created),
    };
  }

  Map<String, dynamic> toStorageMap() {
    return <String, dynamic>{
      'id': id,
      'guest': guest,
      'description': description,
      'amount': amount,
      'currencyCode': currencyCode,
      'moneyItems': moneyItems.map((item) => item.toMap()).toList(),
      'created': created.toIso8601String(),
    };
  }

  static GiftEntry fromStorageMap(Map<dynamic, dynamic> raw) {
    final createdRaw = raw['created']?.toString();
    final amount = raw['amount'] == null
        ? null
        : double.tryParse(raw['amount'].toString().replaceAll(',', '.'));
    final currencyCode = raw['currencyCode']?.toString();
    return GiftEntry(
      id: raw['id']?.toString(),
      guest: raw['guest']?.toString() ?? 'Unknown',
      description: raw['description']?.toString() ?? '',
      amount: amount,
      currencyCode: currencyCode,
      moneyItems: _parseMoneyItems(raw['moneyItems']),
      created: DateTime.tryParse(createdRaw ?? '') ?? DateTime.now(),
    );
  }

  static GiftEntry fromFirestoreDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdRaw = data['created'];
    final created = createdRaw is Timestamp
        ? createdRaw.toDate()
        : createdRaw is DateTime
        ? createdRaw
        : DateTime.now();
    final amount = data['amount'] == null
        ? null
        : double.tryParse(data['amount'].toString().replaceAll(',', '.'));
    final currencyCode = data['currencyCode']?.toString();
    return GiftEntry(
      id: doc.id,
      guest: data['guest']?.toString() ?? 'Unknown',
      description: data['description']?.toString() ?? '',
      amount: amount,
      currencyCode: currencyCode,
      moneyItems: _parseMoneyItems(data['moneyItems']),
      created: created,
    );
  }

  static List<GiftMoneyItem>? _parseMoneyItems(Object? raw) {
    if (raw is! Iterable) return null;
    final items = <GiftMoneyItem>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final parsed = GiftMoneyItem.fromMap(item);
      if (parsed != null) items.add(parsed);
    }
    return items;
  }
}

class GiftListModel extends ChangeNotifier {
  static const _storageKey = 'gift_entries_v1';
  final List<GiftEntry> _entries = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _entriesSubscription;

  GiftListModel() {
    if (Firebase.apps.isNotEmpty) {
      FirebaseAuth.instance.authStateChanges().listen(_handleAuthChanged);
    }
  }

  List<GiftEntry> get entries => List.unmodifiable(_entries);

  Map<String, double> get totalsByCurrency {
    final totals = <String, double>{};
    for (final entry in _entries) {
      for (final item in entry.moneyItems) {
        final code = item.currencyCode.toUpperCase();
        totals.update(
          code,
          (value) => value + item.amount,
          ifAbsent: () => item.amount,
        );
      }
    }
    return totals;
  }

  int get monetaryGiftCount =>
      _entries.where((entry) => entry.isMonetary).length;

  int get regularGiftCount =>
      _entries.where((entry) => !entry.isMonetary).length;

  Future<void> deleteAllEntries() async {
    final user = _currentUser;
    if (user == null) {
      _entries.clear();
      await _saveToStorage();
      notifyListeners();
      return;
    }

    final snapshot = await _entriesCollection(user).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> addEntry(GiftEntry entry) async {
    final user = _currentUser;
    if (user == null) {
      _entries.insert(0, entry);
      await _saveToStorage();
      notifyListeners();
      return;
    }
    await _entriesCollection(user).add(entry.toFirestoreMap());
  }

  Future<void> removeEntry(GiftEntry entry) async {
    final user = _currentUser;
    if (user == null) {
      _entries.removeWhere(
        (item) =>
            item.created == entry.created &&
            item.guest == entry.guest &&
            item.description == entry.description,
      );
      await _saveToStorage();
      notifyListeners();
      return;
    }

    if (entry.id == null || entry.id!.isEmpty) {
      throw Exception('Entry id is missing. Please refresh and try again.');
    }

    await _entriesCollection(user).doc(entry.id).delete();
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _entries
          ..clear()
          ..addAll(decoded.whereType<Map>().map(GiftEntry.fromStorageMap));
      }
    }
    final user = _currentUser;
    if (user != null) _bindEntries(user);
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _entries.map((e) => e.toStorageMap()).toList();
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  User? get _currentUser {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser;
  }

  CollectionReference<Map<String, dynamic>> _entriesCollection(User user) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('giftEntries');
  }

  Future<void> _handleAuthChanged(User? user) async {
    await _entriesSubscription?.cancel();
    _entriesSubscription = null;
    if (user == null) {
      await _saveToStorage();
      notifyListeners();
      return;
    }
    _bindEntries(user);
  }

  void _bindEntries(User user) {
    _entriesSubscription = _entriesCollection(user)
        .orderBy('created', descending: true)
        .snapshots()
        .listen((snapshot) async {
          _entries
            ..clear()
            ..addAll(snapshot.docs.map(GiftEntry.fromFirestoreDoc));
          await _saveToStorage();
          notifyListeners();
        });
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();
    final latin = await PdfGoogleFonts.notoSansRegular();
    final latinBold = await PdfGoogleFonts.notoSansBold();
    final arabic = await PdfGoogleFonts.notoNaskhArabicRegular();
    final hebrew = await PdfGoogleFonts.notoSansHebrewRegular();

    final bodyStyle = pw.TextStyle(font: latin, fontFallback: [arabic, hebrew]);
    final headerStyle = pw.TextStyle(
      font: latinBold,
      fontFallback: [arabic, hebrew],
    );

    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          _pdfCell('Date', style: headerStyle),
          _pdfCell('Guest', style: headerStyle),
          _pdfCell('Description', style: headerStyle),
        ],
      ),
      ..._entries.map(
        (e) => pw.TableRow(
          children: [
            _pdfCell(
              DateFormat.yMd().add_Hm().format(e.created),
              style: bodyStyle,
            ),
            _pdfCell(e.guest, style: bodyStyle),
            _pdfCell(e.description, style: bodyStyle),
          ],
        ),
      ),
    ];

    pdf.addPage(
      pw.Page(
        build: (_) => pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600),
          children: rows,
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  pw.Widget _pdfCell(String text, {pw.TextStyle? style}) {
    final hasRtl = RegExp(r'[\u0590-\u05FF\u0600-\u06FF]').hasMatch(text);
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textDirection: hasRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        style: style,
      ),
    );
  }

  Future<void> exportToCsv() async {
    final rows = <List<String>>[
      ['Date', 'Guest', 'Description'],
      ..._entries.map(
        (e) => [
          DateFormat.yMd().add_Hm().format(e.created),
          e.guest,
          e.description,
        ],
      ),
    ];
    final csvString = const ListToCsvConverter().convert(rows);
    await Share.share(csvString, subject: 'Gift list');
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseReady = Firebase.apps.isNotEmpty;
    if (!firebaseReady) {
      return const SignInPage(firebaseReady: false);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return const GiftHomePage();
        return const SignInPage(firebaseReady: true);
      },
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({required this.firebaseReady, super.key});

  final bool firebaseReady;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    final copy = AppText.read(context);
    if (_isLoading) return;
    if (!widget.firebaseReady) {
      setState(() {
        _errorMessage = copy.firebaseNotReady;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (!mounted) return;
        setState(() => _errorMessage = copy.signInCanceled);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() => _errorMessage = error.message ?? copy.signInFailed);
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() => _errorMessage = copy.signInFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppText.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE8D6), Color(0xFFFFF4EA), Color(0xFFE3F6F5)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      copy.appTitle,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(copy.signInSubtitle, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _signIn,
                        icon: const Icon(Icons.login),
                        label: Text(
                          _isLoading ? copy.signingIn : copy.continueWithGoogle,
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GiftHomePage extends StatefulWidget {
  const GiftHomePage({super.key});

  @override
  State<GiftHomePage> createState() => _GiftHomePageState();
}

class _GiftHomePageState extends State<GiftHomePage> {
  static const Duration _maxRecordingLength = Duration(seconds: 8);

  bool _isListening = false;
  bool _isAiProcessing = false;
  String _speechMessage = '';
  String _lastTranscriptPreview = '';
  DateTime? _recordingStartedAt;
  Timer? _recordingAutoStopTimer;
  final AudioRecorder _audioRecorder = AudioRecorder();

  double _uiScale(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / 520).clamp(0.38, 0.85);
  }

  double _space(BuildContext context, double base) => base * _uiScale(context);

  bool _isCompact(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.width < 700 || media.textScaler.scale(1) > 1.0;
  }

  bool _isUltraCompact(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.width < 500 || media.textScaler.scale(1) > 1.0;
  }

  double _maxContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return 980;
    if (width >= 900) return 860;
    if (width >= 700) return 720;
    return width;
  }

  @override
  void dispose() {
    _recordingAutoStopTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  Map<String, double> _totalsByCurrency(GiftListModel model) {
    return model.totalsByCurrency;
  }

  List<MapEntry<String, double>> _orderedCurrencyTotals(
    Map<String, double> totals,
  ) {
    const preferredOrder = ['ILS', 'USD', 'EUR'];
    final entries = totals.entries.toList();
    entries.sort((a, b) {
      final aIndex = preferredOrder.indexOf(a.key);
      final bIndex = preferredOrder.indexOf(b.key);
      if (aIndex != -1 || bIndex != -1) {
        return (aIndex == -1 ? preferredOrder.length : aIndex).compareTo(
          bIndex == -1 ? preferredOrder.length : bIndex,
        );
      }
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  String _formatCurrencyAmount(String code, double amount) {
    final rounded = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '${_currencySymbol(code)}$rounded';
  }

  Color _entryTint(int index) {
    const palette = [
      Color(0xFFC6DBF7),
      Color(0xFFBFE3D6),
      Color(0xFFE6C7E9),
      Color(0xFFF4D3B4),
    ];
    return palette[index % palette.length];
  }

  Future<void> _confirmDeleteEntry(GiftEntry entry) async {
    final model = context.read<GiftListModel>();
    final copy = AppText.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(copy.deleteEntryTitle),
          content: Text(copy.removeEntry(entry.guest, entry.description)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(copy.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC43C30),
              ),
              child: Text(copy.delete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await model.removeEntry(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.deleted(entry.guest))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.deleteFailed(error))));
    }
  }

  Future<void> _confirmDeleteAllEntries() async {
    final model = context.read<GiftListModel>();
    final copy = AppText.read(context);
    final controller = TextEditingController();
    const protectionCode = '2400';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(copy.deleteAllTitle, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(copy.deleteAllBody, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                textAlign: TextAlign.center,
                decoration: InputDecoration(hintText: copy.protectionCodeHint),
              ),
              const SizedBox(height: 8),
              Text(
                copy.deleteAllCodeHint,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(copy.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(controller.text.trim() == protectionCode);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5C6FAE),
              ),
              child: Text(copy.confirmDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.wrongProtectionCode)));
      return;
    }

    try {
      await model.deleteAllEntries();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.allEntriesDeleted)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.deleteAllFailed(error))));
    }
  }

  Future<void> _showUpgradeSheet(PlanLimitReason reason) async {
    final copy = AppText.read(context);
    final model = context.read<GiftListModel>();
    final plan = context.read<AppPlanModel>();
    final reasonText = switch (reason) {
      PlanLimitReason.giftLimit => copy.freeGiftLimitReached,
      PlanLimitReason.aiLimit => copy.freeAiLimitReached(
        AppPlanModel.freeAiUsesPerMonth,
      ),
      PlanLimitReason.export => copy.premiumExportOnly,
    };

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  copy.upgradeTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reasonText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5F514D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _planSummaryTile(
                  title: copy.freePlan,
                  body: copy.freePlanDetails,
                  icon: Icons.lock_open_outlined,
                ),
                const SizedBox(height: 10),
                _planSummaryTile(
                  title: copy.premiumPlan,
                  body: copy.premiumPlanDetails,
                  icon: Icons.workspace_premium_outlined,
                  highlighted: true,
                ),
                const SizedBox(height: 16),
                Text(
                  plan.isPremium
                      ? copy.premiumPlan
                      : copy.planUsage(
                          model.entries.length,
                          plan.remainingFreeAiUses,
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6D5A52),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(copy.upgradeComingSoon)),
                    );
                  },
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(copy.upgradeCta),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(copy.maybeLater),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _planSummaryTile({
    required String title,
    required String body,
    required IconData icon,
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF2B120C) : const Color(0xFFFFF4EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF2B120C)
              : const Color(0xFFFFD9C9),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: highlighted ? Colors.white : const Color(0xFF6A3C31),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: highlighted ? Colors.white : const Color(0xFF2B120C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: highlighted
                        ? Colors.white70
                        : const Color(0xFF6D5A52),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureCanAddGiftEntries(int incomingCount) async {
    final model = context.read<GiftListModel>();
    final plan = context.read<AppPlanModel>();
    if (plan.canAddGiftEntries(model.entries.length, incomingCount)) {
      return true;
    }
    await _showUpgradeSheet(PlanLimitReason.giftLimit);
    return false;
  }

  Future<bool> _ensureCanUseAi() async {
    final plan = context.read<AppPlanModel>();
    if (plan.canUseAi) return true;
    await _showUpgradeSheet(PlanLimitReason.aiLimit);
    return false;
  }

  Future<void> _runPremiumExport(Future<void> Function() exportAction) async {
    final plan = context.read<AppPlanModel>();
    if (!plan.canUseAdvancedExport) {
      await _showUpgradeSheet(PlanLimitReason.export);
      return;
    }
    await exportAction();
  }

  Future<void> _openSettings() async {
    final settings = context.read<AppSettings>();
    final copy = AppText.read(context);
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.86,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final current = settings.uiLanguageCode;
                final languages = _supportedInterfaceLanguageCodes
                    .where((code) => _languageMatchesQuery(code, query))
                    .toList();

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.settings,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        copy.appLanguage,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: copy.searchLanguage,
                        ),
                        onChanged: (value) {
                          setSheetState(() => query = value.trim());
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView(
                          children: [
                            _languageTile(
                              settings: settings,
                              code: AppSettings.systemLanguageCode,
                              label: copy.systemDefault,
                              subtitle:
                                  '${_languageDisplayName(settings.resolvedUiLanguageCode)} (${settings.resolvedUiLanguageCode})',
                              current: current,
                            ),
                            const Divider(height: 10),
                            for (final code in languages)
                              _languageTile(
                                settings: settings,
                                code: code,
                                label: _languageDisplayName(code),
                                subtitle: code,
                                current: current,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _signOut();
                          },
                          icon: const Icon(Icons.logout),
                          label: Text(copy.signOut),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  bool _languageMatchesQuery(String code, String query) {
    if (query.isEmpty) return true;
    final normalized = query.toLowerCase();
    return code.toLowerCase().contains(normalized) ||
        _languageDisplayName(code).toLowerCase().contains(normalized);
  }

  Widget _languageTile({
    required AppSettings settings,
    required String code,
    required String label,
    required String subtitle,
    required String current,
  }) {
    final selected = current == code;
    return ListTile(
      dense: true,
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(label),
      subtitle: Text(subtitle),
      onTap: () async {
        await settings.setUiLanguage(code);
        if (!mounted) return;
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _handleMicTap() async {
    if (_isListening) {
      await _stopAiCaptureAndProcess();
    } else {
      if (!await _ensureCanUseAi()) return;
      await _startAiCapture();
    }
  }

  Future<void> _startAiCapture() async {
    final copy = AppText.read(context);
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        _speechMessage = copy.microphoneMissing;
      });
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/gift_ai_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    _recordingStartedAt = DateTime.now();
    _recordingAutoStopTimer?.cancel();
    _recordingAutoStopTimer = Timer(_maxRecordingLength, () {
      if (mounted && _isListening && !_isAiProcessing) {
        _stopAiCaptureAndProcess();
      }
    });

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _speechMessage = copy.recording;
    });
  }

  Future<void> _stopAiCaptureAndProcess() async {
    final copy = AppText.read(context);
    _recordingAutoStopTimer?.cancel();
    final path = await _audioRecorder.stop();
    final recordedFor = _recordingStartedAt == null
        ? null
        : DateTime.now().difference(_recordingStartedAt!);
    _recordingStartedAt = null;
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _isAiProcessing = true;
      _speechMessage = recordedFor == null
          ? copy.transcribing(0)
          : copy.transcribing(
              recordedFor.inSeconds.clamp(1, _maxRecordingLength.inSeconds),
            );
    });

    if (path == null || path.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isAiProcessing = false;
        _speechMessage = copy.noAudio;
      });
      return;
    }

    try {
      final aiResult = await _transcribeAndAnalyzeWithAi(path);
      if (!mounted) return;
      setState(() {
        _isAiProcessing = false;
        _lastTranscriptPreview = aiResult.transcript;
      });

      final aiParses = aiResult.entries;
      if (aiParses.isNotEmpty) {
        final model = context.read<GiftListModel>();
        final plan = context.read<AppPlanModel>();
        final missingName = aiParses.any((parse) => parse.guest.trim().isEmpty);
        if (missingName) {
          _showRecognitionRetryMessage(copy.missingGiftName);
          return;
        }
        if (!await _ensureCanAddGiftEntries(aiParses.length)) {
          setState(() {
            _isAiProcessing = false;
            _speechMessage = copy.freeGiftLimitReached;
          });
          return;
        }
        for (final aiParse in aiParses) {
          final firstMoneyItem = aiParse.moneyItems.isEmpty
              ? null
              : aiParse.moneyItems.first;
          await model.addEntry(
            GiftEntry(
              guest: aiParse.guest.trim(),
              description: _composeAiDescription(
                aiParse,
                aiResult.transcript,
                includeAmount: aiParse.moneyItems.length <= 1,
              ),
              amount: firstMoneyItem?.amount ?? aiParse.amount,
              currencyCode:
                  firstMoneyItem?.currencyCode ?? aiParse.currencyCode,
              moneyItems: aiParse.moneyItems
                  .map(
                    (item) => GiftMoneyItem(
                      amount: item.amount,
                      currencyCode: item.currencyCode,
                    ),
                  )
                  .toList(),
              created: aiParse.eventDate,
            ),
          );
        }
        await plan.recordAiUse();
        if (!mounted) return;
        setState(() {
          _speechMessage = copy.capturedGifts(
            aiResult.provider,
            aiParses.length,
          );
        });
      } else {
        _showRecognitionRetryMessage(copy.incompleteRecognition);
        return;
      }
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _isAiProcessing = false;
        _speechMessage = copy.aiFailed(error);
      });
    } finally {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<_AiResult> _transcribeAndAnalyzeWithAi(String audioPath) async {
    final languageHint = mounted
        ? Localizations.maybeLocaleOf(context)?.languageCode
        : null;
    final audioBytes = await File(audioPath).readAsBytes();
    if (audioBytes.isEmpty) throw Exception('Audio payload is empty.');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in before using AI transcription.');
    }

    try {
      await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw Exception(
        error.message ?? 'Failed to refresh your sign-in session.',
      );
    }

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('aiTranscribeAndParse');
      final result = await callable
          .call(<String, dynamic>{
            'audioBase64': base64Encode(audioBytes),
            'mimeType': 'audio/mp4',
            'languageHint': languageHint,
          })
          .timeout(const Duration(seconds: 45));

      final rawData = result.data;
      if (rawData is! Map) {
        throw Exception('AI service returned an invalid payload.');
      }

      final data = Map<String, dynamic>.from(rawData);
      final transcript = data['transcript']?.toString().trim() ?? '';
      final parsedMap = data['parsed'];
      final parsed = parsedMap is Map
          ? _parseAiGiftParseFromMap(parsedMap)
          : null;
      final entries = _parseAiGiftEntries(data['entries'], fallback: parsed);
      final provider = data['provider']?.toString().trim() ?? 'Gemini';

      if (_isPlaceholderAiText(transcript)) {
        throw Exception(
          'AI returned placeholder text instead of a transcription.',
        );
      }

      if (transcript.isEmpty && entries.isEmpty) {
        throw Exception('AI service returned no usable transcript or fields.');
      }

      return _AiResult(
        transcript: transcript,
        entries: entries,
        provider: provider.isEmpty ? 'Gemini' : provider,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        return _transcribeAndAnalyzeWithAiHttp(audioBytes, languageHint);
      }
      throw Exception(error.message ?? error.code);
    }
  }

  void _showRecognitionRetryMessage(String message) {
    if (!mounted) return;
    setState(() {
      _isAiProcessing = false;
      _speechMessage = message;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_AiResult> _transcribeAndAnalyzeWithAiHttp(
    List<int> audioBytes,
    String? languageHint,
  ) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('You must be signed in before using AI transcription.');
    }
    const projectId = 'gift-tracker-98088';
    final uri = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/aiTranscribeAndParseHttp',
    );

    final response = await http
        .post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, dynamic>{
            'audioBase64': base64Encode(audioBytes),
            'mimeType': 'audio/mp4',
            'languageHint': languageHint,
          }),
        )
        .timeout(const Duration(seconds: 45));

    final responseJson = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = responseJson is Map
          ? responseJson['error']?.toString()
          : response.body;
      throw Exception(message ?? 'AI HTTP fallback failed.');
    }

    if (responseJson is! Map) {
      throw Exception('AI service returned an invalid HTTP payload.');
    }

    final data = Map<String, dynamic>.from(responseJson);
    final transcript = data['transcript']?.toString().trim() ?? '';
    final parsedMap = data['parsed'];
    final parsed = parsedMap is Map
        ? _parseAiGiftParseFromMap(parsedMap)
        : null;
    final entries = _parseAiGiftEntries(data['entries'], fallback: parsed);
    final provider = data['provider']?.toString().trim() ?? 'Gemini';

    if (_isPlaceholderAiText(transcript)) {
      throw Exception(
        'AI returned placeholder text instead of a transcription.',
      );
    }

    if (transcript.isEmpty && entries.isEmpty) {
      throw Exception('AI service returned no usable transcript or fields.');
    }

    return _AiResult(
      transcript: transcript,
      entries: entries,
      provider: provider.isEmpty ? 'Gemini' : provider,
    );
  }

  bool _isPlaceholderAiText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    const blockedPhrases = [
      'here is the json requested',
      'the json requested',
      'json requested',
      '```json',
      'transcribe the spoken audio',
      'return strict json only',
    ];
    for (final phrase in blockedPhrases) {
      if (normalized.contains(phrase)) return true;
    }
    return false;
  }

  _AiGiftParse? _parseAiGiftParseFromMap(Map<dynamic, dynamic> parsedRaw) {
    final guest = parsedRaw['guest']?.toString().trim() ?? '';
    final giftDescription =
        parsedRaw['gift_description']?.toString().trim() ?? '';
    final occasion = parsedRaw['occasion']?.toString().trim() ?? '';
    final eventDateRaw = parsedRaw['event_date']?.toString().trim();
    final currencyCodeRaw = parsedRaw['currency_code']
        ?.toString()
        .toUpperCase();
    final currencyCode = switch (currencyCodeRaw) {
      'USD' => 'USD',
      'EUR' => 'EUR',
      'ILS' => 'ILS',
      _ => null,
    };
    final amountRaw = parsedRaw['amount'];
    final amount = amountRaw == null
        ? null
        : double.tryParse(amountRaw.toString().replaceAll(',', '.'));
    final moneyItems = _parseAiMoneyItems(parsedRaw['money_items']);
    final normalizedMoneyItems = moneyItems.isNotEmpty
        ? moneyItems
        : [
            if (amount != null && amount > 0)
              _AiMoneyItem(amount: amount, currencyCode: currencyCode ?? 'ILS'),
          ];

    return _AiGiftParse(
      guest: guest,
      giftDescription: giftDescription,
      amount: amount,
      currencyCode: currencyCode,
      moneyItems: normalizedMoneyItems,
      occasion: occasion,
      eventDate: _parseAiDate(eventDateRaw),
    );
  }

  List<_AiGiftParse> _parseAiGiftEntries(
    Object? raw, {
    _AiGiftParse? fallback,
  }) {
    final entries = <_AiGiftParse>[];
    if (raw is Iterable) {
      for (final item in raw) {
        if (item is! Map) continue;
        final parsed = _parseAiGiftParseFromMap(item);
        if (parsed != null) entries.add(parsed);
      }
    }
    if (entries.isEmpty && fallback != null) {
      entries.add(fallback);
    }
    return entries;
  }

  List<_AiMoneyItem> _parseAiMoneyItems(Object? raw) {
    if (raw is! List) return const [];
    final items = <_AiMoneyItem>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final amountRaw = item['amount'];
      final amount = amountRaw == null
          ? null
          : double.tryParse(amountRaw.toString().replaceAll(',', '.'));
      final currencyCodeRaw = item['currency_code']?.toString().toUpperCase();
      final currencyCode = switch (currencyCodeRaw) {
        'USD' => 'USD',
        'EUR' => 'EUR',
        'ILS' => 'ILS',
        _ => null,
      };
      if (amount == null || amount <= 0 || currencyCode == null) continue;
      items.add(_AiMoneyItem(amount: amount, currencyCode: currencyCode));
    }
    return items;
  }

  DateTime? _parseAiDate(String? raw) {
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _composeAiDescription(
    _AiGiftParse ai,
    String transcript, {
    bool includeAmount = true,
  }) {
    final parts = <String>[];
    if (ai.giftDescription.isNotEmpty) {
      parts.add(ai.giftDescription);
    } else if (ai.moneyItems.isNotEmpty || ai.amount != null) {
      parts.add(AppText.read(context).moneyGift);
    } else {
      parts.add(transcript);
    }
    if (ai.occasion.isNotEmpty) parts.add('for ${ai.occasion}');
    final base = parts.join(' ').trim();
    if (!includeAmount) return base;
    final amount = ai.amount;
    if (amount == null) return base;
    final code = ai.currencyCode ?? 'ILS';
    return '$base ${_formatAmount(amount)} ${_currencySymbol(code)}'.trim();
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) return amount.toStringAsFixed(0);
    return amount.toStringAsFixed(2);
  }

  String _currencySymbol(String code) {
    switch (code) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'ILS':
      default:
        return '₪';
    }
  }

  Widget _buildEntrySymbol(
    BuildContext context,
    GiftEntry entry,
    List<GiftMoneyItem> moneyItems,
  ) {
    const color = Color(0xFF6A3C31);
    if (moneyItems.length == 1) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _currencySymbol(moneyItems.first.currencyCode),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      );
    }
    if (moneyItems.length > 1) {
      final symbols = <String>[];
      for (final item in moneyItems) {
        final symbol = _currencySymbol(item.currencyCode);
        if (!symbols.contains(symbol)) symbols.add(symbol);
      }
      return Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: _space(context, 3),
        runSpacing: _space(context, 2),
        children: [
          for (final symbol in symbols.take(4))
            Text(
              symbol,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
        ],
      );
    }
    return Icon(
      _giftIconForDescription(entry.description),
      size: 28,
      color: color,
    );
  }

  IconData _giftIconForDescription(String description) {
    final text = description.toLowerCase();
    bool hasAny(List<String> words) => words.any(text.contains);

    if (hasAny(['פרח', 'זר', 'flowers', 'flower', 'bouquet', 'ورد', 'زهور'])) {
      return Icons.local_florist_outlined;
    }
    if (hasAny([
      'תכשיט',
      'טבעת',
      'שרשרת',
      'צמיד',
      'זהב',
      'jewel',
      'ring',
      'necklace',
      'bracelet',
      'gold',
      'مجوهرات',
      'خاتم',
      'ذهب',
    ])) {
      return Icons.diamond_outlined;
    }
    if (hasAny(['שעון', 'watch', 'ساعة'])) {
      return Icons.watch_outlined;
    }
    if (hasAny([
      'טלפון',
      'מחשב',
      'אייפון',
      'phone',
      'computer',
      'laptop',
      'iphone',
      'هاتف',
      'كمبيوتر',
    ])) {
      return Icons.devices_outlined;
    }
    if (hasAny([
      'בושם',
      'איפור',
      'קוסמטיקה',
      'perfume',
      'makeup',
      'cosmetic',
      'عطر',
      'مكياج',
    ])) {
      return Icons.spa_outlined;
    }
    if (hasAny(['ספר', 'book', 'كتاب'])) {
      return Icons.menu_book_outlined;
    }
    if (hasAny([
      'בגד',
      'בגדים',
      'חולצה',
      'שמלה',
      'clothes',
      'shirt',
      'dress',
      'ملابس',
      'فستان',
    ])) {
      return Icons.checkroom_outlined;
    }
    if (hasAny([
      'יין',
      'אלכוהול',
      'בקבוק',
      'wine',
      'alcohol',
      'bottle',
      'نبيذ',
      'كحول',
    ])) {
      return Icons.wine_bar_outlined;
    }
    if (hasAny([
      'עוגה',
      'שוקולד',
      'ממתקים',
      'cake',
      'chocolate',
      'sweets',
      'كيك',
      'شوكولاتة',
      'حلويات',
    ])) {
      return Icons.cake_outlined;
    }
    if (hasAny([
      'מטבח',
      'סיר',
      'מחבת',
      'מכשיר',
      'kitchen',
      'pot',
      'pan',
      'appliance',
      'مطبخ',
      'طنجرة',
    ])) {
      return Icons.kitchen_outlined;
    }
    if (hasAny([
      'רהיט',
      'כיסא',
      'שולחן',
      'בית',
      'furniture',
      'chair',
      'table',
      'home',
      'أثاث',
      'كرسي',
      'بيت',
    ])) {
      return Icons.chair_outlined;
    }
    if (hasAny([
      'נסיעה',
      'חופשה',
      'טיסה',
      'מלון',
      'trip',
      'flight',
      'hotel',
      'vacation',
      'سفر',
      'رحلة',
      'فندق',
    ])) {
      return Icons.flight_takeoff_outlined;
    }
    if (hasAny(['תינוק', 'עגלה', 'baby', 'stroller', 'طفل', 'عربة'])) {
      return Icons.child_friendly_outlined;
    }
    if (hasAny(['שובר', 'כרטיס', 'voucher', 'ticket', 'قسيمة', 'تذكرة'])) {
      return Icons.confirmation_number_outlined;
    }
    return Icons.card_giftcard_outlined;
  }

  Widget _topActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color accent = const Color(0xFF4C2418),
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: accent, size: 26),
        ),
      ),
    );
  }

  Widget _summaryActionButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: onTap == null ? 0.08 : 0.95),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          width: 86,
          height: 74,
          child: Icon(
            icon,
            color: onTap == null ? Colors.white38 : const Color(0xFF5A3022),
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, GiftListModel model) {
    final copy = AppText.of(context);
    final plan = context.watch<AppPlanModel>();
    final text = Theme.of(context).textTheme;
    final totals = _totalsByCurrency(model);
    final orderedTotals = _orderedCurrencyTotals(totals);
    final canExport = model.entries.isNotEmpty;

    return Column(
      children: [
        Row(
          children: [
            _topActionButton(icon: Icons.logout_rounded, onTap: _signOut),
            SizedBox(width: _space(context, 10)),
            _topActionButton(
              icon: Icons.settings_outlined,
              onTap: _openSettings,
            ),
            SizedBox(width: _space(context, 10)),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _space(context, 18),
                    vertical: _space(context, 14),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7E6D3),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(_space(context, 26)),
                      topRight: Radius.circular(_space(context, 18)),
                      bottomRight: Radius.circular(_space(context, 18)),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      copy.appTitle,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2E1710),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: _space(context, 10)),
            _topActionButton(
              icon: plan.isPremium
                  ? Icons.workspace_premium_outlined
                  : Icons.lock_open_outlined,
              onTap: () => _showUpgradeSheet(PlanLimitReason.export),
              accent: const Color(0xFFFF8C64),
            ),
          ],
        ),
        SizedBox(height: _space(context, 14)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(_space(context, 20)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2F130D), Color(0xFF6F341E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_space(context, 30)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26A45D44),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                copy.moneySummary,
                style: text.titleLarge?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: _space(context, 18)),
              if (orderedTotals.isEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    copy.noMoneyGifts,
                    style: text.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: _space(context, 10),
                  runSpacing: _space(context, 10),
                  alignment: WrapAlignment.end,
                  children: orderedTotals
                      .map(
                        (entry) => Container(
                          constraints: BoxConstraints(
                            minWidth: _space(context, 112),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: _space(context, 14),
                            vertical: _space(context, 12),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(
                              _space(context, 18),
                            ),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: _space(context, 4)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatCurrencyAmount(entry.key, entry.value),
                                  style: text.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              SizedBox(height: _space(context, 16)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _space(context, 16),
                  vertical: _space(context, 10),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(_space(context, 999)),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  copy.countSummary(
                    model.monetaryGiftCount,
                    model.regularGiftCount,
                    model.entries.length,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: _space(context, 10)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _space(context, 16),
                  vertical: _space(context, 10),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(_space(context, 999)),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  plan.isPremium
                      ? copy.premiumPlan
                      : copy.planUsage(
                          model.entries.length,
                          plan.remainingFreeAiUses,
                        ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: _space(context, 18)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _summaryActionButton(
                    icon: Icons.delete_sweep_outlined,
                    onTap: model.entries.isEmpty
                        ? null
                        : _confirmDeleteAllEntries,
                  ),
                  SizedBox(width: _space(context, 8)),
                  _summaryActionButton(
                    icon: Icons.table_chart_outlined,
                    onTap: canExport
                        ? () => _runPremiumExport(model.exportToCsv)
                        : null,
                  ),
                  SizedBox(width: _space(context, 8)),
                  _summaryActionButton(
                    icon: Icons.picture_as_pdf_outlined,
                    onTap: canExport
                        ? () => _runPremiumExport(model.exportToPdf)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceCard(BuildContext context) {
    final copy = AppText.of(context);
    final iconColor = _isAiProcessing
        ? const Color(0xFF9E5A29)
        : (_isListening ? const Color(0xFF7A261A) : const Color(0xFF6B392A));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _space(context, 18),
        vertical: _space(context, 16),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(_space(context, 24)),
        border: Border.all(color: const Color(0xFFFFD9C9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AD19170),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: _space(context, 44),
            height: _space(context, 44),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E7),
              borderRadius: BorderRadius.circular(_space(context, 999)),
            ),
            alignment: Alignment.center,
            child: Text(
              'AI',
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: _space(context, 12)),
          Expanded(
            child: Text(
              _speechMessage.isEmpty ? copy.aiIdle : _speechMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4C4C4C),
              ),
            ),
          ),
          SizedBox(width: _space(context, 10)),
          Icon(Icons.help, color: iconColor),
        ],
      ),
    );
  }

  Widget _buildEntriesCard(BuildContext context, GiftListModel model) {
    final copy = AppText.of(context);
    final titleSize = (18 * _uiScale(context)).clamp(10.0, 15.0);

    if (model.entries.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(_space(context, 24)),
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: _space(context, 36),
                color: Colors.black45,
              ),
              SizedBox(height: _space(context, 10)),
              Text(
                copy.noGiftsYet,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: _space(context, 4)),
              Text(copy.emptyGiftsHint),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.transparent,
      elevation: 0,
      child: Column(
        children: [
          if (_lastTranscriptPreview.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: _space(context, 10)),
              child: Text(
                _lastTranscriptPreview,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF5A5A5A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: model.entries.length,
            separatorBuilder: (context, index) =>
                SizedBox(height: _space(context, 12)),
            itemBuilder: (context, index) {
              final entry = model.entries[index];
              final tint = _entryTint(index);
              final dateText = DateFormat('H:mm d/M/y').format(entry.created);
              final moneyItems = entry.moneyItems;

              return Container(
                padding: EdgeInsets.all(_space(context, 18)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(_space(context, 28)),
                  border: Border.all(color: tint, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0FE1A68A),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateText,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: _space(context, 10)),
                        IconButton(
                          onPressed: () => _confirmDeleteEntry(entry),
                          icon: const Icon(Icons.delete_outline),
                          color: const Color(0xFF2B120C),
                        ),
                      ],
                    ),
                    SizedBox(width: _space(context, 14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.guest,
                            style: TextStyle(
                              fontSize: titleSize + 6,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: _space(context, 8)),
                          Text(
                            entry.description,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF404040),
                            ),
                          ),
                          if (moneyItems.isNotEmpty) ...[
                            SizedBox(height: _space(context, 12)),
                            Wrap(
                              spacing: _space(context, 8),
                              runSpacing: _space(context, 8),
                              children: [
                                for (final item in moneyItems)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: _space(context, 12),
                                      vertical: _space(context, 8),
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2B120C),
                                      borderRadius: BorderRadius.circular(
                                        _space(context, 999),
                                      ),
                                    ),
                                    child: Text(
                                      _formatCurrencyAmount(
                                        item.currencyCode,
                                        item.amount,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: _space(context, 12)),
                    Container(
                      width: _space(context, 62),
                      height: _space(context, 62),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(
                          _space(context, 18),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _buildEntrySymbol(context, entry, moneyItems),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppText.of(context);
    final model = context.watch<GiftListModel>();
    final compactUi = _isCompact(context);
    final horizontalPadding = _space(context, 14);
    final topPadding = _space(context, 8);
    final bottomPadding = compactUi ? _space(context, 70) : _space(context, 90);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE8D6), Color(0xFFFFF4EA), Color(0xFFE3F6F5)],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _maxContentWidth(context)),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                children: [
                  _buildTopBar(context, model),
                  SizedBox(height: _space(context, 10)),
                  _buildVoiceCard(context),
                  SizedBox(height: _space(context, 12)),
                  _buildEntriesCard(context, model),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: compactUi
          ? FloatingActionButton(
              onPressed: _isAiProcessing ? null : _handleMicTap,
              mini: _isUltraCompact(context),
              tooltip: _isAiProcessing
                  ? copy.processing
                  : (_isListening ? copy.stopRecording : copy.voiceCapture),
              backgroundColor: const Color(0xFF2B120C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_space(context, 20)),
              ),
              child: Icon(
                _isListening ? Icons.stop_circle : Icons.mic_none_rounded,
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _isAiProcessing ? null : _handleMicTap,
              backgroundColor: const Color(0xFF2B120C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_space(context, 24)),
              ),
              icon: Icon(
                _isListening ? Icons.stop_circle : Icons.mic_none_rounded,
              ),
              label: Text(
                _isAiProcessing
                    ? copy.processing
                    : (_isListening ? copy.stopRecording : copy.voiceCapture),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _AiResult {
  const _AiResult({
    required this.transcript,
    required this.entries,
    required this.provider,
  });

  final String transcript;
  final List<_AiGiftParse> entries;
  final String provider;
}

class _AiGiftParse {
  const _AiGiftParse({
    required this.guest,
    required this.giftDescription,
    required this.amount,
    required this.currencyCode,
    required this.moneyItems,
    required this.occasion,
    required this.eventDate,
  });

  final String guest;
  final String giftDescription;
  final double? amount;
  final String? currencyCode;
  final List<_AiMoneyItem> moneyItems;
  final String occasion;
  final DateTime? eventDate;
}

class _AiMoneyItem {
  const _AiMoneyItem({required this.amount, required this.currencyCode});

  final double amount;
  final String currencyCode;
}

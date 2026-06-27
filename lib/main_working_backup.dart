import 'package:csv/csv.dart' show ListToCsvConverter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const GiftVoiceApp());
}

class GiftVoiceApp extends StatelessWidget {
  const GiftVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF006D77);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFFF8F2),
    );

    return ChangeNotifierProvider(
      create: (_) => GiftListModel(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Gift Voice Tracker',
        themeAnimationDuration: Duration.zero,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final tinyScreen = media.size.width < 430;
          final maxScale = tinyScreen ? 0.85 : (media.size.width < 560 ? 1.0 : 1.15);
          final scaler =
              tinyScreen ? const TextScaler.linear(0.62) : media.textScaler.clamp(maxScaleFactor: maxScale);
          return MediaQuery(
            data: media.copyWith(textScaler: scaler),
            child: child!,
          );
        },
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: const Color(0xFFFFF4EA),
          fontFamily: 'Palatino',
          visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          chipTheme: const ChipThemeData(
            labelStyle: TextStyle(fontSize: 10),
          ),
          cardTheme: CardThemeData(
            elevation: 4,
            color: Colors.white.withValues(alpha: 0.96),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        home: const GiftHomePage(),
      ),
    );
  }
}

class GiftEntry {
  GiftEntry({required this.guest, required this.description, DateTime? created})
      : created = created ?? DateTime.now();

  final String guest;
  final String description;
  final DateTime created;
}

class SpeechAnalysis {
  const SpeechAnalysis({
    required this.language,
    required this.confidence,
    required this.normalizedText,
    required this.guest,
    required this.gift,
    required this.amount,
    required this.keywords,
  });

  final String language;
  final String confidence;
  final String normalizedText;
  final String guest;
  final String gift;
  final String amount;
  final List<String> keywords;
}

class GiftListModel extends ChangeNotifier {
  final List<GiftEntry> _entries = [];

  List<GiftEntry> get entries => List.unmodifiable(_entries);

  void addEntry(GiftEntry entry) {
    _entries.add(entry);
    notifyListeners();
  }

  Future<void> exportToPdf() async {
    final pdf = pw.Document();
    final latin = await PdfGoogleFonts.notoSansRegular();
    final latinBold = await PdfGoogleFonts.notoSansBold();
    final arabic = await PdfGoogleFonts.notoNaskhArabicRegular();
    final hebrew = await PdfGoogleFonts.notoSansHebrewRegular();

    final bodyStyle = pw.TextStyle(
      font: latin,
      fontFallback: [arabic, hebrew],
    );
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
            _pdfCell(DateFormat.yMd().add_Hm().format(e.created), style: bodyStyle),
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
        (e) => [DateFormat.yMd().add_Hm().format(e.created), e.guest, e.description],
      ),
    ];

    final csvString = const ListToCsvConverter().convert(rows);
    await Share.share(csvString, subject: 'Gift list');
  }
}

class GiftHomePage extends StatefulWidget {
  const GiftHomePage({super.key});

  @override
  State<GiftHomePage> createState() => _GiftHomePageState();
}

class _GiftHomePageState extends State<GiftHomePage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechInitializing = false;
  bool _speechReady = false;
  String _lastWords = '';
  String _speechMessage = 'Voice is available on Web, Android, and iOS. Default language: العربية';
  bool _autoDetectLanguage = false;
  stt.LocaleName? _selectedLocale;
  stt.LocaleName? _systemLocale;
  List<stt.LocaleName> _locales = [];
  SpeechAnalysis? _lastAnalysis;
  String? _adaptiveLocaleId;
  String? _forcedLocaleId;
  String? _forcedLocaleLabel;

  final _guestController = TextEditingController();
  final _giftController = TextEditingController();

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

  bool get _voiceSupportedOnCurrentPlatform {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    if (_voiceSupportedOnCurrentPlatform) {
      _speechMessage = 'Tap Voice Capture to enable microphone and speech recognition.';
    }
  }

  @override
  void dispose() {
    _guestController.dispose();
    _giftController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (_speechInitializing || !_voiceSupportedOnCurrentPlatform) return;
    setState(() {
      _speechInitializing = true;
      _speechMessage = 'Preparing voice services...';
    });

    final available = await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );

    if (!mounted) return;

    if (available) {
      final locales = await _speech.locales();
      final systemLocale = await _speech.systemLocale();
      if (!mounted) return;
      setState(() {
        _speechInitializing = false;
        _speechReady = true;
        _locales = locales;
        _systemLocale = systemLocale;
        _selectedLocale = _preferredLocale('ar') ??
            _preferredLocale('en') ??
            locales.firstWhereOrNull((l) => l.localeId == 'en_US') ??
            (locales.isNotEmpty ? locales.first : null);
        _speechMessage = locales.isEmpty
            ? 'Voice ready but no locales were reported.'
            : (_selectedLocale != null
                ? 'Voice ready. Default language: ${_selectedLocale!.name}'
                : 'Voice ready.');
      });
    } else {
      setState(() {
        _speechInitializing = false;
        _speechReady = false;
        _speechMessage = 'Voice unavailable. Check browser/app microphone permissions.';
      });
    }
  }

  Future<void> _startListening() async {
    if (!_voiceSupportedOnCurrentPlatform) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      setState(() {
        _speechMessage =
            'Voice on macOS is temporarily disabled for stability. Use Web/Android/iOS for live voice capture.';
      });
      return;
    }
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) return;
    }

    final localeId = _effectiveLocaleId();
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          _lastAnalysis = _analyzeSpeech(_lastWords);
        });
      },
      localeId: localeId,
    );

    if (!mounted) return;
    setState(() => _isListening = true);
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
    _parseEntry(_lastWords);
  }

  void _addManualEntry() {
    final guest = _guestController.text.trim();
    final gift = _giftController.text.trim();
    if (guest.isEmpty || gift.isEmpty) return;
    context.read<GiftListModel>().addEntry(GiftEntry(guest: guest, description: gift));
    _guestController.clear();
    _giftController.clear();
  }

  void _parseEntry(String text) {
    if (text.isEmpty) return;
    final analysis = _analyzeSpeech(text);
    setState(() {
      _lastAnalysis = analysis;
      _adaptiveLocaleId = _localeForLanguageName(analysis.language);
      if (_autoDetectLanguage && _adaptiveLocaleId != null) {
        _selectedLocale = _locales.firstWhereOrNull((l) => l.localeId == _adaptiveLocaleId);
      }
    });
    final guest = analysis.guest.isEmpty ? 'Unknown' : analysis.guest;
    final description = [analysis.amount, analysis.gift]
        .where((v) => v.trim().isNotEmpty)
        .join(' ')
        .trim();
    context.read<GiftListModel>().addEntry(
          GiftEntry(
            guest: guest,
            description: description.isEmpty ? analysis.normalizedText : description,
          ),
        );
  }

  SpeechAnalysis _analyzeSpeech(String text) {
    final normalized = _normalizeSpeechText(text);
    final cleaned = _stripFillerWords(normalized);
    final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    int arabicChars = 0;
    int hebrewChars = 0;
    int latinChars = 0;
    for (final rune in cleaned.runes) {
      if (rune >= 0x0600 && rune <= 0x06FF) arabicChars++;
      if (rune >= 0x0590 && rune <= 0x05FF) hebrewChars++;
      if ((rune >= 0x0041 && rune <= 0x005A) || (rune >= 0x0061 && rune <= 0x007A)) latinChars++;
    }
    final totalLetters = arabicChars + hebrewChars + latinChars;
    String language = 'Unknown';
    int dominant = 0;
    if (totalLetters > 0) {
      dominant = [arabicChars, hebrewChars, latinChars].reduce((a, b) => a > b ? a : b);
      if (dominant == arabicChars && arabicChars > 0) language = 'Arabic';
      if (dominant == hebrewChars && hebrewChars > 0) language = 'Hebrew';
      if (dominant == latinChars && latinChars > 0) language = 'English';
      if (arabicChars > 0 && hebrewChars > 0 && latinChars > 0) language = 'Mixed';
    }
    final confidence = totalLetters == 0 ? '0%' : '${((dominant / totalLetters) * 100).round()}%';

    final amountMatch = RegExp(r'(\$|€|£|₪|aed|usd|eur|ils)?\s*([0-9]+(?:[.,][0-9]+)?)', caseSensitive: false)
        .firstMatch(cleaned);
    final amount = amountMatch == null ? '' : amountMatch.group(0)!.trim();

    final splitRegex = RegExp(r'\b(from|for|to)\b|(?:\s)(من|ل|الى|إلى)(?:\s)|(?:\s)(מאת|מ|ל|עבור)(?:\s)',
        caseSensitive: false);
    String guest = '';
    String gift = cleaned;
    final split = cleaned.split(splitRegex);
    if (split.length >= 2) {
      guest = split.first.trim();
      gift = split.last.trim();
    }
    if (guest.isEmpty && tokens.isNotEmpty) {
      final amountIndex = tokens.indexWhere((t) => RegExp(r'^[\$\€\£\₪]?[0-9]+([.,][0-9]+)?$').hasMatch(t));
      if (amountIndex > 0) {
        guest = tokens.take(amountIndex).join(' ');
        gift = tokens.skip(amountIndex + 1).join(' ');
      } else {
        guest = tokens.take(tokens.length > 2 ? 2 : 1).join(' ');
        gift = tokens.length > 2 ? tokens.skip(2).join(' ') : cleaned;
      }
    }

    final keywordPool = <String>[
      'gift', 'cash', 'money', 'usd', 'eur', 'ils', 'shekel',
      'هدية', 'نقد', 'فلوس', 'شيكل',
      'מתנה', 'מזומן', 'כסף', 'שקל',
    ];
    final foundKeywords = keywordPool.where((k) => cleaned.toLowerCase().contains(k.toLowerCase())).toList();

    return SpeechAnalysis(
      language: language,
      confidence: confidence,
      normalizedText: cleaned,
      guest: guest,
      gift: gift,
      amount: amount,
      keywords: foundKeywords,
    );
  }

  String _normalizeSpeechText(String text) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var out = text.trim();
    for (var i = 0; i < arabicDigits.length; i++) {
      out = out.replaceAll(arabicDigits[i], '$i');
    }
    out = out.replaceAll('٫', '.').replaceAll('،', ',');
    return out.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _stripFillerWords(String text) {
    final fillers = <String>{
      // English
      'bring', 'brings', 'bringing', 'brought',
      'provide', 'provides', 'providing', 'provided',
      'give', 'gives', 'giving', 'gave',
      'gifted', 'donated', 'donate', 'sent',
      // Arabic
      'جاب', 'جابت', 'جبت', 'جابوا',
      'جلب', 'جلبت', 'جلبوا',
      'احضر', 'أحضر', 'احضرت', 'أحضرت',
      'قدم', 'قدمت', 'قدموا',
      'اعطى', 'أعطى', 'عطى', 'أعطت', 'عطت',
      // Hebrew
      'הביא', 'הביאה', 'הביאו', 'מביא', 'מביאה',
      'נתן', 'נתנה', 'נותן', 'נותנת',
      'סיפק', 'סיפקה', 'מספק', 'מספקת',
    };

    final tokens = text.split(RegExp(r'\s+'));
    final kept = <String>[];
    for (final token in tokens) {
      final cleaned = token.replaceAll(RegExp(r'^[^\p{L}\p{N}\$₪€£]+|[^\p{L}\p{N}\$₪€£]+$', unicode: true), '');
      if (cleaned.isEmpty) continue;
      if (fillers.contains(cleaned.toLowerCase())) continue;
      kept.add(token);
    }
    return kept.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _effectiveLocaleId() {
    if (!_autoDetectLanguage) return _forcedLocaleId ?? _selectedLocale?.localeId;
    return _adaptiveLocaleId ?? _selectedLocale?.localeId ?? _systemLocale?.localeId;
  }

  stt.LocaleName? _preferredLocale(String prefix) {
    final p = prefix.toLowerCase();
    return _locales.firstWhereOrNull((l) {
          final id = l.localeId.toLowerCase();
          return id == p || id.startsWith('${p}_') || id.startsWith('$p-');
        }) ??
        _locales.firstWhereOrNull((l) {
          final name = l.name.toLowerCase();
          if (p == 'ar') return name.contains('arab');
          if (p == 'he') return name.contains('hebrew') || name.contains('עבר');
          if (p == 'en') return name.contains('english');
          return false;
        });
  }

  String? _localeForLanguageName(String language) {
    switch (language) {
      case 'Arabic':
        return _preferredLocale('ar')?.localeId;
      case 'Hebrew':
        return _preferredLocale('he')?.localeId;
      case 'English':
        return _preferredLocale('en')?.localeId;
      default:
        return null;
    }
  }

  void _selectLanguagePreset(String code) {
    stt.LocaleName? locale;
    String fallbackId = 'en-US';
    String fallbackLabel = 'English (forced)';
    switch (code) {
      case 'ar':
        locale = _preferredLocale('ar');
        fallbackId = 'ar-SA';
        fallbackLabel = 'العربية (forced)';
        break;
      case 'he':
        locale = _preferredLocale('he');
        fallbackId = 'he-IL';
        fallbackLabel = 'עברית (forced)';
        break;
      default:
        locale = _preferredLocale('en');
        fallbackId = 'en-US';
        fallbackLabel = 'English (forced)';
    }
    setState(() {
      _autoDetectLanguage = false;
      if (locale != null) {
        _selectedLocale = locale;
        _forcedLocaleId = null;
        _forcedLocaleLabel = null;
        _speechMessage = 'Recognition language set to $locale.name.';
      } else {
        _forcedLocaleId = fallbackId;
        _forcedLocaleLabel = fallbackLabel;
        _speechMessage = 'Locale not listed by device. Using fallback $fallbackId.';
      }
    });
  }

  List<stt.LocaleName> _visibleLocales() {
    final items = [..._locales];
    void ensure(String id, String name) {
      final exists = items.any((l) => l.localeId.toLowerCase() == id.toLowerCase());
      if (!exists) items.add(stt.LocaleName(id, name));
    }

    ensure('ar-SA', 'Arabic (forced)');
    ensure('he-IL', 'Hebrew (forced)');
    ensure('en-US', 'English (forced)');
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<GiftListModel>();
    final compactUi = _isCompact(context);
    final horizontalPadding = _space(context, 14);
    final topPadding = _space(context, 8);
    final bottomPadding = compactUi ? _space(context, 70) : _space(context, 90);
    final voiceAction = (_speechReady && _locales.isNotEmpty)
        ? (_isListening ? _stopListening : _startListening)
        : (_speechInitializing ? null : _startListening);

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
                padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, bottomPadding),
                children: [
                  _buildTopBar(context, model),
                  _buildQuickAddCard(),
                  SizedBox(height: _space(context, 10)),
                  _voiceSupportedOnCurrentPlatform ? _buildVoiceCard() : _buildVoiceUnavailableCard(),
                  SizedBox(height: _space(context, 12)),
                  _buildEntriesCard(model),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: !_voiceSupportedOnCurrentPlatform
          ? null
          : (compactUi
                ? FloatingActionButton(
                    onPressed: voiceAction,
                    mini: _isUltraCompact(context),
                    tooltip: _speechInitializing ? 'Starting...' : (_isListening ? 'Stop listening' : 'Voice capture'),
                    child: Icon(_isListening ? Icons.stop_circle : Icons.graphic_eq),
                  )
                : FloatingActionButton.extended(
                    onPressed: voiceAction,
                    icon: Icon(_isListening ? Icons.stop_circle : Icons.graphic_eq),
                    label: Text(
                      _speechInitializing ? 'Starting...' : (_isListening ? 'Stop Listening' : 'Voice Capture'),
                    ),
                  )),
    );
  }

  Widget _buildTopBar(BuildContext context, GiftListModel model) {
    final text = Theme.of(context).textTheme;
    final canExport = model.entries.isNotEmpty;
    final compactActions = _isCompact(context);
    final ultraCompactActions = _isUltraCompact(context);
    final scale = _uiScale(context);

    return Container(
      margin: EdgeInsets.only(bottom: _space(context, 10)),
      padding: EdgeInsets.fromLTRB(_space(context, 16), _space(context, 16), _space(context, 16), _space(context, 14)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_space(context, 22)),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A9396), Color(0xFF005F73)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gift Voice Tracker',
            style: text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              fontSize: ((text.headlineSmall?.fontSize ?? 24) * scale).clamp(10.0, 16.0),
            ),
          ),
          SizedBox(height: _space(context, 6)),
          Text(
            '${model.entries.length} entries captured',
            style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          SizedBox(height: _space(context, 14)),
          if (ultraCompactActions) ...[
            Wrap(
              spacing: _space(context, 8),
              runSpacing: _space(context, 8),
              children: [
                IconButton.filled(
                  onPressed: canExport ? model.exportToPdf : null,
                  tooltip: 'Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFEE9B00)),
                ),
                IconButton.filled(
                  onPressed: canExport ? model.exportToCsv : null,
                  tooltip: 'Export CSV',
                  icon: const Icon(Icons.table_view_outlined),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFCA6702)),
                ),
              ],
            ),
          ] else if (compactActions) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canExport ? model.exportToPdf : null,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEE9B00)),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ),
            SizedBox(height: _space(context, 8)),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canExport ? model.exportToCsv : null,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFCA6702)),
                child: const Text('CSV'),
              ),
            ),
          ] else
            Wrap(
              spacing: _space(context, 8),
              runSpacing: _space(context, 8),
              children: [
                FilledButton.icon(
                  onPressed: canExport ? model.exportToPdf : null,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEE9B00)),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export PDF'),
                ),
                FilledButton.icon(
                  onPressed: canExport ? model.exportToCsv : null,
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFCA6702)),
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAddCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(_space(context, 14)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760 || _isCompact(context);
            final titleSize = (18 * _uiScale(context)).clamp(10.0, 15.0);
            final guest = TextField(
              controller: _guestController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Guest name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            );
            final gift = TextField(
              controller: _giftController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Gift / amount',
                prefixIcon: Icon(Icons.card_giftcard_outlined),
              ),
              onSubmitted: (_) => _addManualEntry(),
            );
            final add = FilledButton.icon(
              onPressed: _addManualEntry,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Entry'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick Add', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600)),
                  SizedBox(height: _space(context, 12)),
                  guest,
                  SizedBox(height: _space(context, 10)),
                  gift,
                  SizedBox(height: _space(context, 10)),
                  SizedBox(width: double.infinity, child: add),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Add', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600)),
                SizedBox(height: _space(context, 12)),
                Row(
                  children: [
                    Expanded(child: guest),
                    SizedBox(width: _space(context, 10)),
                    Expanded(child: gift),
                    SizedBox(width: _space(context, 10)),
                    add,
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVoiceCard() {
    final statusColor = _speechReady ? const Color(0xFF0E7A6D) : const Color(0xFFC43C30);
    final transcript = _lastWords.isEmpty ? 'Nothing recognized yet.' : _lastWords;
    final titleSize = (18 * _uiScale(context)).clamp(10.0, 15.0);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(_space(context, 14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: _space(context, 8),
              runSpacing: _space(context, 8),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.multitrack_audio_outlined),
                Text('Voice Capture', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600)),
                Chip(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  label: Text(
                    _speechInitializing ? 'Starting' : (_speechReady ? 'Ready' : 'Idle'),
                    style: TextStyle(color: statusColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: _space(context, 8)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto detect language'),
              subtitle: Text(
                _autoDetectLanguage
                    ? 'Adaptive mode${_adaptiveLocaleId != null ? ': $_adaptiveLocaleId' : ''}'
                    : (_forcedLocaleId != null
                        ? 'Using forced locale: $_forcedLocaleId'
                        : 'Using selected language'),
              ),
              value: _autoDetectLanguage,
              onChanged: (value) => setState(() => _autoDetectLanguage = value),
            ),
            Wrap(
              spacing: _space(context, 6),
              runSpacing: _space(context, 6),
              children: [
                FilledButton(
                  onPressed: () => _selectLanguagePreset('en'),
                  child: const Text('EN'),
                ),
                FilledButton(
                  onPressed: () => _selectLanguagePreset('ar'),
                  child: const Text('AR'),
                ),
                FilledButton(
                  onPressed: () => _selectLanguagePreset('he'),
                  child: const Text('HE'),
                ),
                ActionChip(
                  label: const Text('English / العربية / עברית'),
                  onPressed: () {},
                ),
                ActionChip(
                  label: const Text('English'),
                  onPressed: () => _selectLanguagePreset('en'),
                ),
                ActionChip(
                  label: const Text('العربية'),
                  onPressed: () => _selectLanguagePreset('ar'),
                ),
                ActionChip(
                  label: const Text('עברית'),
                  onPressed: () => _selectLanguagePreset('he'),
                ),
              ],
            ),
            SizedBox(height: _space(context, 8)),
            DropdownButtonFormField<stt.LocaleName>(
              key: ValueKey('locale-${_selectedLocale?.localeId}-${_locales.length}'),
              initialValue: _selectedLocale,
              onChanged: _visibleLocales().isNotEmpty
                  ? (value) {
                      if (value == null) return;
                      final isNative = _locales.any((l) => l.localeId.toLowerCase() == value.localeId.toLowerCase());
                      setState(() {
                        _selectedLocale = value;
                        _autoDetectLanguage = false;
                        if (isNative) {
                          _forcedLocaleId = null;
                          _forcedLocaleLabel = null;
                        } else {
                          _forcedLocaleId = value.localeId;
                          _forcedLocaleLabel = value.name;
                        }
                      });
                    }
                  : null,
              items: _visibleLocales().map((loc) => DropdownMenuItem(value: loc, child: Text(loc.name))).toList(),
              decoration: const InputDecoration(
                labelText: 'Recognition language',
                prefixIcon: Icon(Icons.language_outlined),
              ),
            ),
            if (_forcedLocaleLabel != null)
              Padding(
                padding: EdgeInsets.only(top: _space(context, 6)),
                child: Text(
                  _forcedLocaleLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            SizedBox(height: _space(context, 10)),
            Text(_speechMessage, style: TextStyle(color: statusColor, fontWeight: FontWeight.w500)),
            SizedBox(height: _space(context, 8)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(_space(context, 12)),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F6),
                borderRadius: BorderRadius.circular(_space(context, 12)),
                border: Border.all(color: const Color(0xFFD5E0DB)),
              ),
              child: Text(
                transcript,
                style: TextStyle(
                  color: _lastWords.isEmpty ? Colors.black45 : Colors.black87,
                  fontStyle: _lastWords.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            if (_lastAnalysis != null) ...[
              SizedBox(height: _space(context, 8)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(_space(context, 10)),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF6),
                  borderRadius: BorderRadius.circular(_space(context, 10)),
                  border: Border.all(color: const Color(0xFFE8E1C7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speech Analysis: ${_lastAnalysis!.language} (${_lastAnalysis!.confidence})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('Guest: ${_lastAnalysis!.guest.isEmpty ? '-' : _lastAnalysis!.guest}'),
                    Text('Gift: ${_lastAnalysis!.gift.isEmpty ? '-' : _lastAnalysis!.gift}'),
                    Text('Amount: ${_lastAnalysis!.amount.isEmpty ? '-' : _lastAnalysis!.amount}'),
                    Text(
                      'Keywords: ${_lastAnalysis!.keywords.isEmpty ? '-' : _lastAnalysis!.keywords.join(', ')}',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceUnavailableCard() {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.mic_off_outlined),
        title: Text('Voice Capture Unavailable on macOS'),
        subtitle: Text('Use quick add here, or run on web/mobile for live voice input.'),
      ),
    );
  }

  Widget _buildEntriesCard(GiftListModel model) {
    final compactRows = _isCompact(context);
    final titleSize = (18 * _uiScale(context)).clamp(10.0, 15.0);

    if (model.entries.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(_space(context, 24)),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: _space(context, 36), color: Colors.black45),
              SizedBox(height: _space(context, 10)),
              Text('No gifts yet', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600)),
              SizedBox(height: _space(context, 4)),
              const Text('Add an entry manually or capture one with voice.'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(_space(context, 10), _space(context, 10), _space(context, 10), _space(context, 6)),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _space(context, 6), vertical: _space(context, 4)),
              child: Wrap(
                spacing: _space(context, 8),
                runSpacing: _space(context, 4),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.list_alt_outlined),
                  Text('Gift Entries', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: model.entries.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = model.entries[index];
                final dateText = DateFormat('MMM d, h:mm a').format(entry.created);
                return ListTile(
                  dense: compactRows,
                  contentPadding: EdgeInsets.symmetric(horizontal: _space(context, 8), vertical: _space(context, 2)),
                  leading: CircleAvatar(
                    radius: compactRows ? _space(context, 12) : _space(context, 16),
                    backgroundColor: const Color(0xFFDCEDE7),
                    child: Text(entry.guest.isEmpty ? '?' : entry.guest[0].toUpperCase()),
                  ),
                  title: Text(entry.guest, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: compactRows
                      ? Text('${entry.description}\n$dateText')
                      : Text(entry.description),
                  trailing: compactRows
                      ? null
                      : Text(
                          dateText,
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

extension IterableX<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

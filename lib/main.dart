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
  runApp(GiftVoiceApp(model: model, settings: settings));
}

class GiftVoiceApp extends StatelessWidget {
  const GiftVoiceApp({required this.model, required this.settings, super.key});

  final GiftListModel model;
  final AppSettings settings;

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
      ],
      child: Consumer<AppSettings>(
        builder: (context, appSettings, _) {
          final lang = appSettings.uiLanguageCode;
          final rtl = _isRtlLanguage(lang);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Event Gift Keeper',
            locale: Locale(lang),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: _supportedMaterialLocales,
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();
              return Directionality(
                textDirection:
                    rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
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
  String _uiLanguageCode = 'en';

  String get uiLanguageCode => _uiLanguageCode;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final fallback = ui.PlatformDispatcher.instance.locale.languageCode;
    final code = prefs.getString(_uiLanguageKey) ?? fallback;
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
    if (_supportedInterfaceLanguageCodes.contains(normalized)) return normalized;
    return 'en';
  }
}

class GiftEntry {
  GiftEntry({
    this.id,
    required this.guest,
    required this.description,
    this.amount,
    this.currencyCode,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  final String? id;
  final String guest;
  final String description;
  final double? amount;
  final String? currencyCode;
  final DateTime created;

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'guest': guest,
      'description': description,
      'amount': amount,
      'currencyCode': currencyCode,
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
      'created': created.toIso8601String(),
    };
  }

  static GiftEntry fromStorageMap(Map<dynamic, dynamic> raw) {
    final createdRaw = raw['created']?.toString();
    return GiftEntry(
      id: raw['id']?.toString(),
      guest: raw['guest']?.toString() ?? 'Unknown',
      description: raw['description']?.toString() ?? '',
      amount: raw['amount'] == null
          ? null
          : double.tryParse(raw['amount'].toString().replaceAll(',', '.')),
      currencyCode: raw['currencyCode']?.toString(),
      created: DateTime.tryParse(createdRaw ?? '') ?? DateTime.now(),
    );
  }

  static GiftEntry fromFirestoreDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdRaw = data['created'];
    final created = createdRaw is Timestamp
        ? createdRaw.toDate()
        : createdRaw is DateTime
            ? createdRaw
            : DateTime.now();
    return GiftEntry(
      id: doc.id,
      guest: data['guest']?.toString() ?? 'Unknown',
      description: data['description']?.toString() ?? '',
      amount: data['amount'] == null
          ? null
          : double.tryParse(data['amount'].toString().replaceAll(',', '.')),
      currencyCode: data['currencyCode']?.toString(),
      created: created,
    );
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
      if (entry.amount == null || entry.amount! <= 0) continue;
      final code = (entry.currencyCode ?? 'ILS').toUpperCase();
      totals.update(code, (value) => value + entry.amount!, ifAbsent: () => entry.amount!);
    }
    return totals;
  }

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
      _entries.removeWhere((item) =>
          item.created == entry.created &&
          item.guest == entry.guest &&
          item.description == entry.description);
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
    final headerStyle = pw.TextStyle(font: latinBold, fontFallback: [arabic, hebrew]);

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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
    if (_isLoading) return;
    if (!widget.firebaseReady) {
      setState(() {
        _errorMessage = 'Firebase is not configured correctly on this device.';
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
        setState(() => _errorMessage = 'Sign-in was canceled.');
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
      setState(() => _errorMessage = error.message ?? 'Sign-in failed.');
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() => _errorMessage = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      'Event Gift Keeper',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Speak and save every gift.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _signIn,
                        icon: const Icon(Icons.login),
                        label: Text(_isLoading ? 'Signing in...' : 'Continue with Google'),
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
  String _speechMessage = 'AI mode is active. Tap mic to record and analyze.';
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

  ({double? amount, String? currencyCode}) _extractAmountAndCurrency(String text) {
    final normalized = text.replaceAll(',', '.');
    final patterns = <({RegExp regex, String code})>[
      (regex: RegExp(r'₪\s*([0-9]+(?:\.[0-9]+)?)'), code: 'ILS'),
      (regex: RegExp(r'\bils\b\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false), code: 'ILS'),
      (regex: RegExp(r'\$\s*([0-9]+(?:\.[0-9]+)?)'), code: 'USD'),
      (regex: RegExp(r'\busd\b\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false), code: 'USD'),
      (regex: RegExp(r'€\s*([0-9]+(?:\.[0-9]+)?)'), code: 'EUR'),
      (regex: RegExp(r'\beur\b\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false), code: 'EUR'),
    ];

    for (final item in patterns) {
      final match = item.regex.firstMatch(normalized);
      if (match != null) {
        return (
          amount: double.tryParse(match.group(1)!),
          currencyCode: item.code,
        );
      }
    }

    final bareNumber = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(normalized);
    if (bareNumber != null) {
      return (
        amount: double.tryParse(bareNumber.group(1)!),
        currencyCode: 'ILS',
      );
    }

    return (amount: null, currencyCode: null);
  }

  Future<void> _confirmDeleteEntry(GiftEntry entry) async {
    final model = context.read<GiftListModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete entry?'),
          content: Text('Remove ${entry.guest} - ${entry.description}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC43C30)),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await model.removeEntry(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${entry.guest}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  Future<void> _confirmDeleteAllEntries() async {
    final model = context.read<GiftListModel>();
    final controller = TextEditingController();
    const protectionCode = '2400';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text(
            'Delete All Entries',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will permanently remove all gift records.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: 'Enter protection code',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Protection code: 2400',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  controller.text.trim() == protectionCode,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5C6FAE),
              ),
              child: const Text('Confirm Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete all canceled or protection code was incorrect.')),
      );
      return;
    }

    try {
      await model.deleteAllEntries();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All entries deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete all failed: $error')),
      );
    }
  }

  Future<void> _openSettings() async {
    final settings = context.read<AppSettings>();
    final current = settings.uiLanguageCode;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                const Text(
                  'App language',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _languageChip(settings, 'en', 'English', current),
                    _languageChip(settings, 'ar', 'العربية', current),
                    _languageChip(settings, 'he', 'עברית', current),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _languageChip(
    AppSettings settings,
    String code,
    String label,
    String current,
  ) {
    final selected = current == code;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) async {
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
      await _startAiCapture();
    }
  }

  Future<void> _startAiCapture() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        _speechMessage = 'Microphone permission is missing. Please allow microphone access.';
      });
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/gift_ai_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
      _speechMessage = 'Recording for AI... it will auto-stop after 8 seconds for faster results.';
    });
  }

  Future<void> _stopAiCaptureAndProcess() async {
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
          ? 'AI is transcribing your speech...'
          : 'AI is transcribing ${recordedFor.inSeconds.clamp(1, _maxRecordingLength.inSeconds)} seconds of audio...';
    });

    if (path == null || path.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isAiProcessing = false;
        _speechMessage = 'No audio captured. Please try again.';
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

      final aiParse = aiResult.parsed;
      if (aiParse != null) {
        final description = _composeAiDescription(aiParse, aiResult.transcript);
        await context.read<GiftListModel>().addEntry(
          GiftEntry(
            guest: aiParse.guest.trim().isEmpty ? 'Unknown' : aiParse.guest,
            description: description,
            amount: aiParse.amount,
            currencyCode: aiParse.currencyCode,
            created: aiParse.eventDate,
          ),
        );
        if (!mounted) return;
        setState(() {
          _speechMessage = 'AI (${aiResult.provider}) captured: ${aiParse.guest.isEmpty ? 'Unknown' : aiParse.guest}';
        });
      } else {
        final fallback = _extractAmountAndCurrency(aiResult.transcript);
        await context.read<GiftListModel>().addEntry(
          GiftEntry(
            guest: 'Unknown',
            description: aiResult.transcript,
            amount: fallback.amount,
            currencyCode: fallback.currencyCode,
          ),
        );
        if (!mounted) return;
        setState(() {
          _speechMessage = 'AI captured transcript without full parsing.';
        });
      }
    } catch (error, stackTrace) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _isAiProcessing = false;
        _speechMessage = 'AI transcription failed: $error';
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
      throw Exception(error.message ?? 'Failed to refresh your sign-in session.');
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
      final parsed =
          parsedMap is Map ? _parseAiGiftParseFromMap(parsedMap) : null;
      final provider = data['provider']?.toString().trim() ?? 'Gemini';

      if (_isPlaceholderAiText(transcript)) {
        throw Exception('AI returned placeholder text instead of a transcription.');
      }

      if (transcript.isEmpty && parsed == null) {
        throw Exception('AI service returned no usable transcript or fields.');
      }

      return _AiResult(
        transcript: transcript,
        parsed: parsed,
        provider: provider.isEmpty ? 'Gemini' : provider,
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        return _transcribeAndAnalyzeWithAiHttp(audioBytes, languageHint);
      }
      throw Exception(error.message ?? error.code);
    }
  }

  Future<_AiResult> _transcribeAndAnalyzeWithAiHttp(
    List<int> audioBytes,
    String? languageHint,
  ) async {
    const projectId = 'gift-tracker-98088';
    final uri = Uri.parse(
      'https://us-central1-$projectId.cloudfunctions.net/aiTranscribeAndParseHttp',
    );

    final response = await http
        .post(
          uri,
          headers: const <String, String>{'Content-Type': 'application/json'},
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
    final parsed = parsedMap is Map ? _parseAiGiftParseFromMap(parsedMap) : null;
    final provider = data['provider']?.toString().trim() ?? 'Gemini';

    if (_isPlaceholderAiText(transcript)) {
      throw Exception('AI returned placeholder text instead of a transcription.');
    }

    if (transcript.isEmpty && parsed == null) {
      throw Exception('AI service returned no usable transcript or fields.');
    }

    return _AiResult(
      transcript: transcript,
      parsed: parsed,
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
    final giftDescription = parsedRaw['gift_description']?.toString().trim() ?? '';
    final occasion = parsedRaw['occasion']?.toString().trim() ?? '';
    final eventDateRaw = parsedRaw['event_date']?.toString().trim();
    final currencyCodeRaw = parsedRaw['currency_code']?.toString().toUpperCase();
    final currencyCode = switch (currencyCodeRaw) {
      'USD' => 'USD',
      'EUR' => 'EUR',
      'ILS' => 'ILS',
      _ => null,
    };
    final amountRaw = parsedRaw['amount'];
    final amount = amountRaw == null ? null : double.tryParse(amountRaw.toString().replaceAll(',', '.'));

    return _AiGiftParse(
      guest: guest,
      giftDescription: giftDescription,
      amount: amount,
      currencyCode: currencyCode,
      occasion: occasion,
      eventDate: _parseAiDate(eventDateRaw),
    );
  }

  DateTime? _parseAiDate(String? raw) {
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _composeAiDescription(_AiGiftParse ai, String transcript) {
    final parts = <String>[];
    if (ai.giftDescription.isNotEmpty) {
      parts.add(ai.giftDescription);
    } else {
      parts.add(transcript);
    }
    if (ai.occasion.isNotEmpty) parts.add('for ${ai.occasion}');
    final base = parts.join(' ').trim();
    if (ai.amount == null) return base;
    final code = ai.currencyCode ?? 'ILS';
    return '$base ${_formatAmount(ai.amount!)} ${_currencySymbol(code)}'.trim();
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
    final text = Theme.of(context).textTheme;
    final totals = _totalsByCurrency(model);
    final canExport = model.entries.isNotEmpty;
    final primaryCode = totals.isNotEmpty ? totals.keys.first : 'ILS';
    final primaryAmount = totals.isNotEmpty ? totals[primaryCode]! : 0.0;

    return Column(
      children: [
        Row(
          children: [
            _topActionButton(
              icon: Icons.logout_rounded,
              onTap: _signOut,
            ),
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
                      'מעקב מתנות',
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
              icon: Icons.card_giftcard_outlined,
              onTap: () {},
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
                'סך ערך האירוע',
                style: text.titleLarge?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: _space(context, 18)),
              Text(
                _formatCurrencyAmount(primaryCode, primaryAmount),
                style: text.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
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
                  '${model.entries.length} מתנות',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (totals.length > 1) ...[
                SizedBox(height: _space(context, 12)),
                Wrap(
                  spacing: _space(context, 8),
                  runSpacing: _space(context, 8),
                  alignment: WrapAlignment.end,
                  children: totals.entries
                      .map(
                        (entry) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: _space(context, 10),
                            vertical: _space(context, 6),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(_space(context, 999)),
                          ),
                          child: Text(
                            _formatCurrencyAmount(entry.key, entry.value),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              SizedBox(height: _space(context, 18)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _summaryActionButton(
                    icon: Icons.delete_sweep_outlined,
                    onTap: model.entries.isEmpty ? null : _confirmDeleteAllEntries,
                  ),
                  SizedBox(width: _space(context, 8)),
                  _summaryActionButton(
                    icon: Icons.table_chart_outlined,
                    onTap: canExport ? model.exportToCsv : null,
                  ),
                  SizedBox(width: _space(context, 8)),
                  _summaryActionButton(
                    icon: Icons.picture_as_pdf_outlined,
                    onTap: canExport ? model.exportToPdf : null,
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
              _speechMessage,
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
            separatorBuilder: (context, index) => SizedBox(height: _space(context, 12)),
            itemBuilder: (context, index) {
              final entry = model.entries[index];
              final tint = _entryTint(index);
              final dateText = DateFormat('H:mm d/M/y').format(entry.created);
              final amountText = entry.amount == null
                  ? null
                  : _formatCurrencyAmount(entry.currencyCode ?? 'ILS', entry.amount!);

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
                        if (amountText != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: _space(context, 12),
                              vertical: _space(context, 8),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B120C),
                              borderRadius: BorderRadius.circular(_space(context, 999)),
                            ),
                            child: Text(
                              amountText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        SizedBox(height: _space(context, 14)),
                        Text(
                          dateText,
                          style: const TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: _space(context, 14)),
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
                        ],
                      ),
                    ),
                    SizedBox(width: _space(context, 12)),
                    Container(
                      width: _space(context, 62),
                      height: _space(context, 62),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(_space(context, 18)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _currencySymbol(entry.currencyCode ?? 'ILS'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6A3C31),
                        ),
                      ),
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
                padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, bottomPadding),
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
              tooltip: _isAiProcessing ? 'Processing...' : (_isListening ? 'Stop recording' : 'Voice capture'),
              backgroundColor: const Color(0xFF2B120C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_space(context, 20)),
              ),
              child: Icon(_isListening ? Icons.stop_circle : Icons.mic_none_rounded),
            )
          : FloatingActionButton.extended(
              onPressed: _isAiProcessing ? null : _handleMicTap,
              backgroundColor: const Color(0xFF2B120C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_space(context, 24)),
              ),
              icon: Icon(_isListening ? Icons.stop_circle : Icons.mic_none_rounded),
              label: Text(_isAiProcessing ? 'Processing...' : (_isListening ? 'Stop Recording' : 'Voice Capture')),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _AiResult {
  const _AiResult({
    required this.transcript,
    required this.parsed,
    required this.provider,
  });

  final String transcript;
  final _AiGiftParse? parsed;
  final String provider;
}

class _AiGiftParse {
  const _AiGiftParse({
    required this.guest,
    required this.giftDescription,
    required this.amount,
    required this.currencyCode,
    required this.occasion,
    required this.eventDate,
  });

  final String guest;
  final String giftDescription;
  final double? amount;
  final String? currencyCode;
  final String occasion;
  final DateTime? eventDate;
}

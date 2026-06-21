import 'dart:async';
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'services/push_notification_service.dart';
import 'services/revenue_cat_service.dart';

const _enableAppCheck = bool.fromEnvironment('ENABLE_APP_CHECK');
const _enableCrashlytics = bool.fromEnvironment(
  'ENABLE_CRASHLYTICS',
  defaultValue: true,
);
const _firebaseStartupTimeout = Duration(seconds: 12);
bool _crashlyticsReady = false;
final _pushNotificationService = PushNotificationService();

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _reportUncaughtError(details.exception, details.stack);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        _reportUncaughtError(error, stack);
        return true;
      };

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(_firebaseStartupTimeout);
      } catch (error, stack) {
        _reportUncaughtError(error, stack);
        runApp(const _StartupFailureApp());
        return;
      }

      if (_enableAppCheck) {
        await _runStartupTask(
          'Firebase App Check',
          _activateAppCheck,
          timeout: const Duration(seconds: 8),
        );
      }

      runApp(
        const ProviderScope(
          child: BhriguApp(),
        ),
      );

      unawaited(_startDeferredStartupServices());
    },
    _reportUncaughtError,
  );
}

Future<void> _startDeferredStartupServices() async {
  await Future<void>.delayed(Duration.zero);

  final tasks = <Future<void>>[
    _runStartupTask(
      'Crashlytics',
      _configureCrashlytics,
      timeout: const Duration(seconds: 4),
    ),
    _runStartupTask(
      'RevenueCat',
      RevenueCatService.instance.configure,
      timeout: const Duration(seconds: 8),
    ),
    _runStartupTask(
      'Push notifications',
      _pushNotificationService.initialize,
      timeout: const Duration(seconds: 8),
    ),
  ];

  await Future.wait<void>(tasks);
}

Future<void> _runStartupTask(
  String label,
  Future<void> Function() task, {
  required Duration timeout,
}) async {
  try {
    await task().timeout(timeout);
  } catch (error, stack) {
    _reportStartupWarning(
      '$label startup failed or timed out after ${timeout.inSeconds}s',
      error,
      stack,
    );
  }
}

void _reportStartupWarning(String label, Object error, StackTrace stack) {
  if (kDebugMode) {
    debugPrint('$label: $error');
    debugPrintStack(stackTrace: stack);
  }

  if (_crashlyticsReady && !kDebugMode) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: label,
        fatal: false,
      ),
    );
  }
}

void _reportUncaughtError(Object error, StackTrace? stack) {
  if (kDebugMode) {
    debugPrint('Uncaught app error: $error');
    if (stack != null) {
      debugPrintStack(stackTrace: stack);
    }
  }

  if (_crashlyticsReady && !kDebugMode) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
    );
  }
}

Future<void> _configureCrashlytics() async {
  if (kIsWeb || !_enableCrashlytics) {
    return;
  }

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );
  _crashlyticsReady = true;
}

Future<void> _activateAppCheck() async {
  if (kIsWeb || !_enableAppCheck) {
    if (kDebugMode && !_enableAppCheck) {
      debugPrint(
        'Firebase App Check activation skipped. '
        'Use --dart-define=ENABLE_APP_CHECK=true when testing App Check.',
      );
    }
    return;
  }

  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
        );
        return;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
        return;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return;
    }
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('Firebase App Check activation failed: $e');
      debugPrintStack(stackTrace: stack);
    }
  }
}

class BhriguApp extends StatelessWidget {
  const BhriguApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BHR1GU',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B21A8),
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme(),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0D0B1E),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B21A8),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF9D6FE8),
        secondary: const Color(0xFFF59E0B),
        onSurface: const Color(0xFFF0ECF8),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1630),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFF2E2650),
            width: 1,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0B1E),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFFF0ECF8),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFFF0ECF8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1630),
        selectedItemColor: Color(0xFF9D6FE8),
        unselectedItemColor: Color(0xFF6B6080),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF050408),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFC7A867),
                    size: 34,
                  ),
                  SizedBox(height: 18),
                  Text(
                    'BHR1GU could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE5D5F5),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Check your connection and open the app again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8E83A8),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

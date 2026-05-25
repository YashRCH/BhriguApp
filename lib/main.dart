import 'dart:async';
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'router.dart';

const _enableAppCheck = bool.fromEnvironment('ENABLE_APP_CHECK');

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

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _activateAppCheck();

      runApp(
        const ProviderScope(
          child: BhriguApp(),
        ),
      );
    },
    _reportUncaughtError,
  );
}

void _reportUncaughtError(Object error, StackTrace? stack) {
  if (kDebugMode) {
    debugPrint('Uncaught app error: $error');
    if (stack != null) {
      debugPrintStack(stackTrace: stack);
    }
  }
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
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
        );
        return;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        await FirebaseAppCheck.instance.activate(
          appleProvider: kDebugMode
              ? AppleProvider.debug
              : AppleProvider.appAttestWithDeviceCheckFallback,
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

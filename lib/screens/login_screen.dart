import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (_loading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final validationError = _validateEmailPassword(email, password);

    if (validationError != null) {
      setState(() {
        _error = validationError;
        _info = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      if (_isLogin) {
        await _auth.signInWithEmail(
          email,
          password,
        );
      } else {
        await _auth.signUpWithEmail(
          email,
          password,
        );

        // TODO: Uncomment this when re-enabling email verification for full release
        /*
        await _auth.signOut();

        if (!mounted) return;

        setState(() {
          _isLogin = true;
          _passwordController.clear();
          _info =
              'Verification email sent. Please verify your email, then sign in.';
        });
        return;
        */
      }
      if (mounted) {
        final completed = await _auth.hasCompletedOnboarding();
        if (mounted) context.go(_postAuthLocation(completed));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final cred = await _auth.signInWithGoogle();
      if (cred == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      if (mounted) {
        final completed = await _auth.hasCompletedOnboarding();
        if (mounted) context.go(_postAuthLocation(completed));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    return _friendlyError(e.code);
  }

  String _postAuthLocation(bool completed) {
    final from = _safeRedirectLocation(
      GoRouterState.of(context).uri.queryParameters['from'],
    );

    if (completed) return from ?? '/home';
    if (from == null) return '/onboarding';

    return '/onboarding?from=${Uri.encodeComponent(from)}';
  }

  String? _safeRedirectLocation(String? value) {
    final location = value?.trim();
    if (location == null || location.isEmpty) return null;
    if (!location.startsWith('/') || location.startsWith('//')) return null;
    if (location.startsWith('/login') || location.startsWith('/onboarding')) {
      return null;
    }

    return location;
  }

  String _friendlyError(String e) {
    if (e.contains('email-not-verified')) {
      return 'Please verify your email, then sign in.';
    }
    if (e.contains('user-not-found') ||
        e.contains('wrong-password') ||
        e.contains('invalid-credential') ||
        e.contains('invalid-login-credentials')) {
      return 'Could not sign in with those credentials.';
    }
    if (e.contains('email-already-in-use')) {
      return 'Could not create account. Try signing in or use another email.';
    }
    if (e.contains('weak-password')) {
      return 'Choose a stronger password.';
    }
    if (e.contains('invalid-email')) return 'Please enter a valid email.';
    return 'Something went wrong. Please try again.';
  }

  String? _validateEmailPassword(String email, String password) {
    if (!_isValidEmail(email)) return 'Please enter a valid email.';

    if (_isLogin) {
      if (password.isEmpty) return 'Please enter your password.';
      return null;
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Use at least one letter and one number in your password.';
    }

    return null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _sendPasswordReset() async {
    if (_loading) return;

    final email = _emailController.text.trim();

    if (!_isValidEmail(email)) {
      setState(() {
        _error = 'Please enter your email address first.';
        _info = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      await _auth.sendPasswordResetEmail(email);

      if (!mounted) return;

      setState(() {
        _info =
            'If an account exists for this email, a reset link has been sent.';
      });
    } on FirebaseAuthException catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
          'Password reset email request failed: ${e.code} ${e.message}',
        );
        debugPrintStack(stackTrace: stack);
      }

      if (!mounted) return;

      setState(() {
        _info =
            'If an account exists for this email, a reset link has been sent.';
        _error = kDebugMode ? 'Debug reset error: ${e.code}' : null;
      });
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Password reset email request failed: $e');
        debugPrintStack(stackTrace: stack);
      }

      if (!mounted) return;

      setState(() {
        _info =
            'If an account exists for this email, a reset link has been sent.';
        _error = kDebugMode ? 'Debug reset error: ${e.runtimeType}' : null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.5,
            colors: [
              Color(0xFF1E1430), // Muted plum center
              Color(0xFF0F0A18), // Dark shadow
              Color(0xFF050408), // Pitch black
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'BHR1GU',
                    style: GoogleFonts.cinzel(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: const Color(0xFFE5D5F5), // Moonlight
                      shadows: [
                        Shadow(
                          color: const Color(0xFFE5D5F5).withValues(alpha: 0.5),
                          blurRadius: 10,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isLogin ? 'WELCOME BACK' : 'CREATE ACCOUNT',
                      key: ValueKey<bool>(_isLogin),
                      style: GoogleFonts.cinzel(
                        fontSize: 14,
                        color: const Color(0xFFB58E34), // Antique Gold
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 64),

                  // Email Field
                  _glassInput(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 22, color: const Color(0xFFE5D5F5)),
                      cursorColor: const Color(0xFFB58E34),
                      decoration: _inputDecoration('Email Address'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  _glassInput(
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 22, color: const Color(0xFFE5D5F5)),
                      cursorColor: const Color(0xFFB58E34),
                      decoration: _inputDecoration('Password').copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFFB58E34),
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _submitEmail(),
                    ),
                  ),

                  // Error Message
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE53E3E).withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _info!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7DD3FC),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Main Action Button (Email)
                  GestureDetector(
                    onTap: _loading ? null : _submitEmail,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF1E1430),
                        border: Border.all(
                          color: const Color(0xFFB58E34).withValues(alpha: 0.6),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFB58E34).withValues(alpha: 0.2),
                            blurRadius: 15,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFFB58E34),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                                style: GoogleFonts.cinzel(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB58E34),
                                  letterSpacing: 3.0,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (_isLogin) ...[
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _loading ? null : _sendPasswordReset,
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFB58E34),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: const Color(0xFF3A2D50)
                                  .withValues(alpha: 0.5))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: GoogleFonts.cinzel(
                            color: const Color(0xFF6B6080),
                            fontSize: 12,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: const Color(0xFF3A2D50)
                                  .withValues(alpha: 0.5))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Google Sign In Button
                  GestureDetector(
                    onTap: _loading ? null : _submitGoogle,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.transparent,
                        border: Border.all(
                          color: const Color(0xFF3A2D50),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'G',
                            style: GoogleFonts.cinzel(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFE5D5F5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'CONTINUE WITH GOOGLE',
                            style: GoogleFonts.cinzel(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE5D5F5),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Toggle login/signup
                  GestureDetector(
                    onTap: () => setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                      _info = null;
                    }),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _isLogin
                                ? "Don't have an account?  "
                                : 'Already have an account?  ',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B6080),
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: _isLogin ? 'Sign up' : 'Sign in',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFB58E34),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
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

  Widget _glassInput({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0812).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3A2D50)),
          ),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.cormorantGaramond(
        color: Colors.white30,
        fontStyle: FontStyle.italic,
        fontSize: 20,
      ),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.all(20),
    );
  }
}

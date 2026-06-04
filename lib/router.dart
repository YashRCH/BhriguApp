import 'dart:async';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/tarot_screen.dart';
import 'screens/geomancy_screen.dart';
import 'screens/partner_match_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

final _routerAuth = AuthService();

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(_routerAuth.authStateChanges),
  redirect: (context, state) async {
    final user = _routerAuth.currentUser;
    final path = state.uri.path;

    // If not logged in, force them to login
    if (user == null) {
      return path == '/login' ? null : '/login';
    }

    // Prevent navigation away from login if the user is signing up/in with email but hasn't verified.
    // This stops the app from bouncing to /onboarding and back to /login, which destroys the error state.
    // TODO: Uncomment when re-enabling email verification
    /*
    final isPasswordProvider = user.providerData.any((p) => p.providerId == 'password');
    if (isPasswordProvider && !user.emailVerified) {
      return path == '/login' ? null : '/login';
    }
    */

    bool completed = false;
    try {
      completed = await _routerAuth.hasCompletedOnboarding();
    } catch (e) {
      debugPrint('Router error checking onboarding status: $e');
      if (path == '/login') return null;
      return '/login';
    }

    // If logged in but trying to access login, redirect based on onboarding
    if (path == '/login') {
      return completed ? '/home' : '/onboarding';
    }

    // If trying to access onboarding but already completed it, go home
    if (path == '/onboarding') {
      return completed ? '/home' : null;
    }

    // A signed-in user must finish onboarding before entering the main shell.
    if (!completed) {
      return '/onboarding';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (ctx, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (ctx, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (ctx, state, child) => MainShell(
        location: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/home',
          builder: (ctx, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/chat',
          builder: (ctx, state) {
            final extra = state.extra;
            final followUpContextId = extra is String ? extra : null;

            return ChatScreen(
              followUpContextId: followUpContextId,
            );
          },
        ),
        GoRoute(
          path: '/tarot',
          builder: (ctx, state) => const TarotScreen(),
        ),
        GoRoute(
          path: '/geomancy',
          builder: (ctx, state) => const GeomancyScreen(),
        ),
        GoRoute(
          path: '/bhrigu-match',
          builder: (ctx, state) => const PartnerMatchScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (ctx, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;
  Timer? _timer;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 250), () {
        notifyListeners();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription.cancel();
    super.dispose();
  }
}

class MainShell extends StatefulWidget {
  final Widget child;
  final String location;

  const MainShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    // A slow, continuous 2.5-second breathing cycle for the active tab
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int _locationToIndex() {
    if (widget.location.startsWith('/chat')) return 1;
    if (widget.location.startsWith('/tarot')) return 2;
    if (widget.location.startsWith('/geomancy')) return 3;
    if (widget.location.startsWith('/bhrigu-match')) return 4;
    return 0; // Default to Home
  }

  void _onTap(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/chat');
        break;
      case 2:
        context.go('/tarot');
        break;
      case 3:
        context.go('/geomancy');
        break;
      case 4:
        context.go('/bhrigu-match');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _locationToIndex();

    return Scaffold(
      backgroundColor: const Color(0xFF050408), // Pitch black base
      // Extend body so the content flows beautifully under the transparent glass nav bar
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _buildCustomNavBar(currentIndex),
    );
  }

  Widget _buildCustomNavBar(int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        // High transparency base for a beautiful, sheer glass effect
        color: const Color(0xFF0A0812).withValues(alpha: 0.35),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFC7A867)
                .withValues(alpha: 0.1), // Faint antique gold rim lighting
            width: 1.0,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          // Intense blur makes the background content smooth and frosted
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: SafeArea(
            child: Padding(
              // Reduced padding to make the bar shorter
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 4,
                left: 8,
                right: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    0,
                    'HOME',
                    (c) => Icon(
                      Icons.home_rounded,
                      color: c,
                      size: 24,
                    ),
                    currentIndex,
                  ),
                  _buildNavItem(
                    1,
                    'BHRIGU',
                    (c) => Icon(
                      Icons.history_edu_rounded,
                      color: c,
                      size: 24,
                    ),
                    currentIndex,
                  ),
                  _buildNavItem(
                    2,
                    'TAROT',
                    (c) => Icon(
                      Icons.style_rounded,
                      color: c,
                      size: 24,
                    ),
                    currentIndex,
                  ),
                  _buildNavItem(
                    3,
                    'GEO',
                    _buildPentacle,
                    currentIndex,
                  ),
                  _buildNavItem(
                    4,
                    'MATCH',
                    (c) => Icon(
                      Icons.favorite_rounded,
                      color: c,
                      size: 24,
                    ),
                    currentIndex,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Creates a clean, esoteric Pentacle (5-pointed star inside a circle)
  Widget _buildPentacle(Color c) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.circle_outlined, color: c, size: 24),
          Icon(Icons.star_border_rounded, color: c, size: 16),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String label,
    Widget Function(Color) iconBuilder,
    int currentIndex,
  ) {
    final isActive = index == currentIndex;

    // Softer Antique Gold for active, muted violet-grey for inactive
    final color = isActive ? const Color(0xFFC7A867) : const Color(0xFF6B6080);

    return GestureDetector(
      onTap: () => _onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 65,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top active indicator dash
            AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 14,
                height: 3,
                margin: const EdgeInsets.only(bottom: 4), // Reduced spacing
                decoration: BoxDecoration(
                  color: const Color(0xFFC7A867),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC7A867).withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),

            // The Icon (Animated if active, static if not)
            SizedBox(
              height: 28, // Reduced height to keep layout shorter
              child: isActive
                  ? AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        // Smooth, gentle floating effect using sine wave
                        final curve = Curves.easeInOutSine.transform(
                          _animController.value,
                        );
                        return Transform.translate(
                          offset: Offset(
                            0,
                            -2.0 * curve,
                          ), // Floats up gently (less travel for shorter bar)
                          child: Transform.scale(
                            scale:
                                1.0 + (0.05 * curve), // Scales up very slightly
                            child: iconBuilder(color),
                          ),
                        );
                      },
                    )
                  : iconBuilder(color),
            ),

            const SizedBox(height: 2), // Reduced spacing

            // The Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: GoogleFonts.cinzel(
                fontSize: isActive ? 10 : 9,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: color,
                letterSpacing: 1.0,
              ),
              child: Text(label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

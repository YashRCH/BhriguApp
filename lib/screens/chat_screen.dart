import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/chat_hints.dart';
import '../models/chat_message.dart';
import '../models/follow_up_context_model.dart';
import '../services/groq_service.dart';
import '../services/follow_up_context_service.dart';
import '../services/user_profile_cache_service.dart';
import '../providers/chat_provider.dart';
import '../widgets/ai_report_button.dart';
import 'cosmic_blueprint_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? followUpContextId;

  const ChatScreen({
    super.key,
    this.followUpContextId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _groq = GroqService();
  final _followUpService = FollowUpContextService();

  FollowUpContext? _activeFollowUpContext;
  bool _loadingFollowUpContext = false;

  bool _isTyping = false;
  bool _stickToBottom = true;

  Timer? _hintTimer;
  int _hintIndex = 0;

  static const String _ephemerisTrustLine =
      'Planetary positions calculated using NASA/JPL Horizons ephemeris data.';
  static const int _apiHistoryLimit = 5;

  late final AnimationController _pulseController;
  late final AnimationController _dotController;
  late final AnimationController _rotationController;
  late final AnimationController _plasmaController;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_handleScroll);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _plasmaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _loadFollowUpContextIfNeeded();
    _syncChatLanguage();

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (_controller.text.trim().isNotEmpty) return;

      setState(() {
        _hintIndex = (_hintIndex + 1) % chatHints.length;
      });
    });
  }

  Future<void> _syncChatLanguage() async {
    await ref.read(chatProvider.notifier).ensureActiveLanguage();

    if (!mounted) return;
    _scrollToBottom(force: true);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _pulseController.dispose();
    _dotController.dispose();
    _rotationController.dispose();
    _plasmaController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;

    _stickToBottom = distanceFromBottom <= 90;
  }

  Future<void> _loadFollowUpContextIfNeeded() async {
    final contextId = widget.followUpContextId;

    if (contextId == null || contextId.trim().isEmpty) return;

    setState(() {
      _loadingFollowUpContext = true;
    });

    try {
      final currentLanguage =
          await UserProfileCacheService.instance.aiResponseLanguage();
      final followUpContext = await _followUpService.getFollowUpContext(
        contextId.trim(),
      );

      if (!mounted) return;

      if (followUpContext != null &&
          followUpContext.aiResponseLanguage != currentLanguage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This reading was created in another response language. Switch back to continue it, or create a new reading.',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF1A1630),
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() {
          _loadingFollowUpContext = false;
        });
        return;
      }

      setState(() {
        _activeFollowUpContext = followUpContext;
        _loadingFollowUpContext = false;

        if (followUpContext != null &&
            _controller.text.trim().isEmpty &&
            followUpContext.selectedFollowUpQuestion.trim().isNotEmpty) {
          _controller.text = followUpContext.selectedFollowUpQuestion.trim();
        }
      });

      _scrollToBottom(force: true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingFollowUpContext = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isTyping) return;

    _stickToBottom = true;
    final language =
        await ref.read(chatProvider.notifier).ensureActiveLanguage();
    if (!mounted) return;

    if (_activeFollowUpContext != null &&
        _activeFollowUpContext!.aiResponseLanguage != language) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This reading was created in another response language. Switch back to continue it, or create a new reading.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFF1A1630),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _activeFollowUpContext = null;
      });
      return;
    }

    ref.read(chatProvider.notifier).addMessage(
          ChatMessage(
            role: 'user',
            content: text,
            aiResponseLanguage: language,
          ),
        );

    setState(() {
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom(force: true);

    ref.read(chatProvider.notifier).addMessage(
          ChatMessage(
            role: 'assistant',
            content: '',
            aiResponseLanguage: language,
          ),
        );

    _scrollToBottom(force: true);

    final history = ref.read(chatProvider).sublist(
          0,
          ref.read(chatProvider).length - 1,
        );

    final limitedHistory = history.length > _apiHistoryLimit
        ? history.sublist(history.length - _apiHistoryLimit)
        : history;

    _groq
        .streamMessage(
      limitedHistory,
      followUpContext: _activeFollowUpContext,
    )
        .listen(
      (streamed) {
        if (!mounted) return;

        ref.read(chatProvider.notifier).updateLast(streamed);
        _scrollToBottom();
      },
      onDone: () async {
        if (!mounted) return;

        final lastContent = ref.read(chatProvider).last.content;

        await ref.read(chatProvider.notifier).finalizeLastMessage(
              lastContent,
            );

        setState(() {
          _isTyping = false;
        });

        _scrollToBottom();
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _isTyping = false;
        });

        _scrollToBottom();
      },
    );
  }

  void _openCosmicBlueprint() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CosmicBlueprintScreen(),
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1630),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Clear conversation?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xFF6B6080),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);

              await ref.read(chatProvider.notifier).clear();

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Conversation cleared',
                    style: GoogleFonts.inter(),
                  ),
                  backgroundColor: const Color(0xFF6B21A8),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: Text(
              'Clear',
              style: GoogleFonts.inter(
                color: const Color(0xFF9D6FE8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!force && !_stickToBottom) return;

      final maxScrollExtent = _scrollController.position.maxScrollExtent;

      _scrollController.jumpTo(maxScrollExtent);
    });
  }

  Widget _animatedTeslaGlobe({double size = 32}) {
    return AnimatedBuilder(
      animation: _plasmaController,
      builder: (context, child) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _TeslaGlobePainter(_plasmaController.value),
        ),
      ),
    );
  }

  Widget _cosmicBlueprintIcon({double size = 30}) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _rotationController,
      ]),
      builder: (context, child) {
        final pulse = 0.88 + (_pulseController.value * 0.12);

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _rotationController.value * math.pi * 2,
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: _CosmicBlueprintIconPainter(),
                  ),
                ),
                Text(
                  '✦',
                  style: TextStyle(
                    color: const Color(0xFFFFD88A),
                    fontSize: size * 0.48,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(
                        color: Color(0xFFF59E0B),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF080512),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _inputBar(),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.8),
            radius: 1.5,
            colors: [
              Color(0xFF2A1B4D),
              Color(0xFF0D0B1E),
              Color(0xFF080512),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: Stack(
                  children: [
                    if (messages.isEmpty)
                      Positioned.fill(
                        child: _emptyState(),
                      ),
                    Column(
                      children: [
                        if (_loadingFollowUpContext) _followUpLoadingChip(),
                        if (!_loadingFollowUpContext &&
                            _activeFollowUpContext != null)
                          _followUpContextChip(),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: 26,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: false,
                            itemCount: messages.length,
                            itemBuilder: (_, i) {
                              final msg = messages[i];

                              if (msg.role == 'assistant' &&
                                  msg.content.isEmpty &&
                                  _isTyping) {
                                return _typingIndicator();
                              }

                              if (msg.content.isEmpty) {
                                return const SizedBox();
                              }

                              final isStreaming = _isTyping &&
                                  i == messages.length - 1 &&
                                  msg.role == 'assistant';

                              if (isStreaming) {
                                return _buildStreamingMessage(msg);
                              }

                              return _buildMessage(msg);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0B1E).withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'BHRIGU',
                      style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _ephemerisTrustLine,
                          maxLines: 1,
                          style: GoogleFonts.inter(
                            color:
                                const Color(0xFFB58E34).withValues(alpha: 0.52),
                            fontSize: 8.8,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _openCosmicBlueprint,
                    child: Container(
                      width: 42,
                      height: 42,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1630).withValues(alpha: 0.72),
                        border: Border.all(
                          color: const Color(0xFFB58E34).withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFB58E34).withValues(alpha: 0.16),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _cosmicBlueprintIcon(size: 27),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.auto_delete_outlined,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    onPressed: _clearChat,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 280;

          return Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                vertical: compact ? 8 : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _animatedTeslaGlobe(size: compact ? 102 : 130),
                  SizedBox(height: compact ? 22 : 38),
                  Text(
                    'Ask Bhrigu anything',
                    style: GoogleFonts.cormorantGaramond(
                      color: Colors.white,
                      fontSize: compact ? 25 : 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your cosmic blueprint guides every answer',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9D6FE8),
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreamingMessage(ChatMessage msg) {
    return RepaintBoundary(
      key: const ValueKey('streaming'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                right: 12,
                top: 4,
              ),
              child: _animatedTeslaGlobe(size: 30),
            ),
            Flexible(
              child: _glassBubble(
                child: Text(
                  msg.content,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.6,
                    color: const Color(0xFFF0ECF8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    final isUser = msg.role == 'user';

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(
                  right: 12,
                  top: 4,
                ),
                child: _animatedTeslaGlobe(size: 30),
              ),
            Flexible(
              child: GestureDetector(
                onLongPress: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: msg.content,
                    ),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Copied to clipboard',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: const Color(0xFF6B21A8),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                child: isUser
                    ? _userBubble(msg.content)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _glassBubble(
                            child: Text(
                              msg.content,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                height: 1.6,
                                color: const Color(0xFFF0ECF8),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: AiReportButton(
                              feature: 'chat',
                              contentId:
                                  'chat_${msg.timestamp.toIso8601String()}',
                              contentText: msg.content,
                              label: 'Report',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userBubble(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8B5CF6),
            Color(0xFF5B21B6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 15,
          height: 1.5,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _glassBubble({
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomRight: Radius.circular(20),
        bottomLeft: Radius.circular(6),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              right: 12,
              top: 4,
            ),
            child: _animatedTeslaGlobe(size: 30),
          ),
          _glassBubble(
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = ((_dotController.value - i * 0.2) % 1.0);
                    final opacity = t < 0.5 ? t * 2 : (1 - t) * 2;

                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF9D6FE8).withValues(
                          alpha: 0.3 + 0.7 * opacity.clamp(0.0, 1.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9D6FE8).withValues(
                              alpha: opacity,
                            ),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _followUpLoadingChip() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1630).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF9D6FE8).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFF9D6FE8).withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Preparing follow-up context...',
            style: GoogleFonts.inter(
              color: const Color(0xFFB8AEE0),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _followUpContextChip() {
    final followUpContext = _activeFollowUpContext;

    if (followUpContext == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1630).withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFB58E34).withValues(alpha: 0.36),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB58E34).withValues(alpha: 0.08),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D0B1E).withValues(alpha: 0.7),
              border: Border.all(
                color: const Color(0xFFB58E34).withValues(alpha: 0.38),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFB58E34),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Following up on ${followUpContext.readingTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFD88A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  followUpContext.selectedFollowUpQuestion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFB8AEE0),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1630).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: chatHints[_hintIndex],
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF6B6080),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.transparent,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: const Color(0xFFE040FB),
                    size: 26,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFE040FB).withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CosmicBlueprintIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final orbitPaint = Paint()
      ..color = const Color(0xFF9D6FE8).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    final goldOrbitPaint = Paint()
      ..color = const Color(0xFFB58E34).withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;

    canvas.drawCircle(center, radius * 0.42, orbitPaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.scale(1.0, 0.48);
    canvas.drawCircle(Offset.zero, radius * 0.72, goldOrbitPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 5);
    canvas.scale(1.0, 0.44);
    canvas.drawCircle(Offset.zero, radius * 0.72, orbitPaint);
    canvas.restore();

    canvas.drawCircle(
      Offset(center.dx + radius * 0.58, center.dy),
      radius * 0.08,
      Paint()
        ..color = const Color(0xFFFFD88A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawCircle(
      Offset(center.dx - radius * 0.46, center.dy + radius * 0.26),
      radius * 0.055,
      Paint()
        ..color = const Color(0xFFE040FB)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TeslaGlobePainter extends CustomPainter {
  final double progress;

  _TeslaGlobePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final glassPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF9D6FE8).withValues(alpha: 0.15),
        ],
        stops: const [0.6, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, glassPaint);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFB58E34).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(
      center,
      radius * 0.25,
      Paint()
        ..color = const Color(0xFFB58E34).withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()..color = const Color(0xFFC7A867),
    );

    canvas.drawCircle(
      center,
      radius * 0.06,
      Paint()..color = Colors.white,
    );

    final math.Random fixedRandom = math.Random(42);
    const int numTendrils = 7;

    for (int i = 0; i < numTendrils; i++) {
      final double baseAngle = i * 2 * math.pi / numTendrils;

      final double dynamicAngle =
          baseAngle + math.sin(progress * 2 * math.pi + i) * 0.5;

      final Offset endPoint = Offset(
        center.dx + math.cos(dynamicAngle) * radius * 0.95,
        center.dy + math.sin(dynamicAngle) * radius * 0.95,
      );

      final double wave1 = math.cos(progress * 4 * math.pi + i * 2);
      final double wave2 = math.sin(progress * 6 * math.pi + i * 3);

      final Offset cp1 = Offset(
        center.dx + math.cos(dynamicAngle + wave1 * 0.8) * radius * 0.4,
        center.dy + math.sin(dynamicAngle + wave1 * 0.8) * radius * 0.4,
      );

      final Offset cp2 = Offset(
        center.dx + math.cos(dynamicAngle - wave2 * 0.6) * radius * 0.7,
        center.dy + math.sin(dynamicAngle - wave2 * 0.6) * radius * 0.7,
      );

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(
          cp1.dx,
          cp1.dy,
          cp2.dx,
          cp2.dy,
          endPoint.dx,
          endPoint.dy,
        );

      final double flicker = 0.5 +
          fixedRandom.nextDouble() * 0.5 +
          math.sin(progress * 20 * math.pi + i) * 0.2;

      final double safeFlicker = flicker.clamp(0.2, 1.0);

      final Color tendrilColor =
          i % 2 == 0 ? const Color(0xFFE040FB) : const Color(0xFF00E5FF);

      canvas.drawPath(
        path,
        Paint()
          ..color = tendrilColor.withValues(alpha: 0.6 * safeFlicker)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE5D5F5).withValues(
            alpha: 0.9 * safeFlicker,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      canvas.drawCircle(
        endPoint,
        3.0 * safeFlicker,
        Paint()
          ..color = const Color(0xFFE5D5F5).withValues(alpha: safeFlicker)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TeslaGlobePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

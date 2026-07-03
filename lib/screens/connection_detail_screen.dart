import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/partner_match_model.dart';
import '../models/social_connection_model.dart';
import '../services/connection_compatibility_service.dart';
import '../services/connection_daily_energy_service.dart';
import '../services/connection_service.dart';
import '../services/follow_up_context_service.dart';
import '../services/ai_report_service.dart';
import '../widgets/ai_report_dialog.dart';
import '../widgets/compatibility_metric_card.dart';
import '../widgets/compatibility_score_ring.dart';
import '../widgets/cosmic_screen_background.dart';
import '../widgets/heart_signal_card.dart';
import '../widgets/ai_disclaimer.dart';
import '../widgets/revealing_text.dart';

class ConnectionDetailScreen extends StatefulWidget {
  final String connectionId;

  const ConnectionDetailScreen({
    super.key,
    required this.connectionId,
  });

  @override
  State<ConnectionDetailScreen> createState() => _ConnectionDetailScreenState();
}

class _ConnectionDetailScreenState extends State<ConnectionDetailScreen>
    with SingleTickerProviderStateMixin {
  final _connectionService = ConnectionService();
  final _compatibilityService = ConnectionCompatibilityService();
  final _dailyEnergyService = ConnectionDailyEnergyService();
  final _followUpService = FollowUpContextService();

  late final TabController _tabController;
  late Future<SocialConnection?> _connectionFuture;
  bool _generatingCompatibility = false;
  bool _generatingEnergy = false;
  bool _creatingFollowUp = false;
  bool _switchingType = false;

  // Set when the user taps a Generate button, so only a freshly produced
  // reading types in word-by-word. Existing readings shown on open or tab
  // switch render instantly. Reset after the first animated build consumes it.
  bool _revealEnergyPending = false;
  bool _revealCompatibilityPending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _connectionFuture = _connectionService.getConnection(widget.connectionId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Re-fetch the connection. Called from the retry button and after mutations.
  void _refreshConnection() {
    setState(() {
      _connectionFuture = _connectionService.getConnection(widget.connectionId);
    });
  }

  /// Clears a reveal flag after the freshly generated reading has mounted, so a
  /// later rebuild or tab switch shows it instantly instead of re-typing.
  void _consumeRevealFlag({required bool energy}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final stillPending =
          energy ? _revealEnergyPending : _revealCompatibilityPending;
      if (!stillPending) return;

      setState(() {
        if (energy) {
          _revealEnergyPending = false;
        } else {
          _revealCompatibilityPending = false;
        }
      });
    });
  }

  Future<void> _generateCompatibility(SocialConnection connection) async {
    if (_generatingCompatibility) return;

    String? heartSignal;
    if (connection.relationshipType == SocialRelationshipType.partner) {
      heartSignal = await showDialog<String>(
        context: context,
        builder: (ctx) => _HeartSignalDialog(
          displayName: _safeDisplayName(connection),
        ),
      );

      if (heartSignal == null) return;
    }

    setState(() => _generatingCompatibility = true);

    try {
      await _compatibilityService.generateCompatibility(
        connectionId: widget.connectionId,
        heartSignal: heartSignal,
      );
      _revealCompatibilityPending = true;
    } catch (e, stack) {
      _logError('Generate connection compatibility failed', e, stack);
      _showError('Could not generate compatibility right now.');
    } finally {
      if (mounted) {
        setState(() => _generatingCompatibility = false);
      }
    }
  }

  Future<void> _generateEnergy() async {
    if (_generatingEnergy) return;

    setState(() => _generatingEnergy = true);

    try {
      await _dailyEnergyService.generateToday(widget.connectionId);
      _revealEnergyPending = true;
    } catch (e, stack) {
      _logError('Generate connection daily energy failed', e, stack);
      _showError('Could not generate daily energy right now.');
    } finally {
      if (mounted) {
        setState(() => _generatingEnergy = false);
      }
    }
  }

  Future<void> _openFollowUp({
    required SocialConnection connection,
    ConnectionCompatibilityReading? reading,
    ConnectionDailyEnergy? energy,
    required String question,
  }) async {
    if (_creatingFollowUp) return;

    setState(() => _creatingFollowUp = true);

    try {
      final isFriend =
          connection.relationshipType == SocialRelationshipType.friend;
      // BUG-B FIXED: Removed unreachable 'spouse_compatibility' branch.
      // SocialRelationshipType has no spouse value; spouse was mapped to partner
      // in fromValue(). SourceType is now a clean two-way ternary.
      final sourceType = reading != null
          ? isFriend
              ? 'friend_compatibility'
              : 'partner_compatibility'
          : 'connection_daily_energy';
      final title = reading != null
          ? '${connection.otherProfile.displayName} Compatibility'
          : '${connection.otherProfile.displayName} Daily Energy';
      final summary = reading?.summary ??
          energy?.members[connection.otherUid]?.heading ??
          'Daily connection energy for ${connection.otherProfile.displayName}.';

      final contextId = await _followUpService.createConnectionFollowUpContext(
        sourceType: sourceType,
        originalQuestion: title,
        selectedFollowUpQuestion: question,
        readingTitle: title,
        readingSummary: summary,
        sourceData: {
          'connectionId': connection.connectionId,
          'otherUid': connection.otherUid,
          'relationshipType': connection.relationshipType.value,
          'otherProfile': {
            'displayName': connection.otherProfile.displayName,
            'username': connection.otherProfile.username,
            'chartSummary': connection.otherProfile.chartSummary,
          },
          if (reading != null)
            'compatibility': {
              'scores': reading.scores,
              'summary': reading.summary,
              'strengths': reading.strengths,
              'tensions': reading.tensions,
              'advice': reading.advice,
              'dailyBondSignal': reading.dailyBondSignal,
              if (reading.partnerMatchReading != null)
                'partnerMatchReading': reading.partnerMatchReading!.toJson(),
            },
          if (energy != null)
            'dailyEnergy': {
              'dateKey': energy.dateKey,
              'bondSignal': energy.bondSignal,
              'members': energy.members.map(
                (key, value) => MapEntry(
                  key,
                  {
                    'energy': value.energy,
                    'heading': value.heading,
                    'doText': value.doText,
                    'avoidText': value.avoidText,
                    'bestApproach': value.bestApproach,
                  },
                ),
              ),
            },
        },
        aiResponseLanguage: reading?.aiResponseLanguage,
      );

      if (!mounted) return;
      context.push('/chat', extra: contextId);
    } catch (e, stack) {
      _logError('Create connection follow-up failed', e, stack);
      _showError('Could not open private guidance right now.');
    } finally {
      if (mounted) {
        setState(() => _creatingFollowUp = false);
      }
    }
  }

  /// Switch the relationship type for this connection. Wipes readings.
  Future<void> _switchRelationshipType(SocialConnection connection) async {
    final current = connection.relationshipType;

    final newType = await showDialog<SocialRelationshipType>(
      context: context,
      builder: (ctx) => _SwitchTypeDialog(current: current),
    );

    if (newType == null || newType == current) return;
    if (_switchingType) return;

    setState(() => _switchingType = true);

    try {
      await _connectionService.switchRelationshipType(
        connectionId: widget.connectionId,
        relationshipType: newType,
      );
      if (!mounted) return;
      _refreshConnection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Relationship updated to ${newType.label}. Compatibility reset.',
          ),
        ),
      );
    } catch (e, stack) {
      _logError('Switch relationship type failed', e, stack);
      _showError('Could not switch relationship type right now.');
    } finally {
      if (mounted) {
        setState(() => _switchingType = false);
      }
    }
  }

  Future<void> _removeConnection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15110A),
        title: const Text(
          'Remove from Circle?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This connection will be archived. You can reconnect later.',
          style: TextStyle(color: Color(0xFFB8AEE0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _connectionService.removeConnection(widget.connectionId);
      if (!mounted) return;
      context.go('/bhrigu-match');
    } catch (e, stack) {
      _logError('Remove connection failed', e, stack);
      _showError('Could not remove connection right now.');
    }
  }

  Future<void> _blockConnection(SocialConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15110A),
        title: const Text(
          'Block this person?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${connection.otherProfile.displayName} will not be able to send you requests.',
          style: const TextStyle(color: Color(0xFFB8AEE0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Block',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _connectionService.blockConnection(connection.otherUid);
      if (!mounted) return;
      context.go('/bhrigu-match');
    } catch (e, stack) {
      _logError('Block connection failed', e, stack);
      _showError('Could not block right now.');
    }
  }

  Future<void> _reportConnection(SocialConnection connection) async {
    final reportText = [
      'Circle connection report',
      'Display name: ${connection.otherProfile.displayName}',
      'Username: @${connection.otherProfile.username}',
      'Chart summary: ${connection.otherProfile.chartSummary}',
      'Relationship: ${connection.relationshipType.label}',
      'Connection ID: ${connection.connectionId}',
      'Other UID: ${connection.otherUid}',
    ].join('\n');

    final submitted = await showAiReportDialog(
      context: context,
      feature: 'circle',
      contentId: AiReportService.stableContentId(
        feature: 'circle',
        contentText: reportText,
      ),
      contentText: reportText,
    );

    if (!mounted || submitted != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report sent. Thank you.')),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _logError(String message, Object error, StackTrace stack) {
    if (error is FirebaseFunctionsException) {
      debugPrint(
        '$message: FirebaseFunctionsException('
        'code=${error.code}, message=${error.message}, '
        'details=${error.details})',
      );
    } else {
      debugPrint('$message: $error');
    }
    debugPrintStack(stackTrace: stack);
  }

  String _safeDisplayName(SocialConnection connection) {
    final displayName = connection.otherProfile.displayName.trim();
    return displayName.isEmpty ? 'this person' : displayName;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SocialConnection?>(
      future: _connectionFuture,
      builder: (context, snapshot) {
        final connection = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final topPadding = MediaQuery.of(context).padding.top +
            kToolbarHeight +
            (connection != null ? kTextTabBarHeight : 0);

        return Scaffold(
          backgroundColor: const Color(0xFF050408),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              connection?.otherProfile.displayName ?? 'Connection',
              style: GoogleFonts.cinzel(
                color: const Color(0xFFB58E34),
                fontSize: 18,
                letterSpacing: 2.2,
              ),
            ),
            actions: [
              if (connection != null && !isLoading)
                PopupMenuButton<_ConnectionAction>(
                  icon: const Icon(Icons.more_vert_rounded),
                  color: const Color(0xFF1C1510),
                  onSelected: (action) {
                    switch (action) {
                      case _ConnectionAction.switchType:
                        _switchRelationshipType(connection);
                      case _ConnectionAction.report:
                        _reportConnection(connection);
                      case _ConnectionAction.remove:
                        _removeConnection();
                      case _ConnectionAction.block:
                        _blockConnection(connection);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: _ConnectionAction.switchType,
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz_rounded,
                              color: Color(0xFFFFD88A), size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Switch relationship',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: _ConnectionAction.remove,
                      child: Row(
                        children: [
                          Icon(Icons.person_remove_rounded,
                              color: Color(0xFF9E7070), size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Remove from Circle',
                            style: TextStyle(color: Color(0xFF9E7070)),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: _ConnectionAction.report,
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined,
                              color: Color(0xFFFFD88A), size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Report',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: _ConnectionAction.block,
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded,
                              color: Color(0xFFFF6B6B), size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Block',
                            style: TextStyle(color: Color(0xFFFF6B6B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            bottom: connection != null
                ? TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Energy'),
                      Tab(text: 'Compatibility'),
                      Tab(text: 'Private Guidance'),
                      Tab(text: 'Rituals'),
                    ],
                  )
                : null,
          ),
          body: CosmicScreenBackground(
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFD88A),
                      ),
                    )
                  : connection == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: _connectionUnavailableCard(),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _energyTab(connection),
                            _compatibilityTab(connection),
                            _guidanceTab(connection),
                            _ritualsTab(connection),
                          ],
                        ),
            ),
          ),
        );
      },
    );
  }

  // ─── Tab content ──────────────────────────────────────────────────────────

  Widget _connectionUnavailableCard() {
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.link_off_rounded,
            color: Color(0xFFFFD88A),
            size: 30,
          ),
          const SizedBox(height: 14),
          const Text(
            'Connection not available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This Circle connection could not be loaded right now.',
            style: TextStyle(color: Color(0xFFB8AEE0), height: 1.45),
          ),
          const SizedBox(height: 14),
          // FIXED: Added retry button so users can attempt loading again
          // without navigating away (e.g. when the mirror hasn't propagated yet).
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _refreshConnection,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/bhrigu-match'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Circle'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _energyTab(SocialConnection connection) {
    // Guard: only subscribe to Firestore sub-collections when connection is active.
    if (connection.status != SocialConnectionStatus.active) {
      return _inactiveConnectionPlaceholder();
    }

    return StreamBuilder<ConnectionDailyEnergy?>(
      stream: _dailyEnergyService.watchToday(connection.connectionId),
      builder: (context, snapshot) {
        final energy = snapshot.data;
        final personEnergy = energy?.members[connection.otherUid];
        final hasReading = energy != null && personEnergy != null;
        final reveal = hasReading && _revealEnergyPending;

        if (reveal) {
          _consumeRevealFlag(energy: true);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            _profileHeader(connection),
            const SizedBox(height: 18),
            if (!hasReading)
              _emptyGeneratedCard(
                title: 'Generate today\'s energy',
                body:
                    'Listen to me carefully: see exactly what\'s going on with their energy today and how you need to move.',
                icon: Icons.bolt_rounded,
                loading: _generatingEnergy,
                onPressed: _generateEnergy,
              )
            else
              ..._generatedEnergyCards(
                connection,
                energy,
                personEnergy,
                animate: reveal,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _generatedEnergyCards(
    SocialConnection connection,
    ConnectionDailyEnergy energy,
    PersonDailyEnergy personEnergy, {
    bool animate = false,
  }) {
    return [
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              personEnergy.heading.isNotEmpty
                  ? personEnergy.heading
                  : '${connection.otherProfile.displayName}\'s Energy',
              style: GoogleFonts.cormorantGaramond(
                color: const Color(0xFFFFD88A),
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 14),
            RevealingText(
              personEnergy.energy,
              animate: animate,
              style: const TextStyle(
                color: Color(0xFFE5D5F5),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (energy.bondSignal.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              RevealingText(
                energy.bondSignal,
                animate: animate,
                style: const TextStyle(
                  color: Color(0xFFB8AEE0),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
      if (personEnergy.doText.isNotEmpty ||
          personEnergy.avoidText.isNotEmpty) ...[
        const SizedBox(height: 14),
        _twoColumnActionCards(
          doText: personEnergy.doText,
          avoidText: personEnergy.avoidText,
          animate: animate,
        ),
      ],
      if (personEnergy.bestApproach.isNotEmpty) ...[
        const SizedBox(height: 14),
        _textCard(
          label: 'BEST APPROACH',
          text: personEnergy.bestApproach,
          animate: animate,
        ),
      ],
    ];
  }

  Widget _compatibilityTab(SocialConnection connection) {
    // Guard: only subscribe to Firestore sub-collections when connection is active.
    if (connection.status != SocialConnectionStatus.active) {
      return _inactiveConnectionPlaceholder();
    }

    return StreamBuilder<List<ConnectionCompatibilityReading>>(
      stream: _compatibilityService.watchReadings(connection.connectionId),
      builder: (context, snapshot) {
        final readings = snapshot.data ?? const [];
        final reading = readings.isEmpty ? null : readings.first;
        final reveal = reading != null && _revealCompatibilityPending;

        if (reveal) {
          _consumeRevealFlag(energy: false);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            _profileHeader(connection),
            const SizedBox(height: 18),
            if (reading == null)
              _emptyGeneratedCard(
                title: 'Generate compatibility',
                body: connection.relationshipType ==
                        SocialRelationshipType.partner
                    ? 'Bhrigu will use both saved birth blueprints automatically. You only add the heart signal.'
                    : 'Compare both cosmic blueprints without exposing birth details.',
                icon: Icons.favorite_rounded,
                loading: _generatingCompatibility,
                onPressed: () => _generateCompatibility(connection),
              )
            else if (connection.relationshipType ==
                    SocialRelationshipType.partner &&
                reading.partnerMatchReading != null)
              _partnerMatchResult(reading.partnerMatchReading!, animate: reveal)
            else if (connection.relationshipType ==
                SocialRelationshipType.friend)
              _friendMatchResult(connection, reading, animate: reveal)
            else ...[
              _scoreGrid(reading.scores),
              const SizedBox(height: 14),
              _signalCard(
                title: 'Bond Signal',
                body: reading.dailyBondSignal,
                footer: connection.relationshipType.label,
                animate: reveal,
              ),
              const SizedBox(height: 14),
              _textCard(
                label: 'READING',
                text: reading.summary,
                animate: reveal,
              ),
              _textCard(
                label: 'STRENGTHS',
                text: reading.strengths,
                animate: reveal,
              ),
              _textCard(
                label: 'TENSIONS',
                text: reading.tensions,
                animate: reveal,
              ),
              _textCard(
                label: 'BHRIGU GUIDANCE',
                text: reading.advice,
                animate: reveal,
              ),
            ],
            const SizedBox(height: 18),
            const AiDisclaimer(),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _friendMatchResult(
    SocialConnection connection,
    ConnectionCompatibilityReading reading, {
    bool animate = false,
  }) {
    final scores = reading.scores;
    final safeOverallScore = _friendOverallScore(scores);
    final verdict = reading.verdict.trim().isEmpty
        ? _friendVerdictForScore(safeOverallScore)
        : reading.verdict.trim();
    final connectionType = reading.connectionType.trim().isEmpty
        ? _friendConnectionTypeFor(scores)
        : reading.connectionType.trim();
    final displayName = _safeDisplayName(connection);

    return Column(
      children: [
        _card(
          child: Column(
            children: [
              CompatibilityScoreRing(score: safeOverallScore),
              const SizedBox(height: 16),
              Text(
                verdict,
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFC7A867),
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                connectionType,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE8B530),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You and $displayName',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                connection.otherProfile.chartSummary,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB8AEE0)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _signalCard(
          title: 'Friend Signal',
          body: reading.dailyBondSignal.trim().isEmpty
              ? 'This friendship needs clarity before assumption.'
              : reading.dailyBondSignal.trim(),
          footer: connectionType,
          animate: animate,
        ),
        const SizedBox(height: 14),
        CompatibilityMetricCard(
          title: 'Emotional Support',
          subtitle: 'How safe this friendship feels when moods shift',
          score: _scoreFromAliases(scores, const ['emotional_support']),
          icon: Icons.groups_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Communication',
          subtitle: 'How clearly both minds understand each other',
          score: _scoreFromAliases(scores, const ['communication']),
          icon: Icons.forum_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Trust',
          subtitle: 'Reliability, honesty, and emotional safety',
          score: _scoreFromAliases(scores, const ['trust']),
          icon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Loyalty',
          subtitle: 'Consistency when life gets inconvenient',
          score: _scoreFromAliases(scores, const ['loyalty']),
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Conflict Repair',
          subtitle: 'How quickly awkwardness can become honesty again',
          score: _scoreFromAliases(
            scores,
            const ['conflict_repair', 'conflict_style'],
          ),
          icon: Icons.sync_alt_rounded,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Shared Rhythm',
          subtitle: 'Timing, pace, and social energy between friends',
          score: _scoreFromAliases(scores, const ['shared_rhythm']),
          icon: Icons.schedule_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Growth Potential',
          subtitle: 'How this friendship pushes both people to mature',
          score: _scoreFromAliases(scores, const ['growth_potential']),
          icon: Icons.trending_up_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Fun Energy',
          subtitle: 'Ease, humor, and low-pressure presence',
          score: _scoreFromAliases(scores, const ['fun_energy']),
          icon: Icons.celebration_outlined,
        ),
        const SizedBox(height: 14),
        _friendVerdictCard(reading, animate: animate),
      ],
    );
  }

  Widget _guidanceTab(SocialConnection connection) {
    if (connection.status != SocialConnectionStatus.active) {
      return _inactiveConnectionPlaceholder();
    }

    return StreamBuilder<List<ConnectionCompatibilityReading>>(
      stream: _compatibilityService.watchReadings(connection.connectionId),
      builder: (context, compatibilitySnapshot) {
        return StreamBuilder<ConnectionDailyEnergy?>(
          stream: _dailyEnergyService.watchToday(connection.connectionId),
          builder: (context, energySnapshot) {
            final readings = compatibilitySnapshot.data ?? const [];
            final reading = readings.isEmpty ? null : readings.first;
            final energy = energySnapshot.data;
            final questions = _questionsFor(connection);

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              children: [
                _textCard(
                  label: 'PRIVATE GUIDANCE',
                  text:
                      'Only you can see these follow-ups. They are not shared with ${connection.otherProfile.displayName}. You can change the selected prompt on the chat screen before sending.',
                ),
                const SizedBox(height: 12),
                ...questions.map(
                  (question) => _questionButton(
                    question,
                    onTap: () => _openFollowUp(
                      connection: connection,
                      reading: reading,
                      energy: energy,
                      question: question,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _ritualsTab(SocialConnection connection) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        _emptyGeneratedCard(
          title: 'Shared geomancy and tarot readings are coming',
          body:
              'Friends and partners will be able to open shared tarot and geomancy readings for this connection.',
          icon: Icons.auto_awesome_rounded,
          loading: false,
          onPressed: null,
        ),
      ],
    );
  }

  Widget _inactiveConnectionPlaceholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'This connection is no longer active.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFB8AEE0), height: 1.5),
        ),
      ),
    );
  }

  // ─── Utility widgets ──────────────────────────────────────────────────────

  List<String> _questionsFor(SocialConnection connection) {
    if (connection.relationshipType == SocialRelationshipType.friend) {
      return const [
        'What is this friend not saying to me?',
        'What quietly strains this friendship?',
        'Where is this friendship really heading?',
      ];
    }

    return const [
      'What are they not telling me right now?',
      'What quietly pulls this bond off course?',
      'What is this bond really building toward?',
    ];
  }

  Widget _profileHeader(SocialConnection connection) {
    final displayName = connection.otherProfile.displayName.trim().isEmpty
        ? 'BHR1GU user'
        : connection.otherProfile.displayName.trim();

    return _card(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF21103D),
            foregroundColor: const Color(0xFFFFD88A),
            child: Text(displayName[0].toUpperCase()),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${connection.relationshipType.label} · ${connection.otherProfile.chartSummary}',
                  style: const TextStyle(color: Color(0xFFB8AEE0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _scoreFromAliases(
    Map<String, int> scores,
    List<String> aliases, {
    int fallback = 60,
  }) {
    for (final alias in aliases) {
      final value = scores[alias];
      if (value != null && value > 0) {
        return value.clamp(0, 100).toInt();
      }
    }

    return fallback.clamp(0, 100).toInt();
  }

  List<int> _friendMetricValues(Map<String, int> scores) {
    return [
      _scoreFromAliases(scores, const ['emotional_support'], fallback: 0),
      _scoreFromAliases(scores, const ['communication'], fallback: 0),
      _scoreFromAliases(scores, const ['trust'], fallback: 0),
      _scoreFromAliases(scores, const ['loyalty'], fallback: 0),
      _scoreFromAliases(
        scores,
        const ['conflict_repair', 'conflict_style'],
        fallback: 0,
      ),
      _scoreFromAliases(scores, const ['shared_rhythm'], fallback: 0),
      _scoreFromAliases(scores, const ['growth_potential'], fallback: 0),
      _scoreFromAliases(scores, const ['fun_energy'], fallback: 0),
    ].where((value) => value > 0).toList(growable: false);
  }

  int _friendOverallScore(Map<String, int> scores) {
    final explicit = _scoreFromAliases(scores, const ['overall'], fallback: 0);
    if (explicit > 0) return explicit.clamp(60, 95).toInt();

    final values = _friendMetricValues(scores);
    if (values.isEmpty) return 60;

    final average =
        values.reduce((total, value) => total + value) / values.length;
    return average.round().clamp(60, 95).toInt();
  }

  String _friendConnectionTypeFor(Map<String, int> scores) {
    final trust = _scoreFromAliases(scores, const ['trust'], fallback: 0);
    final communication =
        _scoreFromAliases(scores, const ['communication'], fallback: 0);
    final funEnergy =
        _scoreFromAliases(scores, const ['fun_energy'], fallback: 0);
    final conflictRepair = _scoreFromAliases(
      scores,
      const ['conflict_repair', 'conflict_style'],
      fallback: 0,
    );
    final emotionalSupport =
        _scoreFromAliases(scores, const ['emotional_support'], fallback: 0);
    final loyalty = _scoreFromAliases(scores, const ['loyalty'], fallback: 0);
    final growthPotential =
        _scoreFromAliases(scores, const ['growth_potential'], fallback: 0);
    final sharedRhythm =
        _scoreFromAliases(scores, const ['shared_rhythm'], fallback: 0);

    if (trust >= 84 && communication >= 78) {
      return 'Trusted Inner-Circle Friend';
    }
    if (funEnergy >= 84 && conflictRepair < 70) {
      return 'High Fun, Low Repair';
    }
    if (emotionalSupport >= 82 && loyalty >= 78) {
      return 'Emotionally Reliable Friendship';
    }
    if (growthPotential >= 84 && sharedRhythm < 72) {
      return 'Growth Mirror';
    }
    if (communication >= 82) return 'Clear-Minded Friendship';
    if (conflictRepair >= 80) return 'Repairable Friendship';
    return 'Useful but Uneven Friendship';
  }

  String _friendVerdictForScore(int score) {
    if (score >= 88) return 'Rare friendship alignment';
    if (score >= 80) return 'Strong friendship compatibility';
    if (score >= 70) return 'Promising friendship';
    return 'Challenging friendship pattern';
  }

  Widget _friendVerdictCard(
    ConnectionCompatibilityReading reading, {
    bool animate = false,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "BHRIGU'S FRIENDSHIP VERDICT",
            style: TextStyle(
              color: Color(0xFFFFD88A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _friendVerdictSection(
            'FRIENDSHIP SNAPSHOT',
            reading.summary.trim().isEmpty
                ? 'Bhrigu is still reading this friendship pattern.'
                : reading.summary.trim(),
            animate: animate,
          ),
          _friendVerdictSection('WHAT WORKS', reading.strengths,
              animate: animate),
          _friendVerdictSection('WHERE IT GETS MESSY', reading.tensions,
              animate: animate),
          _friendVerdictSection('BHRIGU GUIDANCE', reading.advice,
              animate: animate),
        ],
      ),
    );
  }

  Widget _friendVerdictSection(
    String label,
    String text, {
    bool animate = false,
  }) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC7A867),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          RevealingText(
            cleanText,
            animate: animate,
            style: const TextStyle(
              color: Color(0xFFE5D5F5),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreGrid(Map<String, int> scores) {
    final entries = scores.entries.toList(growable: false);

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 118,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];

        return _card(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 34,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    entry.key.replaceAll('_', ' ').toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB8AEE0),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${entry.value}',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFFFD88A),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _partnerMatchResult(
    PartnerMatchReading reading, {
    bool animate = false,
  }) {
    final scores = reading.scores;
    final safeOverallScore = scores.overall.clamp(60, 95).toInt();

    return Column(
      children: [
        _card(
          child: Column(
            children: [
              CompatibilityScoreRing(score: safeOverallScore),
              const SizedBox(height: 16),
              Text(
                reading.verdict,
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFC7A867),
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reading.connectionType,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE8B530),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${reading.user.name} x ${reading.partner.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${reading.userSunSign} x ${reading.partnerSunSign} · ${reading.userMoonStyle} / ${reading.partnerMoonStyle}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB8AEE0)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        HeartSignalCard(
          prompt: reading.partner.emotionalPrompt,
          connectionType: reading.connectionType,
        ),
        const SizedBox(height: 14),
        CompatibilityMetricCard(
          title: 'Emotional Harmony',
          subtitle: 'Moon style and emotional rhythm',
          score: scores.emotional,
          icon: Icons.favorite_border,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Attraction Pull',
          subtitle: 'Chemistry, desire, and magnetic force',
          score: scores.attraction,
          icon: Icons.local_fire_department_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Communication',
          subtitle: 'How easily both minds understand each other',
          score: scores.communication,
          icon: Icons.forum_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Long-term Stability',
          subtitle: 'Patience, loyalty, and real-life bonding',
          score: scores.stability,
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 10),
        CompatibilityMetricCard(
          title: 'Karmic Bond',
          subtitle: 'Lessons, familiarity, and soul-pattern intensity',
          score: scores.karmic,
          icon: Icons.all_inclusive,
        ),
        if (reading.marriageGunaMatch.items.isNotEmpty) ...[
          const SizedBox(height: 14),
          _partnerGunaCard(reading.marriageGunaMatch, animate: animate),
        ],
        const SizedBox(height: 14),
        _partnerVerdictCard(reading.summary, animate: animate),
      ],
    );
  }

  Widget _partnerGunaCard(MarriageGunaMatch marriage, {bool animate = false}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '36 GUNA MATCH',
            style: TextStyle(
              color: Color(0xFFC7A867),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${marriage.totalScore}/${marriage.maxScore} · ${marriage.level}',
            style: const TextStyle(
              color: Color(0xFFFFD88A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          RevealingText(
            marriage.summary,
            animate: animate,
            style: const TextStyle(
              color: Color(0xFFE5D5F5),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerVerdictCard(String summary, {bool animate = false}) {
    final cleanSummary = summary.trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "BHRIGU'S VERDICT",
            style: TextStyle(
              color: Color(0xFFFFD88A),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          RevealingText(
            cleanSummary.isEmpty
                ? 'Bhrigu is still reading this pattern.'
                : cleanSummary,
            animate: animate && cleanSummary.isNotEmpty,
            style: const TextStyle(
              color: Color(0xFFE5D5F5),
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signalCard({
    required String title,
    required String body,
    required String footer,
    bool animate = false,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFFFD88A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          RevealingText(
            body.isEmpty ? 'The signal is still forming.' : body,
            animate: animate && body.isNotEmpty,
            style: GoogleFonts.cormorantGaramond(
              color: Colors.white,
              fontSize: 24,
              height: 1.25,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (footer.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              footer,
              style: const TextStyle(color: Color(0xFFB8AEE0)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _twoColumnActionCards({
    required String doText,
    required String avoidText,
    bool animate = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360;

        if (stack) {
          // FIXED: Column path uses plain _textCard without Expanded wrappers.
          return Column(
            children: [
              _textCard(
                  label: 'DO', text: doText, compact: true, animate: animate),
              const SizedBox(height: 10),
              _textCard(
                  label: 'AVOID',
                  text: avoidText,
                  compact: true,
                  animate: animate),
            ],
          );
        }

        // Row path: Expanded is valid only inside a Row.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _textCard(
                    label: 'DO',
                    text: doText,
                    compact: true,
                    animate: animate)),
            const SizedBox(width: 10),
            Expanded(
              child: _textCard(
                  label: 'AVOID',
                  text: avoidText,
                  compact: true,
                  animate: animate),
            ),
          ],
        );
      },
    );
  }

  Widget _textCard({
    required String label,
    required String text,
    bool compact = false,
    bool animate = false,
  }) {
    final hasText = text.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 12),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC7A867),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            RevealingText(
              hasText ? text : 'BHRIGU is still reading this pattern.',
              animate: animate && hasText,
              style: const TextStyle(
                color: Color(0xFFE5D5F5),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyGeneratedCard({
    required String title,
    required String body,
    required IconData icon,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFFFD88A), size: 30),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: Color(0xFFB8AEE0), height: 1.45),
          ),
          if (onPressed != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: loading ? null : onPressed,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: const Text('Reveal'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _questionButton(String question, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        onPressed: _creatingFollowUp ? null : onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        child: Row(
          children: [
            Expanded(child: Text(question)),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF15110A).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A301C)),
      ),
      child: child,
    );
  }
}

// ─── Switch-type dialog ───────────────────────────────────────────────────────

enum _ConnectionAction { switchType, report, remove, block }

class _HeartSignalDialog extends StatefulWidget {
  final String displayName;

  const _HeartSignalDialog({
    required this.displayName,
  });

  @override
  State<_HeartSignalDialog> createState() => _HeartSignalDialogState();
}

class _HeartSignalDialogState extends State<_HeartSignalDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();

    if (value.isEmpty) {
      setState(() {
        _error = 'Tell Bhrigu what your heart notices first.';
      });
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF15110A),
      title: const Text(
        'Heart signal',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you like most or least about ${widget.displayName}?',
            style: const TextStyle(
              color: Color(0xFFB8AEE0),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: const InputDecoration(
              hintText:
                  'Their confidence pulls me in, but their silence makes me overthink.',
              hintStyle: TextStyle(color: Color(0xFF8B7A56)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text(
            'Reveal',
            style: TextStyle(color: Color(0xFFFFD88A)),
          ),
        ),
      ],
    );
  }
}

class _SwitchTypeDialog extends StatefulWidget {
  final SocialRelationshipType current;

  const _SwitchTypeDialog({required this.current});

  @override
  State<_SwitchTypeDialog> createState() => _SwitchTypeDialogState();
}

class _SwitchTypeDialogState extends State<_SwitchTypeDialog> {
  late SocialRelationshipType _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF15110A),
      title: const Text(
        'Switch relationship type',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Switching will wipe existing compatibility readings so they regenerate under the new type.',
            style: TextStyle(color: Color(0xFFB8AEE0), height: 1.45),
          ),
          const SizedBox(height: 16),
          ...SocialRelationshipType.values.map(_relationshipOption),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selected == widget.current
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text(
            'Switch',
            style: TextStyle(color: Color(0xFFFFD88A)),
          ),
        ),
      ],
    );
  }

  Widget _relationshipOption(SocialRelationshipType type) {
    final selected = _selected == type;

    return InkWell(
      onTap: () => setState(() => _selected = type),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color:
                  selected ? const Color(0xFFFFD88A) : const Color(0xFFB8AEE0),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              type.label,
              style: TextStyle(
                color: selected ? const Color(0xFFFFD88A) : Colors.white,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

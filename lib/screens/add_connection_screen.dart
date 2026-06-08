import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/social_connection_model.dart';
import '../services/connection_service.dart';
import '../services/social_profile_service.dart';
import '../widgets/cosmic_screen_background.dart';

class AddConnectionScreen extends StatefulWidget {
  final String? initialInviteCode;
  final bool autoAcceptInvite;

  const AddConnectionScreen({
    super.key,
    this.initialInviteCode,
    this.autoAcceptInvite = false,
  });

  @override
  State<AddConnectionScreen> createState() => _AddConnectionScreenState();
}

class _AddConnectionScreenState extends State<AddConnectionScreen> {
  final _profileService = SocialProfileService();
  final _connectionService = ConnectionService();
  final _usernameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  SocialRelationshipType _relationshipType = SocialRelationshipType.friend;
  List<PublicAstrologyProfile> _results = const [];
  bool _loading = false;
  bool _autoAcceptStarted = false;

  @override
  void initState() {
    super.initState();

    final code = widget.initialInviteCode?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) {
      _inviteCodeController.text = code;
    }

    if (widget.autoAcceptInvite && code != null && code.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoAcceptStarted) return;
        _autoAcceptStarted = true;
        _acceptInvite();
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    // FIXED: Clear stale results immediately so old entries are not visible
    // while the new search is in flight.
    setState(() {
      _loading = true;
      _results = const [];
    });

    try {
      final results = await _profileService.searchPublicProfiles(
        _usernameController.text,
      );

      if (mounted) {
        setState(() => _results = results);
      }
    } catch (e, stack) {
      _logError('Search public profiles failed', e, stack);
      _showError('Could not search right now. Please try again later.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendRequest(PublicAstrologyProfile profile) async {
    setState(() => _loading = true);

    try {
      await _connectionService.sendConnectionRequest(
        targetUid: profile.uid,
        relationshipType: _relationshipType,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${profile.displayName}.')),
      );
      context.pop();
    } catch (e, stack) {
      _logError('Send connection request failed', e, stack);
      _showError('Could not send request right now.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createInvite() async {
    setState(() => _loading = true);

    try {
      final invite = await _connectionService.createInvite(
        relationshipType: _relationshipType,
      );
      final text = 'Add me on BHR1GU so we can see our cosmic compatibility.\n'
          'Tap: ${invite.inviteLink}\n'
          'Code: ${invite.code}';

      await Share.share(text);
    } catch (e, stack) {
      _logError('Create invite failed', e, stack);
      _showError('Could not create invite right now.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _acceptInvite() async {
    setState(() => _loading = true);

    try {
      final connectionId = await _connectionService.acceptInvite(
        _inviteCodeController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite accepted. Added to Circle.')),
      );

      if (connectionId != null && connectionId.isNotEmpty) {
        context.go('/bhrigu-match/connection/$connectionId');
      } else {
        context.go('/bhrigu-match');
      }
    } catch (e, stack) {
      _logError('Accept invite failed', e, stack);
      _showError('Could not accept invite right now.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _logError(String message, Object error, StackTrace stack) {
    debugPrint('$message: $error');
    debugPrintStack(stackTrace: stack);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF050408),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'ADD TO CIRCLE',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFB58E34),
            fontSize: 18,
            letterSpacing: 3,
          ),
        ),
      ),
      body: CosmicScreenBackground(
        child: Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
            children: [
              _relationshipSelector(),
              const SizedBox(height: 18),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search username',
                      style: TextStyle(
                        color: Color(0xFFFFD88A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: 'friend_username',
                        hintStyle: TextStyle(color: Color(0xFF8B7A56)),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    ),
                    const SizedBox(height: 12),
                    ..._results.map(_profileResult),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite someone new',
                      style: TextStyle(
                        color: Color(0xFFFFD88A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'They will create an account, complete onboarding, and accept your invite.',
                      style: TextStyle(color: Color(0xFFB8AEE0), height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _createInvite,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share invite'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter invite code',
                      style: TextStyle(
                        color: Color(0xFFFFD88A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _inviteCodeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'ABCD1234',
                        hintStyle: TextStyle(color: Color(0xFF8B7A56)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _acceptInvite,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Accept invite'),
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

  Widget _relationshipSelector() {
    return SegmentedButton<SocialRelationshipType>(
      segments: SocialRelationshipType.values
          .map(
            (type) => ButtonSegment(
              value: type,
              label: Text(type.label),
            ),
          )
          .toList(),
      selected: {_relationshipType},
      onSelectionChanged: (selected) {
        setState(() => _relationshipType = selected.first);
      },
    );
  }

  Widget _profileResult(PublicAstrologyProfile profile) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        profile.displayName,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '@${profile.username} · ${profile.chartSummary}',
        style: const TextStyle(color: Color(0xFFB8AEE0)),
      ),
      trailing: TextButton(
        onPressed: _loading ? null : () => _sendRequest(profile),
        // BUG-H FIXED: "Follow" is social-network language. This flow sends
        // a Circle connection request, so "Connect" is the correct label.
        child: const Text('Connect'),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15110A).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A301C)),
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/circle_safety_service.dart';

class CircleSafetyGate extends StatefulWidget {
  final Widget child;

  const CircleSafetyGate({
    super.key,
    required this.child,
  });

  @override
  State<CircleSafetyGate> createState() => _CircleSafetyGateState();
}

class _CircleSafetyGateState extends State<CircleSafetyGate> {
  final _service = CircleSafetyService();
  bool _loading = true;
  bool _accepted = false;
  bool _accepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final accepted = await _service.hasAcceptedCurrentPolicy();
      if (!mounted) return;
      setState(() {
        _accepted = accepted;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Circle guidelines. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    setState(() {
      _accepting = true;
      _error = null;
    });

    try {
      await _service.acceptCurrentPolicy();
      if (!mounted) return;
      setState(() {
        _accepted = true;
        _accepting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = 'Could not save your agreement. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD88A)),
      );
    }

    if (_accepted) return widget.child;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF15110A).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3A301C)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Circle Guidelines',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFFFD88A),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              _guideline(
                Icons.verified_user_outlined,
                'Connect only with people you know, trust, or intentionally invite.',
              ),
              _guideline(
                Icons.report_gmailerrorred_outlined,
                'Do not post or send harassment, hate, threats, sexual exploitation, or someone else\'s private details.',
              ),
              _guideline(
                Icons.block_rounded,
                'Use report, remove, or block if a connection feels unsafe or abusive.',
              ),
              _guideline(
                Icons.auto_awesome_rounded,
                'Circle readings are reflective astrology guidance, not proof of consent, certainty, or obligation.',
              ),
              const SizedBox(height: 14),
              Text(
                'By continuing, you agree to use Circle respectfully and understand that reports may be reviewed for safety.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFB8AEE0),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF8A80),
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _accepting ? null : _accept,
                  icon: _accepting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: const Text('I agree'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guideline(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFC7A867), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: const Color(0xFFE5D5F5),
                fontSize: 13.2,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

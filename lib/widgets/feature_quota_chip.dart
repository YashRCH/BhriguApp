import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/monetization_status.dart';
import '../services/monetization_service.dart';

enum FeatureQuotaKind {
  chat,
  tarot,
  geomancy,
  manualMatch,
}

class FeatureQuotaChip extends StatefulWidget {
  const FeatureQuotaChip({
    super.key,
    required this.feature,
    this.refreshKey,
    this.alignment = Alignment.centerLeft,
  });

  final FeatureQuotaKind feature;
  final Object? refreshKey;
  final Alignment alignment;

  @override
  State<FeatureQuotaChip> createState() => _FeatureQuotaChipState();
}

class _FeatureQuotaChipState extends State<FeatureQuotaChip> {
  final MonetizationService _service = MonetizationService();
  late Future<MonetizationStatus> _future;

  static const _muted = Color(0xFF8E83A8);

  @override
  void initState() {
    super.initState();
    _future = _service.status();
  }

  @override
  void didUpdateWidget(covariant FeatureQuotaChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _refresh();
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = _service.status();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: FutureBuilder<MonetizationStatus>(
        future: _future,
        builder: (context, snapshot) {
          final quota = _quotaText(snapshot.data);
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _refresh,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                loading ? 'Checking remaining...' : quota,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: _textAlignForAlignment(),
                style: TextStyle(
                  color: _muted.withValues(alpha: 0.72),
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _quotaText(MonetizationStatus? status) {
    if (status == null) return 'Remaining unavailable';

    final mode = status.mode.trim().toLowerCase();
    if (mode == 'unavailable') {
      return 'Remaining unavailable';
    }
    if (mode == 'off') {
      return '$_nounPluralTitle open for testing';
    }

    final isManualMatch = widget.feature == FeatureQuotaKind.manualMatch;

    // Plus subscribers on a yearly/annual plan have no metering.
    if (status.plusActive && _isYearlyPlan(status.plan)) {
      return isManualMatch
          ? 'Manual matches unlocked'
          : '$_nounPluralTitle unlimited';
    }
    if (status.plusActive && isManualMatch) {
      return 'Manual matches unlocked';
    }

    // Total credits the user can actually spend right now: included quota plus
    // owl/streak reward credits plus dakshana wallet credits. This is the sum
    // of every source the server may charge, so it is correct regardless of the
    // charge order (free users spend rewards first; paid plans spend the plan
    // allowance first and keep rewards for after it runs out).
    final field = _quotaField;
    final limit = status.limits[field] ?? 0;
    final used = status.usage[field] ?? 0;
    final includedRemaining = math.max(0, limit - used);
    final totalRemaining =
        includedRemaining + _rewardCredits(status) + _dakshanaCredits(status);

    if (isManualMatch) {
      return totalRemaining > 0
          ? '$_nounPluralTitle $totalRemaining remaining'
          : 'Manual matches locked';
    }

    return '$_nounPluralTitle $totalRemaining remaining';
  }

  String get _quotaField {
    switch (widget.feature) {
      case FeatureQuotaKind.chat:
        return 'chat';
      case FeatureQuotaKind.tarot:
        return 'tarot';
      case FeatureQuotaKind.geomancy:
        return 'geomancy';
      case FeatureQuotaKind.manualMatch:
        return 'manualMatch';
    }
  }

  String get _nounPluralTitle {
    switch (widget.feature) {
      case FeatureQuotaKind.chat:
        return 'Messages';
      case FeatureQuotaKind.tarot:
      case FeatureQuotaKind.geomancy:
        return 'Readings';
      case FeatureQuotaKind.manualMatch:
        return 'Matches';
    }
  }

  int _dakshanaCredits(MonetizationStatus status) {
    switch (widget.feature) {
      case FeatureQuotaKind.chat:
        return status.dakshana.chat;
      case FeatureQuotaKind.tarot:
        return status.dakshana.tarot;
      case FeatureQuotaKind.geomancy:
        return status.dakshana.geomancy;
      case FeatureQuotaKind.manualMatch:
        return 0;
    }
  }

  int _rewardCredits(MonetizationStatus status) {
    switch (widget.feature) {
      case FeatureQuotaKind.chat:
        return status.rewards['chat'] ?? 0;
      case FeatureQuotaKind.tarot:
        return status.rewards['tarot'] ?? 0;
      case FeatureQuotaKind.geomancy:
        return status.rewards['geomancy'] ?? 0;
      case FeatureQuotaKind.manualMatch:
        return 0;
    }
  }

  static bool _isYearlyPlan(String plan) {
    final normalized = plan.trim().toLowerCase();
    return normalized == 'yearly' || normalized == 'annual';
  }

  TextAlign _textAlignForAlignment() {
    if (widget.alignment.x > 0) return TextAlign.right;
    if (widget.alignment.x == 0) return TextAlign.center;
    return TextAlign.left;
  }
}

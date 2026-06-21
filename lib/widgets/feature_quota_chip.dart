import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/monetization_constants.dart';
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

    final field = _quotaField;
    final limit = status.limits[field] ?? 0;
    final used = status.usage[field] ?? 0;
    final rewardCredits = _rewardCredits(status);
    final dakshana = _dakshanaCredits(status);
    final includedRemaining = math.max(0, limit - used);
    final mode = status.mode.trim().toLowerCase();
    final openTesting = mode == 'off';

    if (mode == 'unavailable') {
      return 'Remaining unavailable';
    }

    if (openTesting) {
      return '$_nounPluralTitle open for testing';
    }

    if (status.plusActive) {
      if (_isYearlyPlan(status.plan)) {
        return '$_nounPluralTitle unlimited';
      }

      if (widget.feature == FeatureQuotaKind.manualMatch) {
        return 'Manual matches unlocked';
      }

      if (limit > 0) {
        return _meteredQuotaText(
          limit: limit,
          includedRemaining: includedRemaining,
          rewardCredits: rewardCredits,
          dakshanaCredits: dakshana,
        );
      }
    }

    if (limit > 0) {
      return _meteredQuotaText(
        limit: limit,
        includedRemaining: includedRemaining,
        rewardCredits: rewardCredits,
        dakshanaCredits: dakshana,
      );
    }

    if (rewardCredits > 0) {
      return '$_nounPluralTitle $rewardCredits remaining';
    }

    if (dakshana > 0) {
      final dakshanaTotal = _dakshanaTotalCredits;
      return dakshanaTotal > 0
          ? '$_nounPluralTitle $dakshana/$dakshanaTotal remaining'
          : '$_nounPluralTitle $dakshana remaining';
    }

    if (widget.feature == FeatureQuotaKind.manualMatch) {
      return 'Manual matches locked';
    }

    return '$_nounPluralTitle 0 remaining';
  }

  String _meteredQuotaText({
    required int limit,
    required int includedRemaining,
    required int rewardCredits,
    required int dakshanaCredits,
  }) {
    if (rewardCredits > 0) {
      return includedRemaining > 0
          ? '$_nounPluralTitle $rewardCredits bonus + $includedRemaining/$limit included'
          : '$_nounPluralTitle $rewardCredits bonus remaining';
    }

    if (includedRemaining > 0) {
      return '$_nounPluralTitle $includedRemaining/$limit remaining';
    }

    if (dakshanaCredits > 0) {
      final dakshanaTotal = _dakshanaTotalCredits;
      return dakshanaTotal > 0
          ? '$_nounPluralTitle $dakshanaCredits/$dakshanaTotal remaining'
          : '$_nounPluralTitle $dakshanaCredits remaining';
    }

    return '$_nounPluralTitle 0/$limit remaining';
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

  int get _dakshanaTotalCredits {
    switch (widget.feature) {
      case FeatureQuotaKind.chat:
        return dakshanaChatCredits;
      case FeatureQuotaKind.tarot:
        return dakshanaTarotCredits;
      case FeatureQuotaKind.geomancy:
        return dakshanaGeomancyCredits;
      case FeatureQuotaKind.manualMatch:
        return 0;
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

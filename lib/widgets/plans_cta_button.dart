import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const plansRoute = '/plans';

const _rusticGold = Color(0xFFC7A867);
const _deepPanel = Color(0xFF151126);
const _softText = Color(0xFFE5D5F5);

bool isQuotaExhaustedMessage(String message) {
  final lower = message.toLowerCase();
  return lower.contains('quota exhausted') ||
      lower.contains('limit reached') ||
      lower.contains('current plan has reached');
}

bool isPlansRecoveryMessage(String message) {
  final lower = message.toLowerCase();
  return isQuotaExhaustedMessage(message) ||
      lower.contains('this feature needs') ||
      lower.contains('requires bhrigu plus') ||
      lower.contains('requires bhr1gu plus') ||
      lower.contains('requires bhrigu plus or dakshana') ||
      lower.contains('requires bhr1gu plus or dakshana') ||
      lower.contains('active dakshana pack') ||
      lower.contains('needs bhrigu plus or dakshana') ||
      lower.contains('needs bhr1gu plus or dakshana') ||
      lower.contains('see plans') ||
      lower.contains('secure backend sync') ||
      lower.contains('secure sync') ||
      lower.contains('if you just purchased');
}

String plansRecoverySummary(String message) {
  if (isQuotaExhaustedMessage(message)) {
    return "You have used this plan's allowance. See plans to continue.";
  }

  final lower = message.toLowerCase();
  if (lower.contains('sync')) {
    return 'Access is updating. Open Plans to restore or refresh.';
  }

  return 'This feature needs a plan. See plans to continue.';
}

class PlansCtaButton extends StatelessWidget {
  const PlansCtaButton({
    super.key,
    this.message,
    this.label,
    this.onPressed,
    this.alignment = Alignment.centerLeft,
  });

  final String? message;
  final String? label;
  final VoidCallback? onPressed;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final text = label ??
        (isQuotaExhaustedMessage(message ?? '')
            ? 'Allowance used. See plans'
            : 'See plans');

    return Align(
      alignment: alignment,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed ?? () => context.push(plansRoute),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _rusticGold.withValues(alpha: 0.075),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _rusticGold.withValues(alpha: 0.38),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _rusticGold.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: _rusticGold,
                          fontSize: 11,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showPlansSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = _deepPanel,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 7),
      backgroundColor: backgroundColor.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _rusticGold.withValues(alpha: 0.24),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plansRecoverySummary(message),
            style: const TextStyle(
              color: _softText,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          PlansCtaButton(
            message: message,
            onPressed: () {
              messenger.hideCurrentSnackBar();
              context.push(plansRoute);
            },
          ),
        ],
      ),
    ),
  );
}

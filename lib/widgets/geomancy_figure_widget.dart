import 'package:flutter/material.dart';

import '../models/geomancy_figure_model.dart';

class GeomancyFigureWidget extends StatelessWidget {
  final GeomancyFigureModel figure;
  final String label;
  final bool compact;
  final bool highlighted;

  const GeomancyFigureWidget({
    super.key,
    required this.figure,
    required this.label,
    this.compact = false,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 6 : 14),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFF2A1848)
            : const Color(0xFF151126),
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFF59E0B).withAlpha(190)
              : const Color(0xFF2E2650),
          width: highlighted ? 1.4 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withAlpha(45),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF9D6FE8),
              fontSize: compact ? 7.5 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: compact ? 0.6 : 1.1,
            ),
          ),
          SizedBox(height: compact ? 5 : 10),
          _DotPattern(
            pattern: figure.pattern,
            compact: compact,
          ),
          SizedBox(height: compact ? 5 : 10),
          Text(
            figure.name,
            textAlign: TextAlign.center,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFF0ECF8),
              fontSize: compact ? 9 : 14,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              figure.latinName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B6080),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withAlpha(18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withAlpha(70),
                ),
              ),
              child: Text(
                figure.answerType,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD88A),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DotPattern extends StatelessWidget {
  final List<int> pattern;
  final bool compact;

  const _DotPattern({
    required this.pattern,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: pattern.map((value) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 1.6 : 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: value == 1
                ? [_dot()]
                : [
                    _dot(),
                    SizedBox(width: compact ? 8 : 15),
                    _dot(),
                  ],
          ),
        );
      }).toList(),
    );
  }

  Widget _dot() {
    final size = compact ? 5.5 : 8.5;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFD88A),
            Color(0xFFF59E0B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withAlpha(120),
            blurRadius: compact ? 5 : 9,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../utils/zodiac_signs.dart';

class ZodiacSignIcon extends StatelessWidget {
  const ZodiacSignIcon({
    super.key,
    required this.sign,
    this.size = 24,
    this.fallbackColor = const Color(0xFFC7A867),
  });

  final String? sign;
  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final assetPath = zodiacAssetPath(sign);

    if (assetPath == null) {
      return _FallbackZodiacIcon(
        sign: sign,
        size: size,
        color: fallbackColor,
      );
    }

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return _FallbackZodiacIcon(
          sign: sign,
          size: size,
          color: fallbackColor,
        );
      },
    );
  }
}

class _FallbackZodiacIcon extends StatelessWidget {
  const _FallbackZodiacIcon({
    required this.sign,
    required this.size,
    required this.color,
  });

  final String? sign;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Text(
          zodiacSignInitials(sign),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

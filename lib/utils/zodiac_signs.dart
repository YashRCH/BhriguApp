const String unknownZodiacSign = '—';

const List<String> zodiacSignNames = [
  'Aries',
  'Taurus',
  'Gemini',
  'Cancer',
  'Leo',
  'Virgo',
  'Libra',
  'Scorpio',
  'Sagittarius',
  'Capricorn',
  'Aquarius',
  'Pisces',
];

const Map<String, String> _zodiacAssetPaths = {
  'Aries': 'assets/zodiac/aries.png',
  'Taurus': 'assets/zodiac/taurus.png',
  'Gemini': 'assets/zodiac/gemini.png',
  'Cancer': 'assets/zodiac/cancer.png',
  'Leo': 'assets/zodiac/leo.png',
  'Virgo': 'assets/zodiac/virgo.png',
  'Libra': 'assets/zodiac/libra.png',
  'Scorpio': 'assets/zodiac/scorpio.png',
  'Sagittarius': 'assets/zodiac/sagittarius.png',
  'Capricorn': 'assets/zodiac/capricorn.png',
  'Aquarius': 'assets/zodiac/aquarius.png',
  'Pisces': 'assets/zodiac/pisces.png',
};

String cleanZodiacSignName(String? value) {
  final trimmed = value?.trim();

  if (trimmed == null || trimmed.isEmpty || trimmed == unknownZodiacSign) {
    return unknownZodiacSign;
  }

  final lower = trimmed.toLowerCase();
  for (final sign in zodiacSignNames) {
    if (lower.contains(sign.toLowerCase())) {
      return sign;
    }
  }

  return trimmed;
}

bool isKnownZodiacSign(String? value) {
  return zodiacSignNames.contains(cleanZodiacSignName(value));
}

String? zodiacAssetPath(String? value) {
  return _zodiacAssetPaths[cleanZodiacSignName(value)];
}

String zodiacSignInitials(String? value) {
  final sign = cleanZodiacSignName(value);

  return switch (sign) {
    'Sagittarius' => 'SG',
    'Capricorn' => 'CP',
    'Aquarius' => 'AQ',
    unknownZodiacSign => '--',
    _ => sign.length >= 2 ? sign.substring(0, 2).toUpperCase() : sign,
  };
}

String zodiacSignNameFromIso(String? isoDate) {
  if (isoDate == null) return unknownZodiacSign;

  final date = DateTime.tryParse(isoDate);
  if (date == null) return unknownZodiacSign;

  final month = date.month;
  final day = date.day;

  if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) {
    return 'Aries';
  }

  if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) {
    return 'Taurus';
  }

  if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) {
    return 'Gemini';
  }

  if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) {
    return 'Cancer';
  }

  if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) {
    return 'Leo';
  }

  if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) {
    return 'Virgo';
  }

  if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) {
    return 'Libra';
  }

  if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) {
    return 'Scorpio';
  }

  if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) {
    return 'Sagittarius';
  }

  if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) {
    return 'Capricorn';
  }

  if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) {
    return 'Aquarius';
  }

  return 'Pisces';
}

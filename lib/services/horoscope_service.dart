import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/firebase_constants.dart';
import '../utils/date_keys.dart';
import 'user_profile_cache_service.dart';

class HoroscopeService {
  static const _homeHoroscopeContentVersion =
      'home_signal_v6_complete_sentences';

  final _storage = const FlutterSecureStorage();

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        region: firebaseFunctionsRegion,
      );

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<Map<String, dynamic>?> getDailyHoroscope({String? uid}) async {
    final resolvedUid =
        uid ?? _auth.currentUser?.uid ?? await _storage.read(key: 'user_id');
    if (resolvedUid == null) return null;

    final today = DateTime.now();
    final dateKey = formatDateKey(today);

    final horoscopeRef = FirebaseFirestore.instance
        .collection('users')
        .doc(resolvedUid)
        .collection('horoscopes')
        .doc(dateKey);

    try {
      final cachedDoc = await horoscopeRef.get();

      if (cachedDoc.exists) {
        final cachedData = cachedDoc.data();

        if (cachedData != null) {
          final contentVersion = cachedData['contentVersion'] as String?;

          final morning = cachedData['morning'] as String? ?? '';
          final evening = cachedData['evening'] as String? ?? '';
          final moonPhaseLine =
              (cachedData['moonPhaseLine'] as String? ?? '').trim();
          final dailyEnergyLine =
              (cachedData['dailyEnergyLine'] as String? ?? '').trim();
          final bhriguToday =
              (cachedData['bhriguToday'] as String? ?? '').trim();
          final yourTransit =
              (cachedData['yourTransit'] as String? ?? '').trim();
          final relationships =
              (cachedData['relationships'] as String? ?? '').trim();
          final workMoney = (cachedData['workMoney'] as String? ?? '').trim();
          final innerWeather =
              (cachedData['innerWeather'] as String? ?? '').trim();
          final mantra = (cachedData['mantra'] as String? ?? '').trim();
          final doText = _stringOrJoinedList(
            cachedData['doText'],
            cachedData['doLines'],
          );
          final avoidText = _stringOrJoinedList(
            cachedData['avoidText'],
            cachedData['avoidLines'],
          );

          if (contentVersion == _homeHoroscopeContentVersion &&
              (morning.isNotEmpty || evening.isNotEmpty)) {
            return {
              'morning': morning,
              'evening': evening,
              'bhriguToday': bhriguToday,
              'yourTransit': yourTransit,
              'doText': doText,
              'avoidText': avoidText,
              'relationships': relationships,
              'workMoney': workMoney,
              'innerWeather': innerWeather,
              'mantra': mantra,
              'moonPhaseLine': moonPhaseLine.isEmpty
                  ? getMoonPhaseOneLiner(date: today)
                  : moonPhaseLine,
              'dailyEnergyLine': dailyEnergyLine.isEmpty
                  ? getDailyEnergyOneLiner(date: today)
                  : dailyEnergyLine,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore horoscope cache read error: $e');
    }

    final data = await UserProfileCacheService.instance.userData();
    if (data == null) return null;

    final moonPhase = getMoonPhaseInfo(date: today);
    final dailyEnergy = getDailyEnergyInfo(date: today);
    final moonPhaseLine = getMoonPhaseOneLiner(moonPhaseInfo: moonPhase);
    final dailyEnergyLine = getDailyEnergyOneLiner(
      dailyEnergyInfo: dailyEnergy,
    );

    final birthData = 'Name: ${data['name']}, DOB: ${data['dob']}, '
        'Time: ${data['timeOfBirth']}, Place: ${data['placeOfBirth']}';
    final westernChart = data['westernChart'];
    final vedicChart = data['vedicChart'];
    final chartGeneratedBy = data['chartGeneratedBy'] ?? 'unknown';
    final chartCalculationSource = data['chartCalculationSource'] ?? 'unknown';
    final chartCalculationVersion =
        data['chartCalculationVersion'] ?? 'unknown';
    final chartCalculationMeta = data['chartCalculationMeta'];

    final prompt = '''
You are Bhrigu, a Vedic and Western astrology sage.
Generate a daily horoscope for $dateKey for this person: $birthData

User cosmic blueprint generated source:
chartGeneratedBy: $chartGeneratedBy
chartCalculationSource: $chartCalculationSource
chartCalculationVersion: $chartCalculationVersion
chartCalculationMeta: $chartCalculationMeta

User NASA/JPL-backed cosmic blueprint placements:
Western chart: $westernChart
Vedic chart: $vedicChart

Use the saved chart placements as the user's natal blueprint. NASA/JPL supplies astronomical planet positions only; you provide interpretation from the chart placements and today's transits.

Today's lunar and planetary context:
Moon phase: ${moonPhase.name}, age ${moonPhase.moonAge.toStringAsFixed(2)} days, illumination ${(moonPhase.illumination * 100).round()}%.
Daily planetary ruler: ${dailyEnergy.planet}.
Fallback moon phase line: $moonPhaseLine
Fallback daily energy line: $dailyEnergyLine

Respond in this exact format and nothing else:
BHRIGU_TODAY: [1 sharp sentence, maximum 22 words]
YOUR_TRANSIT: [1-2 sentences explaining the strongest chart/transit logic]

DO: [One complete paragraph, 1-2 sentences. Make it actionable and specific. No bullet points.]

AVOID: [One complete paragraph, 1-2 sentences. Make it psychologically sharp. No bullet points.]

RELATIONSHIPS: [1-2 direct sentences]
WORK_MONEY: [1-2 direct sentences]
INNER_WEATHER: [1-2 direct sentences]
MANTRA: [1 memorable line, maximum 14 words]
MOON_PHASE_LINE: [1 short line, maximum 12 words, based on the moon phase and the user's cosmic blueprint]
DAILY_ENERGY_LINE: [1 short line, maximum 12 words, based on today's planetary ruler and the user's cosmic blueprint]

Style reference:
BHRIGU_TODAY: You already know what is draining you. You are just waiting for it to become dramatic enough to justify leaving.
YOUR_TRANSIT: The Moon activates your natal Venus while Saturn pressures your emotional rhythm. Desire and duty are not moving at the same speed today.

DO: Choose the slower answer and clean one unfinished task before you ask the universe for another sign. Let someone prove consistency before you reward potential.

AVOID: Avoid explaining your pain too beautifully or checking for signs instead of patterns. Do not make loyalty out of fear.

RELATIONSHIPS: A soft message may hide a serious need. Do not punish someone for being indirect, but do not translate their silence into love.
WORK_MONEY: Small discipline brings more luck than big ambition today.
INNER_WEATHER: You may feel calm outside and restless inside. That is not confusion; it is restraint.
MANTRA: Do not romanticize what repeatedly costs you peace.

Use the user's saved NASA/JPL-backed chart placements, daily transits, and transit-to-natal aspects when provided by the backend.
Do not invent missing placements. Do not write generic sun-sign horoscope content.
Keep this sparse, impressive, modern, slightly confronting, and useful. Do not copy the example.
Every sentence must be complete and end with a period. Do not use ellipses.
Do not repeat any sentence or key phrase across sections.
MANTRA must not repeat, summarize, or rephrase BHRIGU_TODAY; it must be a separate command.
Do not ask questions at the end. Do not sound like a newspaper horoscope. Do not overuse mystical words.
''';

    try {
      final user = _auth.currentUser;

      if (user == null) {
        debugPrint('Horoscope error: FirebaseAuth.currentUser is null');
        return null;
      }

      final idToken = await user.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        debugPrint('Horoscope error: Firebase ID token is empty');
        return null;
      }

      final callable = _functions.httpsCallable(
        'generateDailyHoroscope',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 180),
        ),
      );

      final result = await callable.call(
        {
          'idToken': idToken,
          'prompt': prompt,
          'dateKey': dateKey,
          'contentVersion': _homeHoroscopeContentVersion,
          'moonPhaseLine': moonPhaseLine,
          'dailyEnergyLine': dailyEnergyLine,
          'horoscopeMeta': {
            'moonPhase': moonPhase.name,
            'moonAge': moonPhase.moonAge,
            'moonIllumination': moonPhase.illumination,
            'dailyPlanet': dailyEnergy.planet,
          },
        },
      );

      final resultData = Map<String, dynamic>.from(
        result.data as Map,
      );

      final returnedBhriguToday =
          (resultData['bhriguToday'] as String? ?? '').trim();
      final returnedYourTransit =
          (resultData['yourTransit'] as String? ?? '').trim();
      final returnedRelationships =
          (resultData['relationships'] as String? ?? '').trim();
      final returnedWorkMoney =
          (resultData['workMoney'] as String? ?? '').trim();
      final returnedInnerWeather =
          (resultData['innerWeather'] as String? ?? '').trim();
      final returnedMantra = (resultData['mantra'] as String? ?? '').trim();
      final returnedDoText = _stringOrJoinedList(
        resultData['doText'],
        resultData['doLines'],
      );
      final returnedAvoidText = _stringOrJoinedList(
        resultData['avoidText'],
        resultData['avoidLines'],
      );
      final returnedMoonPhaseLine =
          (resultData['moonPhaseLine'] as String? ?? '').trim();
      final returnedDailyEnergyLine =
          (resultData['dailyEnergyLine'] as String? ?? '').trim();

      if (returnedBhriguToday.isNotEmpty ||
          returnedYourTransit.isNotEmpty ||
          returnedMantra.isNotEmpty) {
        return {
          'morning':
              (resultData['morning'] as String? ?? returnedBhriguToday).trim(),
          'evening':
              (resultData['evening'] as String? ?? returnedYourTransit).trim(),
          'bhriguToday': returnedBhriguToday,
          'yourTransit': returnedYourTransit,
          'doText': returnedDoText,
          'avoidText': returnedAvoidText,
          'relationships': returnedRelationships,
          'workMoney': returnedWorkMoney,
          'innerWeather': returnedInnerWeather,
          'mantra': returnedMantra,
          'moonPhaseLine': returnedMoonPhaseLine.isEmpty
              ? moonPhaseLine
              : returnedMoonPhaseLine,
          'dailyEnergyLine': returnedDailyEnergyLine.isEmpty
              ? dailyEnergyLine
              : returnedDailyEnergyLine,
        };
      }

      final text = resultData['text'] as String? ?? '';
      final normalizedText = text.replaceAll('**', '');

      final bhriguTodayMatch = RegExp(
        r'(?:\[?\s*BHRIGU[\s_]+TODAY\s*\]?):?\s*(.+?)(?=\[?\s*YOUR[\s_]+TRANSIT\s*\]?:?|\[?\s*DO\s*\]?:?|\[?\s*AVOID\s*\]?:?|\[?\s*RELATIONSHIPS\s*\]?:?|\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)',
        dotAll: true,
      ).firstMatch(normalizedText);

      final yourTransitMatch = RegExp(
        r'(?:\[?\s*YOUR[\s_]+TRANSIT\s*\]?):?\s*(.+?)(?=\[?\s*DO\s*\]?:?|\[?\s*AVOID\s*\]?:?|\[?\s*RELATIONSHIPS\s*\]?:?|\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)',
        dotAll: true,
      ).firstMatch(normalizedText);

      final doMatch = RegExp(
        r'(?:\[?\s*DO\s*\]?):?\s*(.+?)(?=\[?\s*AVOID\s*\]?:?|\[?\s*RELATIONSHIPS\s*\]?:?|\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)',
        dotAll: true,
      ).firstMatch(normalizedText);

      final avoidMatch = RegExp(
        r'(?:\[?\s*AVOID\s*\]?):?\s*(.+?)(?=\[?\s*RELATIONSHIPS\s*\]?:?|\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)',
        dotAll: true,
      ).firstMatch(normalizedText);

      final relationshipsMatch = RegExp(
        r'(?:\[?\s*RELATIONSHIPS\s*\]?):?\s*(.+?)(?=\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?:?|\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)',
        dotAll: true,
      ).firstMatch(normalizedText);

      final workMoneyMatch = RegExp(
        r'(?:\[?\s*(?:WORK_MONEY|WORK\s*\/\s*MONEY)\s*\]?):?\s*(.+?)(?=\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?:?|\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)',
        dotAll: true,
      ).firstMatch(normalizedText);

      final innerWeatherMatch = RegExp(
        r'(?:\[?\s*(?:INNER_WEATHER|INNER\s+WEATHER)\s*\]?):?\s*(.+?)(?=\[?\s*MANTRA\s*\]?:?|MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)',
        dotAll: true,
      ).firstMatch(normalizedText);

      final mantraMatch = RegExp(
        r'(?:\[?\s*MANTRA\s*\]?):?\s*(.+?)(?=MOON_PHASE_LINE:|DAILY_ENERGY_LINE:|$)',
        dotAll: true,
      ).firstMatch(normalizedText);

      final moonPhaseLineMatch = RegExp(
        r'MOON_PHASE_LINE:\s*(.+?)(?=DAILY_ENERGY_LINE:|$)',
        dotAll: true,
      ).firstMatch(normalizedText);

      final dailyEnergyLineMatch =
          RegExp(r'DAILY_ENERGY_LINE:\s*(.+)', dotAll: true)
              .firstMatch(normalizedText);

      final bhriguToday = _limitWords(
        _cleanGeneratedLine(bhriguTodayMatch?.group(1) ?? ''),
        24,
      );
      final yourTransit = _limitWords(
        _cleanGeneratedLine(yourTransitMatch?.group(1) ?? ''),
        42,
      );
      final doText = _limitWords(
        _cleanGeneratedLine(
          doMatch?.group(1) ??
              'Choose one clean action and finish it before seeking signs.',
        ),
        34,
      );
      final avoidText = _limitWords(
        _cleanGeneratedLine(
          avoidMatch?.group(1) ??
              'Avoid turning silence into evidence, drama, or prophecy.',
        ),
        34,
      );
      final relationships = _limitWords(
        _cleanGeneratedLine(relationshipsMatch?.group(1) ?? ''),
        34,
      );
      final workMoney = _limitWords(
        _cleanGeneratedLine(workMoneyMatch?.group(1) ?? ''),
        28,
      );
      final innerWeather = _limitWords(
        _cleanGeneratedLine(innerWeatherMatch?.group(1) ?? ''),
        30,
      );
      final mantra = _limitWords(
        _cleanGeneratedLine(
          mantraMatch?.group(1) ?? 'Choose peace before performance.',
        ),
        14,
      );
      final distinctMantra = _normalizedReadingLine(mantra) ==
              _normalizedReadingLine(
                _firstSentence(bhriguToday),
              )
          ? 'Choose peace before performance.'
          : mantra;
      final morning = bhriguToday;
      final evening = yourTransit;
      final generatedMoonPhaseLine = _limitWords(
        _cleanGeneratedLine(moonPhaseLineMatch?.group(1) ?? moonPhaseLine),
        12,
      );
      final generatedDailyEnergyLine = _limitWords(
        _cleanGeneratedLine(
          dailyEnergyLineMatch?.group(1) ?? dailyEnergyLine,
        ),
        12,
      );

      return {
        'morning': morning,
        'evening': evening,
        'bhriguToday': bhriguToday,
        'yourTransit': yourTransit,
        'doText': doText,
        'avoidText': avoidText,
        'relationships': relationships,
        'workMoney': workMoney,
        'innerWeather': innerWeather,
        'mantra': distinctMantra,
        'moonPhaseLine': generatedMoonPhaseLine,
        'dailyEnergyLine': generatedDailyEnergyLine,
      };
    } catch (e) {
      debugPrint('Horoscope error: $e');
      return null;
    }
  }

  String _cleanGeneratedLine(String value) {
    return value
        .replaceAll('**', '')
        .replaceFirstMapped(
          RegExp(r'^\s*\[([^\]]+)\]\s*'),
          (match) => '${match.group(1)} ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\-\*\u2022\s]+'), '')
        .trim();
  }

  String _firstSentence(String value) {
    final cleaned = _cleanGeneratedLine(value);
    final match = RegExp(r'^(.+?[.!?])(?:\s|$)').firstMatch(cleaned);
    return match?.group(1)?.trim() ?? cleaned;
  }

  String _terminalPunctuation(String value) {
    final cleaned = _cleanGeneratedLine(value)
        .replaceAll(RegExp(r'(?:\.{3,}|…)+$'), '')
        .trim();

    if (cleaned.isEmpty) return '';
    if (RegExp(r'[.!?]$').hasMatch(cleaned)) return cleaned;

    return '$cleaned.';
  }

  String _normalizedReadingLine(String value) {
    return _cleanGeneratedLine(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];

    return value
        .map((item) => _cleanGeneratedLine(item.toString()))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _stringOrJoinedList(dynamic value, dynamic legacyList) {
    final text = _cleanGeneratedLine(value?.toString() ?? '');

    if (text.isNotEmpty && text != 'null') return text;

    final lines = _stringList(legacyList);
    return lines.join(' ').trim();
  }

  // ignore: unused_element
  List<String> _splitGeneratedLines(String? value) {
    if (value == null || value.trim().isEmpty) return const [];

    final normalized = value
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .split('\n')
        .expand((line) => line.split(RegExp(r'\s*;\s*')))
        .map((line) {
          return _cleanGeneratedLine(
            line.replaceFirst(RegExp(r'^\d+[\).\s-]+'), ''),
          );
        })
        .where((line) => line.isNotEmpty)
        .toList();

    return normalized;
  }

  // ignore: unused_element
  List<String> _ensureActionLines(
    List<String> generated,
    List<String> fallback, {
    required int maxWords,
  }) {
    final source = generated.isEmpty ? fallback : generated;

    return source
        .take(3)
        .map((line) => _limitWords(line, maxWords))
        .toList(growable: false);
  }

  String _limitWords(String value, int maxWords) {
    final cleaned =
        _cleanGeneratedLine(value).replaceAll(RegExp(r'\.{3,}|…'), '').trim();
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

    if (words.length <= maxWords) return _terminalPunctuation(cleaned);

    final sentences = RegExp(r'[^.!?]+[.!?]+')
        .allMatches(cleaned)
        .map((match) => match.group(0)!.trim())
        .toList();
    final selected = <String>[];

    for (final sentence in sentences) {
      final next = [...selected, sentence].join(' ');
      final nextWords = next.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);

      if (nextWords.length <= maxWords) {
        selected.add(sentence);
      }
    }

    if (selected.isNotEmpty) {
      return _terminalPunctuation(selected.join(' '));
    }

    return _terminalPunctuation(words.take(maxWords).join(' '));
  }

  MoonPhaseInfo getMoonPhaseInfo({DateTime? date}) {
    final selectedDate = (date ?? DateTime.now()).toUtc();

    final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
    const synodicMonth = 29.530588853;
    const millisecondsPerDay = 86400000;

    final daysSinceKnownNewMoon =
        selectedDate.difference(knownNewMoon).inMilliseconds /
            millisecondsPerDay;

    final moonAge =
        ((daysSinceKnownNewMoon % synodicMonth) + synodicMonth) % synodicMonth;

    final phase = moonAge / synodicMonth;
    final illumination = (1 - math.cos(phase * 2 * math.pi)) / 2;

    if (moonAge < 1.0 || moonAge > synodicMonth - 0.5) {
      return MoonPhaseInfo(
        name: 'New Moon',
        icon: '🌑',
        advice:
            'Pause, reset, and set one clear intention before taking action.',
        phase: phase,
        moonAge: moonAge,
        illumination: illumination,
      );
    }

    if (phase < 0.1875) {
      return MoonPhaseInfo(
        name: 'Waxing Crescent',
        icon: '🌒',
        advice: 'Take one small step toward something you want to grow.',
        phase: phase,
        moonAge: moonAge,
        illumination: illumination,
      );
    }

    if (phase < 0.3125) {
      return MoonPhaseInfo(
        name: 'First Quarter',
        icon: '🌓',
        advice: 'Choose action over overthinking. A decision needs movement.',
        phase: phase,
        moonAge: moonAge,
        illumination: illumination,
      );
    }

    if (phase < 0.4375) {
      return MoonPhaseInfo(
        name: 'Waxing Gibbous',
        icon: '🌔',
        advice: 'Refine your plans. Improve what is already in motion.',
        phase: phase,
        moonAge: moonAge,
        illumination: illumination,
      );
    }

    if (phase < 0.5625) {
      return MoonPhaseInfo(
        name: 'Full Moon',
        icon: '🌕',
        advice:
            'Notice what is being revealed. Release emotional excess tonight.',
        phase: phase,
        moonAge: moonAge,
        illumination: illumination,
      );
    }

    if (phase < 0.6875) {
      return MoonPhaseInfo(
        name: 'Waning Gibbous',
        icon: '🌖',
        advice: 'Review the lesson, share wisdom, and avoid forcing outcomes.',
        phase: phase,
        moonAge: moonAge,
        illumination: illumination,
      );
    }

    if (phase < 0.8125) {
      return MoonPhaseInfo(
        name: 'Last Quarter',
        icon: '🌗',
        advice:
            'Cut away what drains you. Simplify your energy and commitments.',
        phase: phase,
        moonAge: moonAge,
        illumination: illumination,
      );
    }

    return MoonPhaseInfo(
      name: 'Waning Crescent',
      icon: '🌘',
      advice: 'Rest, reflect, and prepare for a fresh emotional cycle.',
      phase: phase,
      moonAge: moonAge,
      illumination: illumination,
    );
  }

  String getMoonPhase() {
    final phase = getMoonPhaseInfo();
    return '${phase.icon} ${phase.name}';
  }

  String getMoonPhaseAdvice() {
    return getMoonPhaseInfo().advice;
  }

  double getMoonPhaseValue({DateTime? date}) {
    return getMoonPhaseInfo(date: date).phase;
  }

  double getMoonAge({DateTime? date}) {
    return getMoonPhaseInfo(date: date).moonAge;
  }

  double getMoonIllumination({DateTime? date}) {
    return getMoonPhaseInfo(date: date).illumination;
  }

  String getPlanetaryEnergy({DateTime? date}) {
    final energy = getDailyEnergyInfo(date: date);
    return '${energy.symbol} ${energy.planet} — ${energy.advice}';
  }

  DailyEnergyInfo getDailyEnergyInfo({DateTime? date}) {
    final day = (date ?? DateTime.now()).weekday;

    const planets = {
      1: DailyEnergyInfo(
        symbol: '☽',
        planet: 'Moon',
        advice: 'trust your intuition today',
        theme: 'emotional clarity',
      ),
      2: DailyEnergyInfo(
        symbol: '♂',
        planet: 'Mars',
        advice: 'channel your energy with purpose',
        theme: 'courage and action',
      ),
      3: DailyEnergyInfo(
        symbol: '☿',
        planet: 'Mercury',
        advice: 'choose precise words and clear decisions',
        theme: 'communication',
      ),
      4: DailyEnergyInfo(
        symbol: '♃',
        planet: 'Jupiter',
        advice: 'expand with wisdom, not excess',
        theme: 'growth and perspective',
      ),
      5: DailyEnergyInfo(
        symbol: '♀',
        planet: 'Venus',
        advice: 'nurture love, beauty, and harmony',
        theme: 'relationships',
      ),
      6: DailyEnergyInfo(
        symbol: '♄',
        planet: 'Saturn',
        advice: 'honor discipline and structure',
        theme: 'responsibility',
      ),
      7: DailyEnergyInfo(
        symbol: '☉',
        planet: 'Sun',
        advice: 'step into your power with humility',
        theme: 'confidence',
      ),
    };

    return planets[day] ?? planets[7]!;
  }

  String getMoonPhaseOneLiner({
    DateTime? date,
    MoonPhaseInfo? moonPhaseInfo,
  }) {
    final moon = moonPhaseInfo ?? getMoonPhaseInfo(date: date);

    return switch (moon.name) {
      'New Moon' => 'Plant one clean intention before the day gets loud.',
      'Waxing Crescent' => 'Take the smallest useful step toward growth.',
      'First Quarter' => 'Choose action where hesitation has been winning.',
      'Waxing Gibbous' => 'Refine the plan before asking for results.',
      'Full Moon' => 'Let the revealed truth simplify your next move.',
      'Waning Gibbous' => 'Carry the lesson forward without forcing closure.',
      'Last Quarter' => 'Release the commitment that keeps draining focus.',
      _ => 'Rest, clear space, and prepare for renewal.',
    };
  }

  String getDailyEnergyOneLiner({
    DateTime? date,
    DailyEnergyInfo? dailyEnergyInfo,
  }) {
    final energy = dailyEnergyInfo ?? getDailyEnergyInfo(date: date);

    return switch (energy.planet) {
      'Moon' => 'Let emotion inform you without running the day.',
      'Mars' => 'Move with courage, but keep your aim clean.',
      'Mercury' => 'Say less, mean more, and decide clearly.',
      'Jupiter' => 'Expand the right thing, not every thing.',
      'Venus' => 'Choose harmony without abandoning your own value.',
      'Saturn' => 'Structure gives your energy somewhere useful to land.',
      _ => 'Lead from center, not from the need to prove.',
    };
  }

  String getSunSign(String? isoDate) {
    if (isoDate == null) return '—';

    final d = DateTime.tryParse(isoDate);
    if (d == null) return '—';

    final m = d.month;
    final day = d.day;

    if ((m == 3 && day >= 21) || (m == 4 && day <= 19)) {
      return 'Aries ♈';
    }

    if ((m == 4 && day >= 20) || (m == 5 && day <= 20)) {
      return 'Taurus ♉';
    }

    if ((m == 5 && day >= 21) || (m == 6 && day <= 20)) {
      return 'Gemini ♊';
    }

    if ((m == 6 && day >= 21) || (m == 7 && day <= 22)) {
      return 'Cancer ♋';
    }

    if ((m == 7 && day >= 23) || (m == 8 && day <= 22)) {
      return 'Leo ♌';
    }

    if ((m == 8 && day >= 23) || (m == 9 && day <= 22)) {
      return 'Virgo ♍';
    }

    if ((m == 9 && day >= 23) || (m == 10 && day <= 22)) {
      return 'Libra ♎';
    }

    if ((m == 10 && day >= 23) || (m == 11 && day <= 21)) {
      return 'Scorpio ♏';
    }

    if ((m == 11 && day >= 22) || (m == 12 && day <= 21)) {
      return 'Sagittarius ♐';
    }

    if ((m == 12 && day >= 22) || (m == 1 && day <= 19)) {
      return 'Capricorn ♑';
    }

    if ((m == 1 && day >= 20) || (m == 2 && day <= 18)) {
      return 'Aquarius ♒';
    }

    return 'Pisces ♓';
  }
}

class MoonPhaseInfo {
  final String name;
  final String icon;
  final String advice;
  final double phase;
  final double moonAge;
  final double illumination;

  const MoonPhaseInfo({
    required this.name,
    required this.icon,
    required this.advice,
    required this.phase,
    required this.moonAge,
    required this.illumination,
  });
}

class DailyEnergyInfo {
  final String symbol;
  final String planet;
  final String advice;
  final String theme;

  const DailyEnergyInfo({
    required this.symbol,
    required this.planet,
    required this.advice,
    required this.theme,
  });
}

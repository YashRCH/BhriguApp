import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/ai_response_language.dart';

class TarotCard {
  final String name;
  final String asset;
  final String keywords;
  final String uprightMeaning;

  const TarotCard({
    required this.name,
    required this.asset,
    required this.keywords,
    required this.uprightMeaning,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'asset': asset,
      'keywords': keywords,
      'uprightMeaning': uprightMeaning,
    };
  }

  factory TarotCard.fromJson(Map<String, dynamic> json) {
    return TarotCard(
      name: json['name'] as String? ?? '',
      asset: json['asset'] as String? ?? '',
      keywords: json['keywords'] as String? ?? '',
      uprightMeaning: json['uprightMeaning'] as String? ?? '',
    );
  }
}

class TarotSavedReading {
  final String id;
  final String question;
  final TarotCard past;
  final TarotCard present;
  final TarotCard future;
  final String reading;
  final DateTime createdAt;
  final String aiResponseLanguage;

  const TarotSavedReading({
    required this.id,
    required this.question,
    required this.past,
    required this.present,
    required this.future,
    required this.reading,
    required this.createdAt,
    this.aiResponseLanguage = englishAiResponseLanguage,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'past': past.toJson(),
      'present': present.toJson(),
      'future': future.toJson(),
      'reading': reading,
      'createdAt': Timestamp.fromDate(createdAt),
      'aiResponseLanguage': normalizeAiResponseLanguage(aiResponseLanguage),
    };
  }

  factory TarotSavedReading.fromJson({
    required String id,
    required Map<String, dynamic> json,
  }) {
    return TarotSavedReading(
      id: id,
      question: json['question'] as String? ?? '',
      past: TarotCard.fromJson(
        Map<String, dynamic>.from(json['past'] as Map? ?? {}),
      ),
      present: TarotCard.fromJson(
        Map<String, dynamic>.from(json['present'] as Map? ?? {}),
      ),
      future: TarotCard.fromJson(
        Map<String, dynamic>.from(json['future'] as Map? ?? {}),
      ),
      reading: json['reading'] as String? ?? '',
      createdAt: _dateFromValue(json['createdAt']),
      aiResponseLanguage: normalizeAiResponseLanguage(
        json['aiResponseLanguage'],
      ),
    );
  }

  static DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }
}

const List<TarotCard> majorArcana = [
  TarotCard(
      name: 'The Fool',
      asset: 'assets/tarot/fool.webp',
      keywords: 'beginnings, innocence, spontaneity',
      uprightMeaning: 'A leap of faith into the unknown.'),
  TarotCard(
      name: 'The Magician',
      asset: 'assets/tarot/magician.webp',
      keywords: 'willpower, skill, manifestation',
      uprightMeaning: 'You have all the tools you need.'),
  TarotCard(
      name: 'The High Priestess',
      asset: 'assets/tarot/high_priestess.webp',
      keywords: 'intuition, mystery, inner knowledge',
      uprightMeaning: 'Trust your inner voice.'),
  TarotCard(
      name: 'The Empress',
      asset: 'assets/tarot/empress.webp',
      keywords: 'fertility, abundance, nature',
      uprightMeaning: 'Creativity and abundance flow through you.'),
  TarotCard(
      name: 'The Emperor',
      asset: 'assets/tarot/emperor.webp',
      keywords: 'authority, structure, stability',
      uprightMeaning: 'Build with discipline.'),
  TarotCard(
      name: 'The Hierophant',
      asset: 'assets/tarot/hierophant.webp',
      keywords: 'tradition, spiritual wisdom, guidance',
      uprightMeaning: 'Seek wisdom from tradition.'),
  TarotCard(
      name: 'The Lovers',
      asset: 'assets/tarot/lovers.webp',
      keywords: 'love, harmony, alignment',
      uprightMeaning: 'Follow what your heart knows.'),
  TarotCard(
      name: 'The Chariot',
      asset: 'assets/tarot/chariot.webp',
      keywords: 'determination, control, victory',
      uprightMeaning: 'Victory through willpower.'),
  TarotCard(
      name: 'Strength',
      asset: 'assets/tarot/strength.webp',
      keywords: 'courage, patience, inner strength',
      uprightMeaning: 'Your quiet strength will outlast any storm.'),
  TarotCard(
      name: 'The Hermit',
      asset: 'assets/tarot/hermit.webp',
      keywords: 'solitude, introspection, guidance',
      uprightMeaning: 'The light you seek is already within you.'),
  TarotCard(
      name: 'Wheel of Fortune',
      asset: 'assets/tarot/wheel_of_fortune.webp',
      keywords: 'cycles, fate, turning point',
      uprightMeaning: 'A pivotal moment of change is here.'),
  TarotCard(
      name: 'Justice',
      asset: 'assets/tarot/justice.webp',
      keywords: 'truth, fairness, law',
      uprightMeaning: 'Truth and balance will prevail.'),
  TarotCard(
      name: 'The Hanged Man',
      asset: 'assets/tarot/hanged_man.webp',
      keywords: 'surrender, pause, new perspective',
      uprightMeaning: 'Surrender reveals what struggle hides.'),
  TarotCard(
      name: 'Death',
      asset: 'assets/tarot/death.webp',
      keywords: 'transformation, endings, transition',
      uprightMeaning: 'What ends now makes space for what must come.'),
  TarotCard(
      name: 'Temperance',
      asset: 'assets/tarot/temperance.webp',
      keywords: 'balance, patience, moderation',
      uprightMeaning: 'Balance is not stillness — it is movement.'),
  TarotCard(
      name: 'The Devil',
      asset: 'assets/tarot/devil.webp',
      keywords: 'bondage, materialism, shadow',
      uprightMeaning: 'Examine what chains you hold yourself.'),
  TarotCard(
      name: 'The Tower',
      asset: 'assets/tarot/tower.webp',
      keywords: 'upheaval, revelation, sudden change',
      uprightMeaning: 'Liberation through chaos.'),
  TarotCard(
      name: 'The Star',
      asset: 'assets/tarot/star.webp',
      keywords: 'hope, renewal, inspiration',
      uprightMeaning: 'Hope and healing are flowing in.'),
  TarotCard(
      name: 'The Moon',
      asset: 'assets/tarot/moon.webp',
      keywords: 'illusion, fear, the subconscious',
      uprightMeaning: 'Trust your instincts through the fog.'),
  TarotCard(
      name: 'The Sun',
      asset: 'assets/tarot/sun.webp',
      keywords: 'joy, success, vitality',
      uprightMeaning: 'Step into the light.'),
  TarotCard(
      name: 'Judgement',
      asset: 'assets/tarot/judgement.webp',
      keywords: 'reflection, reckoning, awakening',
      uprightMeaning: 'Answer the call without hesitation.'),
  TarotCard(
      name: 'The World',
      asset: 'assets/tarot/world.webp',
      keywords: 'completion, integration, wholeness',
      uprightMeaning: 'Celebrate completion before the next cycle begins.'),

  // WANDS
  TarotCard(
      name: 'Ace of Wands',
      asset: 'assets/tarot/wands_ace.webp',
      keywords: 'new beginning, creative spark, passion',
      uprightMeaning: 'A spark of creative energy arrives.'),
  TarotCard(
      name: 'Two of Wands',
      asset: 'assets/tarot/wands_02.webp',
      keywords: 'planning, options, future vision',
      uprightMeaning: 'Weigh your options before moving forward.'),
  TarotCard(
      name: 'Three of Wands',
      asset: 'assets/tarot/wands_03.webp',
      keywords: 'waiting, expansion, foresight',
      uprightMeaning: 'Your ship is coming in.'),
  TarotCard(
      name: 'Four of Wands',
      asset: 'assets/tarot/wands_04.webp',
      keywords: 'celebration, marriage, reunion, foundation',
      uprightMeaning: 'A joyful foundation is being built.'),
  TarotCard(
      name: 'Five of Wands',
      asset: 'assets/tarot/wands_05.webp',
      keywords: 'conflict, chaos, competition',
      uprightMeaning: 'Conflict that leads to change.'),
  TarotCard(
      name: 'Six of Wands',
      asset: 'assets/tarot/wands_06.webp',
      keywords: 'victory, recognition, success',
      uprightMeaning: 'Victory is yours — own it.'),
  TarotCard(
      name: 'Seven of Wands',
      asset: 'assets/tarot/wands_07.webp',
      keywords: 'challenge, defense, perseverance',
      uprightMeaning: 'Stand your ground despite obstacles.'),
  TarotCard(
      name: 'Eight of Wands',
      asset: 'assets/tarot/wands_08.webp',
      keywords: 'swift action, communication, movement',
      uprightMeaning: 'Things are moving very quickly now.'),
  TarotCard(
      name: 'Nine of Wands',
      asset: 'assets/tarot/wands_09.webp',
      keywords: 'resilience, almost there, caution',
      uprightMeaning: 'You are almost at the finish line.'),
  TarotCard(
      name: 'Ten of Wands',
      asset: 'assets/tarot/wands_10.webp',
      keywords: 'burden, overload, responsibility',
      uprightMeaning: 'Put down what no longer serves you.'),
  TarotCard(
      name: 'Page of Wands',
      asset: 'assets/tarot/wands_page.webp',
      keywords: 'enthusiasm, creative idea, spark',
      uprightMeaning: 'A creative idea is ready to take flight.'),
  TarotCard(
      name: 'Knight of Wands',
      asset: 'assets/tarot/wands_knight.webp',
      keywords: 'fast, passionate, impulsive',
      uprightMeaning: 'Passionate energy arriving fast.'),
  TarotCard(
      name: 'Queen of Wands',
      asset: 'assets/tarot/wands_queen.webp',
      keywords: 'magnetic, confident, passionate',
      uprightMeaning: 'Stand in your magnetic power.'),
  TarotCard(
      name: 'King of Wands',
      asset: 'assets/tarot/wands_king.webp',
      keywords: 'vision, leadership, fire energy',
      uprightMeaning: 'Lead with passion and vision.'),

  // CUPS
  TarotCard(
      name: 'Ace of Cups',
      asset: 'assets/tarot/cups_ace.webp',
      keywords: 'new love, emotional beginning, overflow',
      uprightMeaning: 'Your cup overflows with love.'),
  TarotCard(
      name: 'Two of Cups',
      asset: 'assets/tarot/cups_02.webp',
      keywords: 'mutual love, partnership, harmony',
      uprightMeaning: 'Equal and mutual connection.'),
  TarotCard(
      name: 'Three of Cups',
      asset: 'assets/tarot/cups_03.webp',
      keywords: 'celebration, reunion, friendship',
      uprightMeaning: 'A joyful reunion or gathering.'),
  TarotCard(
      name: 'Four of Cups',
      asset: 'assets/tarot/cups_04.webp',
      keywords: 'contemplation, apathy, withdrawal',
      uprightMeaning: 'Look up — an offer is being made.'),
  TarotCard(
      name: 'Five of Cups',
      asset: 'assets/tarot/cups_05.webp',
      keywords: 'grief, loss, focusing on negatives',
      uprightMeaning: 'Two cups still stand — look at them.'),
  TarotCard(
      name: 'Six of Cups',
      asset: 'assets/tarot/cups_06.webp',
      keywords: 'nostalgia, soulmate, past, innocence',
      uprightMeaning: 'A soulful connection from the past.'),
  TarotCard(
      name: 'Seven of Cups',
      asset: 'assets/tarot/cups_07.webp',
      keywords: 'illusion, fantasy, choices, dreaming',
      uprightMeaning: 'Remove the rose-tinted glasses.'),
  TarotCard(
      name: 'Eight of Cups',
      asset: 'assets/tarot/cups_08.webp',
      keywords: 'walking away, self-discovery, moving on',
      uprightMeaning: 'Walk away to find yourself.'),
  TarotCard(
      name: 'Nine of Cups',
      asset: 'assets/tarot/cups_09.webp',
      keywords: 'wish fulfilled, contentment, satisfaction',
      uprightMeaning: 'Your wish is coming true.'),
  TarotCard(
      name: 'Ten of Cups',
      asset: 'assets/tarot/cups_10.webp',
      keywords: 'emotional fulfillment, family, happiness',
      uprightMeaning: 'Complete emotional happiness.'),
  TarotCard(
      name: 'Page of Cups',
      asset: 'assets/tarot/cups_page.webp',
      keywords: 'intuitive, dreamy, emotional message',
      uprightMeaning: 'An emotional offer arrives.'),
  TarotCard(
      name: 'Knight of Cups',
      asset: 'assets/tarot/cups_knight.webp',
      keywords: 'romantic, coming towards you, offer',
      uprightMeaning: 'Love is riding towards you.'),
  TarotCard(
      name: 'Queen of Cups',
      asset: 'assets/tarot/cups_queen.webp',
      keywords: 'empathic, intuitive, emotionally mature',
      uprightMeaning: 'Lead with emotional wisdom.'),
  TarotCard(
      name: 'King of Cups',
      asset: 'assets/tarot/cups_king.webp',
      keywords: 'emotionally balanced, supportive, mature',
      uprightMeaning: 'Emotional mastery and support.'),

  // SWORDS
  TarotCard(
      name: 'Ace of Swords',
      asset: 'assets/tarot/swords_ace.webp',
      keywords: 'clarity, truth, breakthrough',
      uprightMeaning: 'Cut through illusion to the truth.'),
  TarotCard(
      name: 'Two of Swords',
      asset: 'assets/tarot/swords_02.webp',
      keywords: 'indecision, stalemate, confusion',
      uprightMeaning: 'Remove the blindfold and choose.'),
  TarotCard(
      name: 'Three of Swords',
      asset: 'assets/tarot/swords_03.webp',
      keywords: 'heartbreak, grief, betrayal',
      uprightMeaning: 'Pain that leads to healing.'),
  TarotCard(
      name: 'Four of Swords',
      asset: 'assets/tarot/swords_04.webp',
      keywords: 'rest, recovery, retreat',
      uprightMeaning: 'Rest is not weakness — it is wisdom.'),
  TarotCard(
      name: 'Five of Swords',
      asset: 'assets/tarot/swords_05.webp',
      keywords: 'conflict, defeat, walking away',
      uprightMeaning: 'Walk away from battles that drain you.'),
  TarotCard(
      name: 'Six of Swords',
      asset: 'assets/tarot/swords_06.webp',
      keywords: 'transition, moving on, calmer waters',
      uprightMeaning: 'Calmer waters lie ahead.'),
  TarotCard(
      name: 'Seven of Swords',
      asset: 'assets/tarot/swords_07.webp',
      keywords: 'deceit, betrayal, sneaky behavior',
      uprightMeaning: 'Not everything is as it appears.'),
  TarotCard(
      name: 'Eight of Swords',
      asset: 'assets/tarot/swords_08.webp',
      keywords: 'trapped, restricted, self-imposed prison',
      uprightMeaning: 'The chains are in your mind.'),
  TarotCard(
      name: 'Nine of Swords',
      asset: 'assets/tarot/swords_09.webp',
      keywords: 'anxiety, nightmares, overthinking',
      uprightMeaning: 'The fear is worse than the reality.'),
  TarotCard(
      name: 'Ten of Swords',
      asset: 'assets/tarot/swords_10.webp',
      keywords: 'painful ending, betrayal, rock bottom',
      uprightMeaning: 'The cycle is complete — now rise.'),
  TarotCard(
      name: 'Page of Swords',
      asset: 'assets/tarot/swords_page.webp',
      keywords: 'curious, communicative, new ideas',
      uprightMeaning: 'A message or news is arriving.'),
  TarotCard(
      name: 'Knight of Swords',
      asset: 'assets/tarot/swords_knight.webp',
      keywords: 'fast, direct, charging ahead',
      uprightMeaning: 'Swift action cuts through obstacles.'),
  TarotCard(
      name: 'Queen of Swords',
      asset: 'assets/tarot/swords_queen.webp',
      keywords: 'sharp mind, direct, clear boundaries',
      uprightMeaning: 'Speak your truth clearly.'),
  TarotCard(
      name: 'King of Swords',
      asset: 'assets/tarot/swords_king.webp',
      keywords: 'authority, intellect, clear thinking',
      uprightMeaning: 'Lead with clarity and truth.'),

  // PENTACLES
  TarotCard(
      name: 'Ace of Pentacles',
      asset: 'assets/tarot/pentacles_ace.webp',
      keywords: 'new financial opportunity, abundance',
      uprightMeaning: 'A new material opportunity arrives.'),
  TarotCard(
      name: 'Two of Pentacles',
      asset: 'assets/tarot/pentacles_02.webp',
      keywords: 'juggling, balance, adaptability',
      uprightMeaning: 'Balance multiple priorities with grace.'),
  TarotCard(
      name: 'Three of Pentacles',
      asset: 'assets/tarot/pentacles_03.webp',
      keywords: 'teamwork, skill, collaboration',
      uprightMeaning: 'Collaboration leads to mastery.'),
  TarotCard(
      name: 'Four of Pentacles',
      asset: 'assets/tarot/pentacles_04.webp',
      keywords: 'holding on, security, possessiveness',
      uprightMeaning: 'Release the grip — abundance flows.'),
  TarotCard(
      name: 'Five of Pentacles',
      asset: 'assets/tarot/pentacles_05.webp',
      keywords: 'hardship, isolation, financial struggle',
      uprightMeaning: 'Help is closer than it appears.'),
  TarotCard(
      name: 'Six of Pentacles',
      asset: 'assets/tarot/pentacles_06.webp',
      keywords: 'generosity, give and take, balance',
      uprightMeaning: 'Give and receive in equal measure.'),
  TarotCard(
      name: 'Seven of Pentacles',
      asset: 'assets/tarot/pentacles_07.webp',
      keywords: 'patience, investment, long-term vision',
      uprightMeaning: 'The harvest is coming — be patient.'),
  TarotCard(
      name: 'Eight of Pentacles',
      asset: 'assets/tarot/pentacles_08.webp',
      keywords: 'hard work, mastery, dedication',
      uprightMeaning: 'Mastery comes through consistent effort.'),
  TarotCard(
      name: 'Nine of Pentacles',
      asset: 'assets/tarot/pentacles_09.webp',
      keywords: 'abundance, independence, self-sufficiency',
      uprightMeaning: 'You have everything you need within.'),
  TarotCard(
      name: 'Ten of Pentacles',
      asset: 'assets/tarot/pentacles_10.webp',
      keywords: 'legacy, family wealth, complete abundance',
      uprightMeaning: 'Complete abundance in all areas of life.'),
  TarotCard(
      name: 'Page of Pentacles',
      asset: 'assets/tarot/pentacles_page.webp',
      keywords: 'opportunity, study, new skills',
      uprightMeaning: 'A new opportunity for growth arrives.'),
  TarotCard(
      name: 'Knight of Pentacles',
      asset: 'assets/tarot/pentacles_knight.webp',
      keywords: 'slow, reliable, methodical, long-term',
      uprightMeaning: 'Slow and steady wins the race.'),
  TarotCard(
      name: 'Queen of Pentacles',
      asset: 'assets/tarot/pentacles_queen.webp',
      keywords: 'nurturing, grounded, practical, abundant',
      uprightMeaning: 'Nurture your resources and they will grow.'),
  TarotCard(
      name: 'King of Pentacles',
      asset: 'assets/tarot/pentacles_king.webp',
      keywords: 'wealth, stability, provider, security',
      uprightMeaning: 'Steady mastery of the material world.'),
];

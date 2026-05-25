const englishAiResponseLanguage = 'english';
const hinglishAiResponseLanguage = 'hinglish';

const aiResponseLanguages = <String>[
  englishAiResponseLanguage,
  hinglishAiResponseLanguage,
];

String normalizeAiResponseLanguage(dynamic value) {
  return value == hinglishAiResponseLanguage
      ? hinglishAiResponseLanguage
      : englishAiResponseLanguage;
}

String aiResponseLanguageLabel(String value) {
  return switch (normalizeAiResponseLanguage(value)) {
    hinglishAiResponseLanguage => 'Hinglish',
    _ => 'English',
  };
}

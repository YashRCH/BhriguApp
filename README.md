# BHR1GU

BHR1GU is a Flutter app for AI-powered astrology and mystical wellness. It combines Firebase authentication, personalized birth-profile onboarding, Bhrigu-style chat guidance, daily horoscope generation, tarot readings, geomancy, compatibility matching, and shareable reading cards.

## App Areas

- `lib/screens` contains the main user flows: login, onboarding, home, chat, tarot, geomancy, partner match, cosmic blueprint, and profile.
- `lib/services` contains Firebase, AI, chart, horoscope, tarot, geomancy, and compatibility logic.
- `lib/widgets` contains reusable visual components and share-card surfaces.
- `functions` contains Firebase Cloud Functions that call Groq, Gemini, and Google Places through server-side secrets.

## Local Development

```bash
flutter pub get
flutter test
flutter analyze
```

Firebase configuration is generated in `lib/firebase_options.dart`. Cloud Function secrets should stay in Firebase Secret Manager and must not be committed as local environment files.

## Production Release Checklist

- Configure Firebase Secret Manager values for `GROQ_API_KEY`, `GEMINI_API_KEY`, and `GOOGLE_PLACES_API_KEY`.
- Create `android/key.properties` from `android/key.properties.example` and keep the real keystore outside version control.
- Use a production Android package id and matching Firebase app before store release. The current Firebase Android config is tied to `com.example.astrology_guru_app`.
- Run `flutter analyze --no-pub`, `flutter test test/widget_test.dart --no-pub`, and `node --check functions/index.js` before every release.
- Build store artifacts from a clean workspace with production Firebase config and release signing available.

## Notes

The app currently prioritizes preserving the existing UI and product flow. Refactors should be small, feature-scoped, and covered by tests where possible.

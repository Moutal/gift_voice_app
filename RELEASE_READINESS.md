# Event Gift Keeper Release Readiness

## Current Status

The app is close to testing-ready, but not fully publish-ready yet.

What is already in place:
- Firebase sign-in flow
- Firestore-backed gift entries
- AI voice parsing flow
- Crashlytics wiring
- export to CSV / PDF
- settings, delete entry, delete all, currency totals
- Android and iOS microphone permissions

## Remaining Release Blockers

### 1. Secure AI architecture

Current state:
- the Gemini key can still be provided from the client app
- this is acceptable for local testing, but not safe for production release

Required before public launch:
- move Gemini access to a backend
- keep API keys only on the server
- have the mobile app call your backend instead of Gemini directly

### 2. Android release signing

Current state:
- `android/app/build.gradle.kts` still signs `release` with the debug key

Required before Google Play:
- create a release keystore
- add proper release signing config
- build a signed app bundle

### 3. Apple signing and distribution

Required before App Store:
- Apple Developer account
- signing certificate
- App Store Connect app record
- privacy metadata and screenshots

### 4. Store policy and privacy materials

Prepare:
- privacy policy URL
- support email
- app description
- screenshots
- age rating answers
- data safety / privacy nutrition answers

### 5. Real testing pass

Before release, test at minimum:
- sign in
- sign out
- add entry via AI
- add entry manually
- delete one entry
- delete all entries
- export CSV
- export PDF
- Hebrew / Arabic / English flows
- offline / weak network behavior

## Recommended Next Technical Step

1. Move AI to backend
2. Add proper release signing
3. Run a structured QA pass
4. Generate release builds

## Local Test Run

For local testing, you can run with:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

This is still not production-secure. It is only a better testing setup than hardcoding keys into the app bundle.

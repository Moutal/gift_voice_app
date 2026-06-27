# Event Gift Keeper Release Checklist

Last updated: 2026-06-27

## Status Legend

- `[x]` Done or already verified in the repo
- `[ ]` Not done
- `[~]` Partially done / needs review

## P0 - Must Fix Before Internal Testing

### Security

- [x] AI calls go through Firebase Cloud Functions.
- [x] Gemini API key is stored in Firebase Secret Manager.
- [x] API key files are ignored by Git.
- [x] `google-services.json` is not tracked by Git.
- [x] `GoogleService-Info.plist` is not tracked by Git.
- [~] Remove `assets/ai_config.json` from Flutter release assets.
- [ ] Add Firestore rules file to repo.
- [ ] Configure `firebase.json` to deploy Firestore rules.
- [ ] Verify users can only read/write their own gift entries.
- [ ] Add rules tests or documented rules test cases.
- [ ] Enable Firebase App Check for Android.
- [ ] Enable Firebase App Check for iOS.
- [ ] Enforce App Check for callable Functions after testing.
- [ ] Enforce App Check for Firestore after testing.
- [ ] Confirm Functions require authenticated users.
- [ ] Rate-limit or abuse-protect AI endpoints.
- [ ] Review Crashlytics data for sensitive payloads.
- [ ] Confirm transcripts/audio are not stored unless intended.
- [ ] Remove stale references to local API key setup from docs.
- [ ] Rotate Gemini key before public release.

### Android Release

- [ ] Create release keystore.
- [ ] Add `android/key.properties` locally.
- [ ] Configure release signing in `android/app/build.gradle.kts`.
- [ ] Stop signing release builds with debug key.
- [ ] Enable code shrinking for release.
- [ ] Add or verify Proguard/R8 rules.
- [ ] Build signed AAB with `flutter build appbundle --release`.
- [ ] Install and smoke-test release build.
- [ ] Verify app name in launcher.
- [ ] Verify package name is final: `com.eventgiftkeeper.app`.

### Stability

- [x] `flutter analyze` passes.
- [x] `flutter test` passes.
- [x] Cloud Functions deploy successfully.
- [~] Crashlytics is wired.
- [ ] Verify Crashlytics receives a test non-fatal in release mode.
- [ ] Test cold start on real Android device.
- [ ] Test sign-in on real Android device.
- [ ] Test AI recording on real Android device.
- [ ] Test weak network behavior.
- [ ] Test no-internet behavior.
- [ ] Test app after force close and reopen.
- [ ] Test app after logout/login.

## P1 - UX Polish

### Brand

- [ ] Decide final primary color.
- [ ] Reduce scattered one-off colors in `lib/main.dart`.
- [ ] Define a small color token set in one place.
- [ ] Decide final app name for stores.
- [ ] Create final logo mark.
- [ ] Create Android launcher icon.
- [ ] Create iOS app icon.
- [ ] Create adaptive Android foreground/background icon.
- [ ] Replace default desktop/web icons if shipping those targets.

### Splash Screen

- [ ] Design splash background.
- [ ] Add centered logo to Android launch screen.
- [ ] Add centered logo to iOS launch screen.
- [ ] Add small in-app loading state after native splash.
- [ ] Ensure splash-to-app transition is under 2 seconds on target devices.
- [ ] Avoid blank white screen during Firebase init.

### Typography

- [~] App uses a single `fontFamily`.
- [ ] Choose production font with Hebrew/Arabic/English support.
- [ ] Add font files or use robust platform fonts.
- [ ] Verify Arabic shaping and RTL readability.
- [ ] Verify Hebrew punctuation and numbers.
- [ ] Verify dynamic text scaling.
- [ ] Remove overly small text on compact devices.

### Animations

- [ ] Add fade transition after sign-in state resolves.
- [ ] Add subtle scale animation to record button.
- [ ] Add slide/fade animation when new gift card appears.
- [ ] Add loading animation during AI processing.
- [ ] Add small success animation after AI adds entries.
- [ ] Add error animation for failed recognition.
- [ ] Keep all animations under 250ms unless loading.
- [ ] Respect reduced-motion accessibility where possible.

### Main Flow UX

- [x] Missing name no longer creates `Unknown` entries.
- [x] One recording can create multiple gift cards.
- [x] One person can have multiple money items in one card.
- [x] Monetary totals are grouped by currency.
- [~] Icons adapt to money or gift type.
- [ ] Add clearer “recording” visual state.
- [ ] Add clearer “AI processing” visual state.
- [ ] Make retry action obvious after recognition failure.
- [ ] Add undo after deleting an entry.
- [ ] Add confirmation before deleting all entries.
- [ ] Review manual entry flow end to end.
- [ ] Make empty state more polished.
- [ ] Add first-use onboarding or tiny guidance.

### Localization

- [x] AI prompt supports Hebrew, Arabic, and English.
- [~] UI supports many locales through Flutter material locales.
- [ ] Translate app UI strings to Hebrew.
- [ ] Translate app UI strings to Arabic.
- [ ] Translate app UI strings to English.
- [x] Make app language choice explicit.
- [ ] Verify RTL layout in Hebrew.
- [ ] Verify RTL layout in Arabic.
- [ ] Verify mixed currency formatting in RTL.

## P1 - Performance

- [ ] Measure cold start on Android debug.
- [ ] Measure cold start on Android release.
- [ ] Target release cold start under 2 seconds.
- [ ] Measure AI request latency from tap-stop to result.
- [ ] Target AI result under 10 seconds for normal recordings.
- [ ] Add timeout-specific user message.
- [ ] Compress audio before upload if needed.
- [ ] Keep recordings short by default.
- [ ] Verify no UI jank while recording.
- [ ] Verify no UI jank while generating PDF.
- [ ] Move heavy export work off UI thread if needed.
- [ ] Remove unused assets from release bundle.
- [ ] Remove unused backup source from release consideration.
- [ ] Review dependency size.

## P1 - Analytics

- [ ] Add `firebase_analytics` dependency.
- [ ] Track app open.
- [ ] Track sign-in success.
- [ ] Track sign-in failure.
- [ ] Track event/list created if event concept is added.
- [ ] Track manual gift creation.
- [ ] Track recording start.
- [ ] Track recording stop.
- [ ] Track AI success.
- [ ] Track AI failure.
- [ ] Track multi-person AI result.
- [ ] Track missing-name recognition error.
- [ ] Track PDF export.
- [ ] Track CSV export.
- [ ] Track share action.
- [ ] Track delete entry.
- [ ] Track delete all.
- [ ] Add privacy-safe event names only.
- [ ] Do not log names, transcripts, or gift text in analytics.

## P2 - Google Play Readiness

- [ ] Google Play developer account ready.
- [ ] App listing created.
- [ ] Final app icon uploaded.
- [ ] Feature graphic created.
- [ ] Phone screenshots created.
- [ ] Tablet screenshots created if tablet support is claimed.
- [ ] Short description written.
- [ ] Full description written.
- [ ] Privacy policy URL ready.
- [ ] Support email ready.
- [ ] Data Safety answers completed.
- [ ] Content rating completed.
- [ ] Target audience selected.
- [ ] Internal testing track created.
- [ ] Upload signed AAB to Internal Testing.
- [ ] Add 20 testers.
- [ ] Collect feedback.
- [ ] Fix P0/P1 bugs from first 20 testers.
- [ ] Expand to 100 testers.
- [ ] Expand to 500 testers.
- [ ] Prepare production rollout plan.

## P2 - App Store Readiness

- [ ] Apple Developer account ready.
- [ ] Bundle identifier final.
- [ ] Signing configured.
- [ ] App Store Connect app record created.
- [ ] iPhone screenshots created.
- [ ] iPad screenshots created if supported.
- [ ] App icon verified at 1024x1024.
- [ ] Subtitle written.
- [ ] Promotional text written.
- [ ] Description written.
- [ ] Keywords written.
- [ ] Support URL ready.
- [ ] Marketing URL ready if available.
- [ ] Privacy policy URL ready.
- [ ] App Privacy answers completed.
- [ ] TestFlight internal group created.
- [ ] TestFlight external group prepared.
- [ ] Export compliance answered.

## P2 - Marketing

- [ ] One-page landing site.
- [ ] Product screenshots.
- [ ] 30-second demo video.
- [ ] Hebrew demo video.
- [ ] Arabic demo video.
- [ ] English demo video.
- [ ] Facebook page.
- [ ] Instagram account.
- [ ] TikTok account.
- [ ] Waitlist form.
- [ ] Support inbox.
- [ ] Basic FAQ.
- [ ] Launch announcement copy.

## P2 - Monetization Planning

- [x] Decide free tier: 2 events, 50 gifts, basic AI.
- [x] Decide premium features: unlimited events, unlimited gifts, unlimited AI, full backup, designed PDF, advanced export, family sharing.
- [x] Decide starter Premium price: $1.99/month.
- [x] Add local Freemium gates for gift count, AI usage, and advanced export.
- [~] Decide AI credit model: currently 20 free AI uses/month; revisit after beta data.
- [ ] Decide wedding/event plan.
- [ ] Decide family plan.
- [ ] Decide business plan.
- [ ] Decide whether monetization starts at launch or after beta.
- [~] Draft paywall copy.
- [ ] Draft pricing experiment.
- [ ] Review Apple/Google payment policy.

## First 7-Day Execution Plan

1. Remove release blockers around secrets, Firestore rules, signing, and App Check.
2. Polish the main recording flow and loading/error states.
3. Create app icon and splash assets.
4. Add analytics without collecting personal content.
5. Build Android release AAB and run a release smoke test.
6. Create Google Play Internal Testing listing.
7. Invite first 20 real testers and track every issue.

# Security & Setup Guide

## ⚠️ IMPORTANT: API Keys & Secrets

### DO NOT commit sensitive files:
- `assets/ai_config.json` ❌ **Contains API keys**
- `android/local.properties` ❌ **Contains local paths**
- `android/app/google-services.json` ❌ (Use CI/CD or local setup)
- `ios/Runner/GoogleService-Info.plist` ❌ (Use CI/CD or local setup)

These files are in `.gitignore` and will not be tracked.

---

## 🔧 Local Development Setup

### 1. Prerequisites
```bash
# Install Flutter
curl -fsSL https://raw.githubusercontent.com/flutter/flutter/main/bin/flutter_install.sh | bash

# Install Firebase CLI
npm install -g firebase-tools

# Verify installations
flutter doctor
firebase --version
```

### 2. Clone & Setup Repository
```bash
git clone <your-repo-url>
cd gift_voice_app

# Get Flutter dependencies
flutter pub get

# Get Firebase Functions dependencies
cd functions
npm install
cd ..
```

### 3. Configure Firebase (Local Development)

**Download google-services.json from Firebase Console:**
```bash
# Go to: https://console.firebase.google.com/
# Select project: gift-tracker-98088
# Project Settings → Download google-services.json
# Place at: android/app/google-services.json

# For iOS, download GoogleService-Info.plist
# Place at: ios/Runner/GoogleService-Info.plist
```

### 4. Configure Local Properties
```bash
# Create android/local.properties (this is gitignored)
cat > android/local.properties << EOF
sdk.dir=$ANDROID_SDK_ROOT
flutter.sdk=$(which flutter | xargs dirname | xargs dirname)
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
EOF
```

### 5. Set Up API Keys (Local Only)

**DO NOT create `assets/ai_config.json` locally. Instead, use Firebase Secrets:**

```bash
# Authenticate with Firebase
firebase login

# Set secrets (replace with actual keys from:
# https://console.groq.com/keys
# https://aistudio.google.com/app/apikey)
firebase functions:secrets:set GROQ_API_KEY
firebase functions:secrets:set GEMINI_API_KEY

# Verify
firebase functions:secrets:list
```

### 6. Run Locally
```bash
# Debug mode
flutter run -d <device-id>

# Or use connected device
flutter devices
flutter run
```

---

## 🚀 CI/CD & Deployment (GitHub Actions)

### 1. Set GitHub Secrets

Go to your GitHub repository:
```
Settings → Secrets and variables → Actions → New repository secret
```

Add these secrets:
- `FIREBASE_TOKEN`: Run `firebase login:ci` and copy the token
- `GEMINI_API_KEY`: Your Gemini API key (from https://aistudio.google.com/app/apikey)
- `GROQ_API_KEY`: Your Groq API key (from https://console.groq.com/keys)

### 2. GitHub Actions Workflow

File: `.github/workflows/deploy.yml` (already created)

**What it does:**
- ✅ Builds Flutter APK and App Bundle on every push
- ✅ Runs tests
- ✅ Lints code with Flutter analyzer
- ✅ Deploys Cloud Functions to production (main branch only)
- ✅ Uses GitHub Secrets for sensitive data (no hardcoded keys)

### 3. Deploy from CI/CD
```bash
# Create a release build
git tag v1.0.0
git push origin v1.0.0

# Or just push to main branch
git push origin main
# GitHub Actions automatically builds and deploys
```

---

## 🔐 Firebase Cloud Functions Security

### API Keys are stored as secrets:
```javascript
// functions/index.js
exports.aiTranscribeAndParse = onCall(
  {
    secrets: ["GEMINI_API_KEY"], // ✅ Secure
  },
  async (request) => {
    const apiKey = process.env.GEMINI_API_KEY;
    // Use apiKey securely
  }
);
```

### To update secrets in production:
```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

---

## 🛡️ Security Best Practices

### ✅ DO:
- Store all API keys in Firebase Secrets or GitHub Secrets
- Use environment variables, never hardcode values
- Rotate keys regularly
- Use Firebase Security Rules for Firestore access
- Enable Firebase Authentication
- Keep dependencies updated

### ❌ DON'T:
- Commit `.env*` files
- Hardcode API keys anywhere in code
- Share Firebase Admin SDK files publicly
- Commit `google-services.json` or `GoogleService-Info.plist`
- Use the same keys across environments (dev/staging/prod)

---

## 📝 Local Development Checklist

- [ ] Clone repository
- [ ] Download `google-services.json` to `android/app/`
- [ ] Download `GoogleService-Info.plist` to `ios/Runner/`
- [ ] Create `android/local.properties` with local SDK paths
- [ ] Run `firebase functions:secrets:set` for API keys
- [ ] Run `flutter pub get`
- [ ] Run `cd functions && npm install && cd ..`
- [ ] Run `flutter run` to test on device
- [ ] Verify `.gitignore` prevents accidental commits

---

## 🚨 If Secrets Are Exposed

**Immediately:**
1. Rotate all API keys
2. Run: `git filter-branch --tree-filter 'rm -f assets/ai_config.json' -f HEAD`
3. Force push: `git push origin --force-with-lease`
4. Update GitHub Secrets with new keys
5. Redeploy: `firebase deploy --only functions`

---

## 📚 Additional Resources

- [Firebase Security Rules](https://firebase.google.com/docs/firestore/security/start)
- [Flutter Security Guide](https://flutter.dev/docs/security)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Firebase Functions Environment Variables](https://firebase.google.com/docs/functions/config/set-up-and-configure)

---

**Last Updated:** June 20, 2026  
**Status:** Secure ✅

# 🚀 Setup Instructions - Gift Voice Tracker

## Quick Start (5 minutes)

### For Contributors/Developers:

```bash
# 1. Clone repository
git clone https://github.com/your-username/gift_voice_app.git
cd gift_voice_app

# 2. Get Flutter dependencies
flutter pub get

# 3. Get Functions dependencies
cd functions && npm install && cd ..

# 4. Download Firebase config files
# - Visit: https://console.firebase.google.com/project/gift-tracker-98088/settings/general
# - Download google-services.json → android/app/
# - Download GoogleService-Info.plist → ios/Runner/

# 5. Create local.properties (machine-specific, not tracked)
cat > android/local.properties << EOF
sdk.dir=$ANDROID_SDK_ROOT
flutter.sdk=$(which flutter | xargs dirname | xargs dirname)
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
EOF

# 6. Set up API keys (using Firebase Secrets, not local files)
firebase login
firebase functions:secrets:set GROQ_API_KEY    # Will prompt for value
firebase functions:secrets:set GEMINI_API_KEY  # Will prompt for value

# 7. Run the app
flutter devices                    # List available devices
flutter run -d <device-id>         # Or just: flutter run
```

---

## Detailed Setup Steps

### Prerequisites

**Mac/Linux:**
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Flutter
brew install flutter

# Install Node.js (for Firebase Functions)
brew install node

# Install Firebase CLI
npm install -g firebase-tools

# Verify everything
flutter doctor
firebase --version
node --version
```

**Windows (PowerShell as Admin):**
```powershell
# Install Chocolatey (if not installed)
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install dependencies
choco install flutter node googlechrome

# Install Firebase CLI
npm install -g firebase-tools

# Verify
flutter doctor
firebase --version
```

---

### Clone the Repository

```bash
git clone https://github.com/your-username/gift_voice_app.git
cd gift_voice_app
```

---

### Install Dependencies

```bash
# Flutter dependencies
flutter pub get

# Firebase Functions dependencies
cd functions
npm install
cd ..

# iOS (macOS/iOS only)
cd ios
pod install
cd ..
```

---

### Firebase Configuration

#### Step 1: Get Firebase Config Files

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **gift-tracker-98088**
3. Go to **Project Settings** → **Your apps**

**For Android:**
- Click Android app → Download `google-services.json`
- Save to: `android/app/google-services.json`

**For iOS:**
- Click iOS app → Download `GoogleService-Info.plist`
- Save to: `ios/Runner/GoogleService-Info.plist`

⚠️ **These files are in `.gitignore` and won't be tracked. Each developer needs their own copy.**

#### Step 2: Create Local Properties

```bash
# This file is machine-specific and .gitignored
cat > android/local.properties << 'EOF'
sdk.dir=/path/to/android/sdk
flutter.sdk=/path/to/flutter
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
EOF
```

**Find your SDK paths:**
```bash
# Android SDK
echo $ANDROID_SDK_ROOT
# Or: $ANDROID_HOME

# Flutter
which flutter
```

---

### API Keys Setup (Firebase Secrets)

**⚠️ NEVER create `assets/ai_config.json` locally!**

Instead, use Firebase Cloud Functions Secrets:

```bash
# Log in to Firebase
firebase login

# Set API keys (you'll be prompted to enter each value)
firebase functions:secrets:set GROQ_API_KEY
# Enter your key from: https://console.groq.com/keys

firebase functions:secrets:set GEMINI_API_KEY
# Enter your key from: https://aistudio.google.com/app/apikey

# Verify secrets are set
firebase functions:secrets:list
```

**To get API keys:**
1. **Groq API Key**: https://console.groq.com/keys
2. **Gemini API Key**: https://aistudio.google.com/app/apikey

---

### Run on Device/Emulator

#### Android:

```bash
# List available Android devices/emulators
flutter devices

# Run on specific device
flutter run -d <device-id>

# Or just use connected device
flutter run
```

**To use emulator:**
```bash
# Start Android emulator
emulator -avd <emulator-name>

# Or from Android Studio: Device Manager
```

#### iOS:

```bash
# List connected iOS devices
flutter devices

# Run on iOS device
flutter run -d <device-id>

# Or run on simulator
open -a Simulator
flutter run
```

**To create iOS simulator:**
```bash
xcrun simctl create "iPhone 15" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-17-5
```

---

### Verify Setup

```bash
# Check everything is working
flutter doctor

# Run tests
flutter test

# Build APK (Android)
flutter build apk --debug

# Build for iOS
flutter build ios --debug
```

---

## Troubleshooting

### "Could not find google-services.json"
- Download from Firebase Console
- Save to `android/app/google-services.json`
- File path is case-sensitive

### "Cloud functions secrets not found"
```bash
firebase functions:secrets:list
firebase functions:secrets:set GROQ_API_KEY
firebase functions:secrets:set GEMINI_API_KEY
```

### "Pod install fails" (iOS)
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

### "Flutter doctor shows issues"
```bash
# Accept licenses
flutter config --no-analytics
flutter doctor --android-licenses
```

### "Device not found"
```bash
# Restart ADB (Android)
adb kill-server
adb start-server

# Reconnect devices
flutter devices
```

---

## Development Workflow

### 1. Create a branch
```bash
git checkout -b feature/your-feature-name
```

### 2. Make changes
```bash
# Edit Dart/JavaScript files
# Changes auto-reload with Hot Reload (R key in terminal)
flutter run
```

### 3. Test
```bash
flutter test
flutter analyze
```

### 4. Commit & push
```bash
git add .
git commit -m "feat: description of change"
git push origin feature/your-feature-name
```

### 5. Create Pull Request
- Go to GitHub repository
- Create PR from your branch to `main`
- Wait for CI/CD checks to pass

---

## CI/CD (Automatic Deployment)

**GitHub Actions automatically:**
- ✅ Builds APK/App Bundle on every push
- ✅ Runs tests
- ✅ Lints code
- ✅ Deploys to Firebase on main branch

**No manual deployment needed!**

---

## Important: DO NOT Commit

- ❌ `assets/ai_config.json` (contains API keys)
- ❌ `android/local.properties` (machine-specific)
- ❌ `.env*` files
- ❌ `android/app/google-services.json` (download locally)
- ❌ `ios/Runner/GoogleService-Info.plist` (download locally)

These are in `.gitignore` and will be rejected if you try to commit.

---

## Need Help?

### Resources:
- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Setup Guide](https://firebase.google.com/docs/guides)
- [GitHub Issues](https://github.com/your-username/gift_voice_app/issues)

### Common Issues:
- Check `.gitignore` section above
- See SECURITY.md for secrets management
- Run `flutter doctor` for environment issues

---

**Happy Coding! 🚀**

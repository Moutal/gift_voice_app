# 📋 QUICK REFERENCE: What to Commit vs What NOT to Commit

## ✅ SAFE TO COMMIT

### Source Code
- ✅ `lib/` - All Dart source files
- ✅ `test/` - Test files
- ✅ `functions/` - Cloud Functions (index.js, package.json)
- ✅ `.dart_tool/` - Already excluded (OK)

### Configuration Files (No Secrets)
- ✅ `pubspec.yaml` - Dependencies list
- ✅ `pubspec.lock` - Locked versions (for reproducibility)
- ✅ `firebase.json` - Firebase structure only (no credentials)
- ✅ `.firebaserc` - Firebase project name only (no credentials)
- ✅ `analysis_options.yaml` - Linting config
- ✅ `android/app/build.gradle.kts` - Build config (no secrets)
- ✅ `android/settings.gradle.kts`
- ✅ `android/build.gradle.kts`
- ✅ `ios/Podfile` - Dependency config
- ✅ `ios/Podfile.lock` - iOS locked versions

### Android Project Files
- ✅ `android/app/src/main/AndroidManifest.xml`
- ✅ `android/app/src/main/kotlin/` - App code
- ✅ `android/app/src/main/res/` - Resources
- ✅ `android/gradle/wrapper/gradle-wrapper.properties`
- ✅ `android/gradle/wrapper/gradle-wrapper.jar`

### iOS Project Files
- ✅ `ios/Runner/Assets.xcassets/` - App assets
- ✅ `ios/Runner/Base.lproj/` - Localization
- ✅ `ios/Runner/Info.plist` - No secrets
- ✅ `ios/Runner/*.swift` - Swift code files

### Documentation
- ✅ `README.md` - Project overview
- ✅ `RELEASE_READINESS.md` - Release checklist
- ✅ `SECURITY.md` - Security guidelines
- ✅ `SETUP_INSTRUCTIONS.md` - Setup guide
- ✅ `SECRETS_MIGRATION.md` - API key setup

### GitHub/CI-CD
- ✅ `.github/workflows/deploy.yml` - CI/CD configuration
- ✅ `.github/` directory (workflows, configs)
- ✅ `.gitignore` - Git exclusions
- ✅ `android/.gitignore`
- ✅ `ios/.gitignore`

### Assets
- ✅ `assets/` directory (except `ai_config.json`)
- ✅ Images, fonts, localization files
- ✅ Anything that's not credentials

### Build System
- ✅ `scripts/` - Helper scripts (no credentials)
- ✅ Scripts that don't contain API keys

---

## ❌ MUST NOT COMMIT

### API Keys & Secrets (CRITICAL)
- ❌ `assets/ai_config.json` - **CONTAINS API KEYS**
- ❌ `.env` - Environment files
- ❌ `.env.local`, `.env.*.local`
- ❌ `GROQ_API_KEY` (anywhere)
- ❌ `GEMINI_API_KEY` (anywhere)
- ❌ Any hardcoded API keys

### Firebase Configurations
- ❌ `android/app/google-services.json` - **CONTAINS PROJECT ID & API KEY**
- ❌ `ios/Runner/GoogleService-Info.plist` - **CONTAINS PROJECT ID & API KEY**
- ❌ `service-account.json` - Admin SDK key
- ❌ Firebase Admin credentials

### Machine-Specific Files
- ❌ `android/local.properties` - **CONTAINS LOCAL PATHS**
- ❌ `android/gradle.properties` - If it contains local config
- ❌ Local SDK paths

### Security Files
- ❌ `android/key.properties` - Keystore config
- ❌ `**/*.keystore` - Signing keystore files
- ❌ `**/*.jks` - Java keystore files
- ❌ `*.p12`, `*.pfx` - Certificate files
- ❌ `*.pem` - Private key files
- ❌ `*.key` - Cryptographic keys

### Build Artifacts (Already Excluded)
- ❌ `build/` - All build outputs
- ❌ `android/app/debug/`, `profile/`, `release/`
- ❌ `android/build/`
- ❌ `android/.gradle/`
- ❌ `ios/Pods/` - Dependency cache (huge)
- ❌ `ios/Podfile.lock` - Consider excluding

### IDE Files (Already Excluded)
- ❌ `.idea/` - IntelliJ config
- ❌ `.vscode/` - VS Code workspace config (if private)
- ❌ `*.iml` - IDE project files
- ❌ `.DS_Store` - macOS metadata

### Node Modules (Dependency Cache)
- ❌ `functions/node_modules/` - Dependency cache
- ❌ `.pub-cache/` - Pub cache
- ❌ `ios/Pods/` - CocoaPods cache

### Temporary Files
- ❌ `*.bak`, `*.backup`
- ❌ `*.tmp`, `*.temp`
- ❌ `.swp`, `.swo` - Editor swaps

---

## 🚦 Decision Tree

**Should I commit this file?**

```
├─ Is it a source code file? (.dart, .js, .kt, .swift)
│  └─ YES → ✅ COMMIT
├─ Does it contain API keys or passwords?
│  └─ YES → ❌ DO NOT COMMIT
├─ Is it a config file? (gradle, gradle.properties, AndroidManifest)
│  ├─ Contains secrets? → ❌ DO NOT COMMIT
│  └─ No secrets? → ✅ COMMIT
├─ Is it machine-specific? (local.properties, SDK paths)
│  └─ YES → ❌ DO NOT COMMIT
├─ Is it a build artifact? (build/, .gradle/, Pods/)
│  └─ YES → ❌ DO NOT COMMIT
├─ Is it documentation? (README, SECURITY, SETUP)
│  └─ YES → ✅ COMMIT
├─ Is it Firebase config? (google-services.json, GoogleService-Info.plist)
│  └─ YES → ❌ DO NOT COMMIT (download locally, don't track)
└─ Not sure?
   └─ CHECK .gitignore → Follow its rules
```

---

## 🔍 How to Check Before Committing

### Before git commit:

```bash
# Show what will be committed
git status

# See details of staged changes
git diff --cached

# Run security check script
bash scripts/pre-commit-security-check.sh

# If any secrets found:
# 1. Don't commit
# 2. Run: git reset HEAD <file>
# 3. Add file to .gitignore
# 4. Delete or rotate the key
```

### If you accidentally committed a secret:

```bash
# Remove from Git history (DESTRUCTIVE - use with care)
git filter-branch --tree-filter 'rm -f <file>' -f HEAD

# Force push to remote (only on private repos before public)
git push origin --force-with-lease

# Then rotate the exposed key immediately
```

---

## 📊 Repository Health Check

```bash
# This will show if any secrets might be leaking
git log -p | grep -i "key\|secret\|password\|token" || echo "✅ No obvious secrets found"

# Check what's currently tracked
git ls-files | grep -E "(google-services|GoogleService|local\.properties|\.env|ai_config)" && echo "⚠️  Sensitive files tracked!" || echo "✅ No tracked sensitive files"

# Verify .gitignore is working
git check-ignore -v $(git ls-files) | head -20
```

---

## ✅ Final Checklist Before First Public Push

- [ ] All API keys rotated (old ones deleted)
- [ ] `assets/ai_config.json` deleted from filesystem
- [ ] `.gitignore` files updated (root, android, ios)
- [ ] No `google-services.json` in git
- [ ] No `GoogleService-Info.plist` in git
- [ ] No `local.properties` in git
- [ ] No `.env*` files in git
- [ ] Firebase Secrets configured
- [ ] GitHub Secrets configured
- [ ] `flutter test` passes
- [ ] `flutter analyze` passes
- [ ] GitHub Actions workflow passes
- [ ] Documentation complete (SECURITY.md, SETUP_INSTRUCTIONS.md)

---

**When you see this in git status, you're ready:**

```
On branch main
nothing to commit, working tree clean
```

**You're good to go! 🚀**

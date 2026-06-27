#!/bin/bash

# Pre-commit security check
# Run this before committing to ensure no secrets are being tracked

echo "🔐 Running security checks..."
echo ""

# Check for common secret patterns
echo "✓ Checking for API keys..."
if grep -r "api[_-]?key\|secret\|password" --include="*.json" --include="*.dart" --include="*.js" \
  --exclude-dir=.git --exclude-dir=Pods --exclude-dir=node_modules \
  android/app/src lib functions 2>/dev/null; then
  echo "⚠️  Warning: Possible secrets found in source code"
fi

# Check for Firebase config files
echo ""
echo "✓ Checking for Firebase config files..."
if [ -f "android/app/google-services.json" ] && git ls-files | grep -q "google-services.json"; then
  echo "❌ ERROR: google-services.json is tracked by Git!"
  echo "   Run: git rm --cached android/app/google-services.json"
fi

if [ -f "ios/Runner/GoogleService-Info.plist" ] && git ls-files | grep -q "GoogleService-Info.plist"; then
  echo "❌ ERROR: GoogleService-Info.plist is tracked by Git!"
  echo "   Run: git rm --cached ios/Runner/GoogleService-Info.plist"
fi

# Check for local.properties
echo ""
echo "✓ Checking for local.properties..."
if [ -f "android/local.properties" ] && git ls-files | grep -q "local.properties"; then
  echo "❌ ERROR: local.properties is tracked by Git!"
  echo "   Run: git rm --cached android/local.properties"
fi

# Check for ai_config.json
echo ""
echo "✓ Checking for ai_config.json..."
if [ -f "assets/ai_config.json" ]; then
  echo "❌ ERROR: assets/ai_config.json still exists!"
  echo "   This file contains API keys and should be deleted"
  echo "   Run: rm assets/ai_config.json"
fi

if git ls-files | grep -q "ai_config.json"; then
  echo "❌ ERROR: ai_config.json is tracked by Git!"
  echo "   Run: git rm --cached assets/ai_config.json"
fi

# Check for .env files
echo ""
echo "✓ Checking for .env files..."
if git ls-files | grep -q "\.env"; then
  echo "❌ ERROR: .env files are tracked by Git!"
  echo "   Run: git rm --cached .env*"
fi

echo ""
echo "✅ Security check complete!"

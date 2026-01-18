# Fermi Frontend Deployment Guide

This document describes the deployment configuration and build processes for The Fermi Game's Flutter frontend application.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Environment Configuration](#environment-configuration)
- [Local Development](#local-development)
- [Building for Production](#building-for-production)
- [Platform-Specific Details](#platform-specific-details)
- [Troubleshooting](#troubleshooting)

---

## Overview

The Fermi Game frontend is a Flutter application that can be built for multiple platforms:

- **Android**: APK and App Bundle (AAB)
- **iOS**: IPA (requires macOS and Xcode)
- **Web**: Progressive Web App deployed to Firebase Hosting

### Build Targets

- **Development**: Local emulators with Firebase emulators and local API
- **Production**: Real Firebase services and production API endpoint

### Build Flavors

The app supports two build flavors for Android:

- **Dev Flavor** (`tech.leverai.guesstimate.dev`):
  - Used for internal testing via Firebase App Distribution
  - Includes "DEV" banner on app icon
  - App name: "Guesstimate Dev"
  - Can coexist with prod flavor on the same device
  - Connects to dev backend by default

- **Prod Flavor** (`tech.leverai.guesstimate`):
  - Used for Google Play Store releases
  - Standard app icon without banner
  - App name: "Guesstimate"
  - Connects to production backend

Both flavors have separate Firebase app configurations and can be installed simultaneously on the same device for testing.

---

## Prerequisites

### Required Tools

- **Flutter SDK**: Managed via FVM (Flutter Version Manager)
- **FVM**: For consistent Flutter version across team
- **Android SDK**: For Android builds and emulator
- **Android Emulator**: For local testing (recommended)

### Optional Tools

- **Xcode** (macOS only): Required for iOS builds
- **iOS Simulator** (macOS only): For iOS testing

### Installation

1. **Install FVM**:
   ```bash
   dart pub global activate fvm
   ```

2. **Install Flutter via FVM**:
   ```bash
   cd apps/fermi-frontend
   fvm install
   fvm use
   ```

3. **Install Dependencies**:
   ```bash
   fvm flutter pub get
   ```

4. **Verify Installation**:
   ```bash
   fvm flutter doctor
   ```

---

## Environment Configuration

The app uses `--dart-define` flags to configure runtime behavior. **All values must be provided**; the app does not default missing values.

### Required Environment Variables

- `USE_EMULATORS`: Set to `true` for local development, `false` for production
- `FIREBASE_AUTH_EMULATOR_HOST`: Firebase Auth emulator host (e.g., `127.0.0.1:9099`)
- `FIRESTORE_EMULATOR_HOST`: Firestore emulator host (e.g., `127.0.0.1:8080`)
- `API_BASE_URL`: Backend API base URL (e.g., `http://localhost:8000/api/v1`)

### Firebase Configuration

The app uses flavor-specific Firebase configuration files:

- **Dev Flavor**: `android/app/src/dev/google-services.json`
- **Prod Flavor**: `android/app/src/prod/google-services.json`
- **iOS**: `ios/Runner/GoogleService-Info.plist` (if iOS support added)

These files are **not** committed to the repository. Obtain them from Firebase Console:
1. Go to Firebase Console → Project Settings
2. Add Android app for each flavor (if not exists):
   - Dev: Package name `tech.leverai.guesstimate.dev`
   - Prod: Package name `tech.leverai.guesstimate`
3. Download each `google-services.json` and place in the appropriate flavor directory

---

## Local Development

### Starting the Development Environment

The easiest way to run the full stack locally:

```bash
# From workspace root
make run-frontend
```

This command:
1. Starts PostgreSQL database
2. Starts Firebase emulators (Auth + Firestore)
3. Runs database migrations
4. Seeds test data
5. Starts the backend API
6. Launches the Flutter app with emulator configuration

### Manual Development Setup

If you prefer manual control:

1. **Start Database and Emulators**:
   ```bash
   # From workspace root
   make up-api
   ```

2. **Start Android Emulator**:
   ```bash
   # List available emulators
   emulator -list-avds

   # Start emulator
   emulator -avd <emulator_name>
   ```

3. **Run Flutter App**:
   ```bash
   cd apps/fermi-frontend
   fvm flutter run -t lib/main.dart \
     --dart-define=USE_EMULATORS=true \
     --dart-define=FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
     --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
     --dart-define=API_BASE_URL=http://localhost:8000/api/v1
   ```

### Widget Demo Harness

For isolated widget development and testing:

```bash
cd apps/fermi-frontend
fvm flutter run -t lib/widget_test_harness.dart
```

This runs a demo environment without requiring backend services.

### Hot Reload

During development, Flutter supports hot reload:
- Press `r` in the terminal to reload
- Press `R` to hot restart
- Press `q` to quit

### Emulator Configuration

**Android Emulator Network**:
- The app automatically replaces `http://localhost` with `http://10.0.2.2` for Android emulators
- This allows the emulator to reach services running on the host machine

**Emulator Project ID**:
- With emulators enabled, Firebase initializes using projectId `fermi-local`
- Connects to emulator hosts provided in `--dart-define`

### Local Web Development

To run the web app locally with the full stack:

```bash
# From workspace root
make run-frontend-web
```

This command:
1. Starts PostgreSQL database
2. Starts Firebase emulators (Auth + Firestore)
3. Runs database migrations
4. Seeds test data
5. Starts the backend API
6. Launches the Flutter web app in Chrome

**Manual Web Development:**

```bash
# Start backend services
make up-api

# Wait for API to be ready, then run web app
cd apps/fermi-frontend
fvm flutter run -d chrome \
  --dart-define=USE_EMULATORS=true \
  --dart-define=FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  --dart-define=FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

**Testing Deep Links Locally:**

The web app handles deep links via URL paths. To test:
- Navigate to `http://localhost:<port>/dq/2025-12-23` for Daily Question
- Navigate to `http://localhost:<port>/invite/game/<game_id>` for game invites

The `DeepLinkService` recognizes `localhost` URLs and routes appropriately.

---

## Building for Production

### Android

The app uses build flavors for different deployment targets. Use the Makefile commands for simplified builds:

#### Dev Flavor (Firebase App Distribution)

Build a release APK for internal testing via Firebase App Distribution:

```bash
# From workspace root
make build-frontend-android-dev
```

Output: `build/app/outputs/flutter-apk/app-dev-release.apk`

**Manual build:**
```bash
cd apps/fermi-frontend
fvm flutter build apk --release --flavor dev \
  --dart-define=USE_EMULATORS=false \
  --dart-define=API_BASE_URL=https://fermi-api-bwuxx6eogq-uc.a.run.app/api/v1 \
  --dart-define=SUPPRESS_TEST_LOGS=true \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_nlfyHlphbqbWfeqdPYtzBVVgkJJ
```

**Distributing via Firebase App Distribution:**
```bash
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-dev-release.apk \
  --app 1:811437731406:android:3e808c9261b17a9c3c1d1f \
  --groups "internal-testers"
```

#### Prod Flavor (Google Play Store)

Build a release App Bundle for Google Play Store:

```bash
# From workspace root
make build-frontend-android-prod
```

Output: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`

**Manual build:**
```bash
cd apps/fermi-frontend
fvm flutter build appbundle --release --flavor prod \
  --dart-define=USE_EMULATORS=false \
  --dart-define=API_BASE_URL=https://fermi-api-prod-uc.a.run.app/api/v1 \
  --dart-define=SUPPRESS_TEST_LOGS=true \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_nlfyHlphbqbWfeqdPYtzBVVgkJJ
```

**Note**: Both flavors require signing configuration via environment variables:
- `KEYSTORE_FILE`: Path to keystore file
- `KEYSTORE_PASSWORD`: Keystore password
- `KEY_ALIAS`: Key alias
- `KEY_PASSWORD`: Key password

### iOS (macOS Only)

```bash
cd apps/fermi-frontend
fvm flutter build ios --release \
  --dart-define=USE_EMULATORS=false \
  --dart-define=API_BASE_URL=https://your-production-api.com/api/v1
```

**Requirements**:
- macOS with Xcode installed
- Apple Developer account for signing
- iOS provisioning profiles configured

### Web

```bash
cd apps/fermi-frontend
fvm flutter build web --release \
  --dart-define=USE_EMULATORS=false \
  --dart-define=API_BASE_URL=https://your-production-api.com/api/v1
```

Output: `build/web/`

**Deploying to Firebase Hosting:**

1. Build the web app (see above)
2. Deploy to Firebase Hosting:
   ```bash
   firebase deploy --only hosting
   ```

**Custom Domain Setup:**

The app can optionally use a custom domain (e.g., `guesstimate.leverai.tech`) for web hosting:

1. In Firebase Console → Hosting → Add custom domain
2. Add your domain
3. Follow DNS setup instructions (add CNAME record)
4. Wait for SSL certificate provisioning

**Deep Links:**

The app uses ChottuLink for cross-platform deep links in dev/prod environments, with API trampoline endpoints as fallback for local development.

**ChottuLink URLs (Dev/Prod):**
- Party: `https://guesstimate.chottu.link/invite?mode=party&id={game_id}`
- DQ: `https://guesstimate.chottu.link/invite?mode=dq&date={YYYY-MM-DD}`

ChottuLink handles:
- **Android**: App Links with automatic App Store fallback
- **iOS**: Universal Links with App Store fallback
- **Web**: Redirects to the Destination URL (e.g., `https://leverai.tech`)

**Local Development:**

When `INVITE_URL_BASE` is not set, the backend uses API trampoline endpoints:
- Game invites: `{API_BASE_URL}/api/v1/game/invite/{game_id}`
- Daily Question: `{API_BASE_URL}/api/v1/daily_question/invite/{YYYY-MM-DD}`

**Environment Configuration:**

Set `INVITE_URL_BASE` in your `.env` file:
- **Local**: Leave unset (uses trampoline)
- **Dev/Prod**: `INVITE_URL_BASE=https://guesstimate.chottu.link`

---

## Platform-Specific Details

### Android

**Minimum SDK**: Android 5.0 (API level 21)

**Permissions** (configured in `android/app/src/main/AndroidManifest.xml`):
- Internet access (required for API and Firebase)
- Network state (for connectivity checks)

**Configuration Files**:
- `android/app/build.gradle`: Build configuration, dependencies
- `android/app/google-services.json`: Firebase configuration
- `android/gradle.properties`: Gradle properties
- `android/local.properties`: Local SDK paths (not committed)

**Signing Configuration**:
For release builds, configure signing in `android/app/build.gradle`:

```gradle
android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### iOS (Future)

**Minimum Version**: iOS 12.0+

**Configuration Files**:
- `ios/Runner/Info.plist`: App metadata and permissions
- `ios/Runner/GoogleService-Info.plist`: Firebase configuration
- `ios/Podfile`: CocoaPods dependencies

### Web

**Configuration Files**:
- `web/index.html`: Entry point
- `web/manifest.json`: PWA manifest
- `web/.well-known/apple-app-site-association`: iOS Universal Links verification
- `web/.well-known/assetlinks.json`: Android App Links verification
- `firebase.json`: Firebase Hosting configuration

**Deep Links Configuration:**

The app uses ChottuLink for cross-platform deep links. Native apps register to handle:

- **ChottuLink domain**: `guesstimate.chottu.link` (App Links/Universal Links)
- **Custom scheme**: `guesstimate://` (fallback for local development)

**Android** (`AndroidManifest.xml`):
- Intent filters for `guesstimate://` scheme (invite/dq hosts)
- App Links for `https://guesstimate.chottu.link`

**iOS** (`Runner.entitlements`):
- Associated domains: `applinks:guesstimate.chottu.link`
- URL scheme: `guesstimate://` in `Info.plist`

**ChottuLink Dashboard Configuration:**
- Ensure SHA256 fingerprints are added for Android App Links verification
- Ensure Team ID, Bundle ID, and App Store ID are configured for iOS

**Verification Files (Hosted by ChottuLink):**
- ChottuLink automatically hosts `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` on their domain

These are configured in `firebase.json` with proper headers.

---

## Troubleshooting

### Common Issues

#### Stuck on Loading or 401 Errors

**Symptoms**: App shows loading screen indefinitely or authentication fails

**Causes**:
- Token exchange failed
- Invalid dart-define values
- Emulator hosts incorrect

**Solutions**:
1. Check logs for token exchange errors
2. Verify all `--dart-define` values are provided
3. Ensure emulators are running (`make up-api`)
4. Verify API is accessible at specified URL

#### Backend Unreachable on Android Emulator

**Symptoms**: Network errors when connecting to API

**Cause**: Android emulator uses special IP for host

**Solution**: The app automatically handles this by replacing `localhost` with `10.0.2.2`. Ensure API is running and accessible.

#### Firestore Listener Issues

**Symptoms**: Real-time updates not working

**Causes**:
- Emulators not running
- Wrong project ID
- Incorrect emulator host configuration

**Solutions**:
1. Ensure Firebase emulators are running
2. Verify project ID is `fermi-local` for emulators
3. Check `FIRESTORE_EMULATOR_HOST` is correct
4. Restart emulators if needed

#### Unitless Answer Issues

**Symptom**: Errors when submitting answers without units

**Solution**: Ensure backend is running with the refactor that treats unitless as `null`. Leaving the unit empty will submit `unit: null`.

#### Build Failures

**Symptoms**: Flutter build fails with errors

**Common Solutions**:
1. **Clean and rebuild**:
   ```bash
   fvm flutter clean
   fvm flutter pub get
   fvm flutter build <target>
   ```

2. **Check Flutter version**:
   ```bash
   fvm flutter --version
   ```

3. **Update dependencies**:
   ```bash
   fvm flutter pub upgrade
   ```

4. **Android Gradle issues**:
   ```bash
   cd android
   ./gradlew clean
   cd ..
   ```

#### Firebase Configuration Missing

**Symptom**: Build fails with "google-services.json not found"

**Solution**:
1. Download `google-services.json` from Firebase Console
2. Place in `android/app/` directory
3. Ensure file is not in `.gitignore`

#### Hot Reload Not Working

**Symptoms**: Changes don't reflect in running app

**Solutions**:
1. Try hot restart (`R` in terminal)
2. Stop and restart the app
3. Check for syntax errors in code
4. Verify file is saved

### Platform-Specific Troubleshooting

#### Android

**Gradle sync issues**:
```bash
cd android
./gradlew clean
./gradlew build --refresh-dependencies
```

**Emulator performance**:
- Enable hardware acceleration in BIOS
- Allocate more RAM to emulator in AVD Manager
- Use x86_64 system images (faster than ARM)

#### iOS (Future)

**Pod installation issues**:
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
```

**Xcode build errors**:
- Clean build folder in Xcode (Cmd+Shift+K)
- Update CocoaPods: `pod update`
- Verify provisioning profiles are valid

### Debugging Tips

**Enable verbose logging**:
```bash
fvm flutter run -v
```

**Check device logs**:
```bash
# Android
adb logcat

# iOS (on device)
idevicesyslog
```

**Analyze build output**:
```bash
fvm flutter analyze
```

**Format code**:
```bash
fvm flutter format .
```

---

## Related Documentation

- [Frontend README](../README.md): Quick start and overview
- [Architecture Guide](ARCHITECTURE.md): Detailed implementation details
- [Fermi API Deployment](../../fermi-api/docs/DEPLOYMENT.md): Backend deployment
- [Main CI/CD Documentation](../../../docs/CICD.md): Complete infrastructure setup

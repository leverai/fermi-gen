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
- **Web**: Progressive Web App (future)

### Build Targets

- **Development**: Local emulators with Firebase emulators and local API
- **Production**: Real Firebase services and production API endpoint

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

The app includes Firebase configuration files:

- **Android**: `android/app/google-services.json`
- **iOS**: `ios/Runner/GoogleService-Info.plist` (if iOS support added)

These files are **not** committed to the repository. Obtain them from Firebase Console:
1. Go to Firebase Console → Project Settings
2. Add Android app (if not exists)
3. Download `google-services.json` and place in `android/app/`

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

---

## Building for Production

### Android

#### Debug APK (Testing)

```bash
cd apps/fermi-frontend
fvm flutter build apk --debug \
  --dart-define=USE_EMULATORS=false \
  --dart-define=API_BASE_URL=https://your-production-api.com/api/v1
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

#### Release APK

```bash
cd apps/fermi-frontend
fvm flutter build apk --release \
  --dart-define=USE_EMULATORS=false \
  --dart-define=API_BASE_URL=https://your-production-api.com/api/v1
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

#### Release App Bundle (AAB)

For Google Play Store distribution:

```bash
cd apps/fermi-frontend
fvm flutter build appbundle --release \
  --dart-define=USE_EMULATORS=false \
  --dart-define=API_BASE_URL=https://your-production-api.com/api/v1
```

Output: `build/app/outputs/bundle/release/app-release.aab`

**Note**: App Bundle requires signing configuration in `android/app/build.gradle`.

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

### Web (Future Support)

```bash
cd apps/fermi-frontend
fvm flutter build web --release \
  --dart-define=USE_EMULATORS=false \
  --dart-define=API_BASE_URL=https://your-production-api.com/api/v1
```

Output: `build/web/`

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

### Web (Future)

**Configuration Files**:
- `web/index.html`: Entry point
- `web/manifest.json`: PWA manifest
- Firebase SDK initialization in `web/index.html`

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

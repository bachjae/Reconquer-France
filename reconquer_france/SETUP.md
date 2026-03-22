# Reconquer France — Setup Guide

## Prerequisites

- Flutter 3.19+ with Dart 3.3+
- Firebase project (create at console.firebase.google.com)
- Mapbox account (mapbox.com) with a public access token
- Xcode 15+ (for iOS)
- Android Studio / VS Code

---

## 1. Firebase Setup

### Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project: `reconquer-france`
3. Enable the following services:
   - **Authentication**: Enable Google Sign-In + Email/Password
   - **Cloud Firestore**: Create database in production mode
   - **Firebase Messaging**: No additional setup needed
   - **Cloud Functions**: Enable Blaze plan (required for Functions)

### Generate `firebase_options.dart`

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=reconquer-france
```

This replaces `lib/firebase_options.dart` with your real config.

### Download config files

- **Android**: Download `google-services.json` → place at `android/app/google-services.json`
- **iOS**: Download `GoogleService-Info.plist` → place at `ios/Runner/GoogleService-Info.plist`

---

## 2. Mapbox Setup

1. Sign up at [mapbox.com](https://www.mapbox.com)
2. Create a **Public Access Token** (starts with `pk.`)
3. Create a **Secret Access Token** (starts with `sk.`) with `DOWNLOADS:READ` scope

### Configure tokens

**`lib/main.dart`** — Replace:
```dart
const String _mapboxAccessToken = 'pk.YOUR_MAPBOX_ACCESS_TOKEN_HERE';
```

**`ios/Runner/Info.plist`** — Replace:
```xml
<string>pk.YOUR_MAPBOX_ACCESS_TOKEN_HERE</string>
```

**`android/build.gradle`** — Add to `local.properties` or env:
```
MAPBOX_DOWNLOADS_TOKEN=sk.YOUR_MAPBOX_SECRET_TOKEN
```

Or set the environment variable:
```bash
export MAPBOX_DOWNLOADS_TOKEN=sk.eyJ1...
```

---

## 3. Google Sign-In Setup

### Android
Add your SHA-1 fingerprint to Firebase:
```bash
cd android && ./gradlew signingReport
```
Copy the SHA-1 and add it in Firebase Console → Project Settings → Android app.

### iOS
1. In `ios/Runner.xcworkspace`, open project settings
2. Set Bundle ID to `com.reconquer.reconquerFrance`
3. Add the `GoogleService-Info.plist` URL scheme to Info.plist (FlutterFire handles this automatically)

---

## 4. Background Geolocation Setup

The app uses `flutter_background_geolocation` by Transistor Software.

### iOS
Add to `ios/Runner/Runner.entitlements`:
```xml
<key>com.apple.developer.location.push</key>
<true/>
```

### Android
The `AndroidManifest.xml` is already configured.

---

## 5. Critical Alerts (HUSKER) — iOS Only

HUSKER alerts bypass silent mode. This requires Apple's Critical Alert entitlement.

1. Request entitlement from [Apple Developer Portal](https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/)
2. Once approved, add to your app's `.entitlements` file:
```xml
<key>com.apple.developer.usernotifications.critical-alerts</key>
<true/>
```

---

## 6. Install Dependencies

```bash
cd reconquer_france
flutter pub get
```

### Regenerate Hive adapters (if needed)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 7. Deploy Firebase Functions

```bash
cd reconquer_france/functions
npm install
npm run build
firebase deploy --only functions
```

---

## 8. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

---

## 9. Add Real Fonts

Download from Google Fonts and place in `assets/fonts/`:
- [Playfair Display](https://fonts.google.com/specimen/Playfair+Display): Regular, Bold, Italic
- [Inter](https://fonts.google.com/specimen/Inter): Regular, Medium, Bold

---

## 10. Add Sound Files

Replace placeholder files in `assets/sounds/`:
- `corn_pop.wav` — A fun pop/corn sound
- `husker_alarm.wav` — An urgent alarm sound

---

## 11. Run the App

```bash
# iOS Simulator
flutter run -d ios

# Android Emulator
flutter run -d android

# Physical device (recommended for GPS)
flutter run -d <device_id>
```

---

## Architecture Notes

### Hex Grid
- Each hex is ~1km² at France's latitude
- ~550,000 total cells cover metropolitan France
- Cells are identified by `col:row` string keys
- Viewport culling keeps max 500 hexes rendered at once
- At zoom < 8, hexes are hidden for performance

### Offline Sync
1. GPS unlock → saved to Hive instantly
2. Queued for Firestore sync
3. Debounced 30s batch write
4. On connectivity restore → flush queue

### Emergency Alerts
- **Corn** 🌽: Normal FCM → group only → doesn't bypass DND
- **Husker** 🔴: High priority FCM → all friends → bypasses DND via:
  - iOS: Critical Alert (requires Apple entitlement)
  - Android: `IMPORTANCE_MAX` channel + `fullScreenIntent`

### State Management
- Riverpod for all state
- `SyncService` owns Hive boxes (shared global access)
- Providers compose over services

---

## File Structure

```
lib/
├── main.dart                    # Entry point, Firebase + Hive init
├── app.dart                     # MaterialApp.router
├── firebase_options.dart        # AUTO-GENERATED by flutterfire CLI
├── core/
│   ├── constants.dart           # France bounds, colors, config
│   ├── theme.dart               # Dark cinematic theme
│   └── router.dart              # GoRouter with shell route
├── models/
│   ├── hex_cell.dart            # HexCell + Hive adapter
│   ├── trip_photo.dart          # TripPhoto + Hive adapter
│   ├── user_profile.dart        # UserProfile + Trip models
│   └── trip_group.dart          # TripGroup + GroupAlert + FriendRequest
├── services/
│   ├── hex_grid_service.dart    # Hex math (latLng ↔ hexId)
│   ├── location_service.dart    # Background GPS + dwell timer
│   ├── photo_service.dart       # photo_manager + EXIF parsing
│   ├── sync_service.dart        # Hive + Firestore offline sync
│   ├── notification_service.dart# FCM + local notifications
│   └── auth_service.dart        # Firebase Auth wrapper
├── providers/
│   ├── auth_provider.dart       # Auth state
│   ├── map_provider.dart        # Unlocked cells + viewport
│   ├── photo_provider.dart      # Photo state
│   └── social_provider.dart     # Groups, leaderboard, friends
├── screens/
│   ├── splash/                  # Animated France outline draw
│   ├── onboarding/              # 3-step swipeable intro
│   ├── auth/                    # Login + Register (3-step)
│   ├── trip_setup/              # Trip name, dates, group, offline map
│   ├── map/                     # Main map + hex detail sheet
│   ├── camera/                  # In-app camera with GPS
│   ├── gallery/                 # Grid view + map view
│   ├── social/                  # Friends + leaderboard tabs
│   ├── profile/                 # Stats + settings
│   └── export/                  # Instagram story card export
└── widgets/
    ├── emergency_fab.dart       # Corn + Husker SpeedDial FAB
    ├── progress_badge.dart      # % France conquered badge
    ├── hex_overlay_painter.dart # CustomPainter for hex grid
    └── friend_map_overlay.dart  # Re-export of overlay painter

functions/
└── src/index.ts                 # Cloud Functions (FCM fanout, milestones)

firestore.rules                  # Firestore security rules
firestore.indexes.json           # Compound indexes
firebase.json                    # Firebase project config
```

================================================================================
                      EXAMVAULT - DEPENDENCIES INVENTORY
================================================================================

Project path : /home/rj12_rj1/Desktop/Dev Projects (OC)/exam-vault
Generated    : Thu Nov 12 2026

This file lists both (a) the Dart/Flutter package dependencies declared in
pubspec.yaml and (b) the system toolchain dependencies required to build and
run the app, together with their installed status on this system.

--------------------------------------------------------------------------------
A. DART / FLUTTER PACKAGE DEPENDENCIES  (source: pubspec.yaml)
--------------------------------------------------------------------------------

Production dependencies (declared in pubspec.yaml, resolved by `flutter pub get`):

  flutter                    SDK      Flutter framework (Dart SDK included)
  cupertino_icons   ^1.0.8   iOS-style icons
  file_picker        ^13.3.2  System file picker (import PDF/TXT)
  sqflite             ^2.4.5+1  Local SQLite storage
  path                ^1.9.1   File path utilities
  path_provider       ^2.1.6   Locate app documents directory
  syncfusion_flutter_pdf ^35.1.43  Embedded-text PDF extraction
  pdfx                ^2.11.0   Scanned-PDF page rendering
  google_mlkit_text_recognition ^1.0.1  On-device OCR (Latin model)
  share_plus          ^13.3.1   Android share sheet (CSV export)
  intl                ^0.20.3   Date/number formatting

Dev dependencies:

  flutter_test     SDK      Flutter test framework
  flutter_lints    ^6.0.0   Recommended Dart lint rules

Status: All resolved and fetched. `flutter pub get` completed successfully.
         24 packages have newer versions incompatible with the declared
         constraints (informational only; run `flutter pub outdated` to review).

--------------------------------------------------------------------------------
B. SYSTEM TOOLCHAIN DEPENDENCIES  (required to build/run on Android)
--------------------------------------------------------------------------------

| Dependency          | Required        | Installed on this system           | Status  |
|---------------------|-----------------|------------------------------------|---------|
| Flutter SDK         | any stable      | /home/rj12_rj1/flutter (3.50.0)    | INSTALLED|
| Dart SDK            | bundled w/ Flutter | /home/rj12_rj1/flutter/bin/dart  | INSTALLED|
| Java (JDK)          | 17              | /usr/lib/jvm/java-17-openjdk-amd64 | INSTALLED|
| Android Studio      | any recent      | /opt/android-studio                | INSTALLED|
| Android SDK (root)  | ANDROID_HOME    | /home/rj12_rj1/Android/Sdk         | INSTALLED|
| SDK cmdline-tools   | sdkmanager      | $ANDROID_HOME/cmdline-tools/latest | INSTALLED|
| platform-tools      | adb             | $ANDROID_HOME/platform-tools       | INSTALLED|
| build-tools         | 36.0.0          | $ANDROID_HOME/build-tools/36.0.0   | INSTALLED|
| compile platform    | android-36 (37 OK)| $ANDROID_HOME/platforms/android-37 | INSTALLED|
| SDK licenses        | accepted        | $ANDROID_HOME/licenses             | INSTALLED|
| local.properties    | flutter.sdk + sdk.dir | android/local.properties        | CREATED |

Notes:
- The Linux desktop toolchain (clang++, CMake, ninja, pkg-config) is NOT
  installed, but this app targets Android only, so it is not required.
- `flutter doctor` reports the Android toolchain as [✓]. The only remaining
  doctor notice is the optional Linux desktop toolchain.
- No new packages were added for the LLM question generation pipeline — it
  uses Dart's built-in `dart:io` (`HttpClient`) for HTTP calls, so no
  `pubspec.yaml` changes are required. The LLM API key is supplied at runtime
  (not bundled in the app).

--------------------------------------------------------------------------------
C. ENVIRONMENT VARIABLES (add to ~/.bashrc or ~/.profile)
--------------------------------------------------------------------------------

  export FLUTTER_HOME="$HOME/flutter"
  export ANDROID_HOME="$HOME/Android/Sdk"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  export PATH="$FLUTTER_HOME/bin:$PATH"
  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
  export PATH="$ANDROID_HOME/platform-tools:$PATH"

--------------------------------------------------------------------------------
D. BUILD / TEST COMMANDS (run from project root)
--------------------------------------------------------------------------------

  export FLUTTER_HOME="$HOME/flutter"
  export ANDROID_HOME="$HOME/Android/Sdk"
  export PATH="$FLUTTER_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

  flutter pub get          # fetch Dart dependencies
  flutter analyze          # static analysis
  flutter test             # run unit/widget/integration tests (24 tests)
  flutter build apk --release   # build release APK

--------------------------------------------------------------------------------
                            END OF DEPENDENCIES
================================================================================

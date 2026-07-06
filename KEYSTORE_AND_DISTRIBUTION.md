# Keystore + Firebase App Distribution — setup & release procedure

## Where things stood

Checking `android/app/build.gradle.kts`, this project has never had a real
release keystore — release builds were signing with the **debug** key
(`signingConfig = signingConfigs.getByName("debug")`), and `applicationId`
is still the Flutter template default, `com.example.aquagas`. I've wired
`build.gradle.kts` to use a proper release keystore *once you create one*
(falls back to debug signing until then, so nothing breaks today). The
keystore itself has to come from you, run locally — a signing key is a
secret, and it needs to be the same one for every release you ever ship
(Android refuses to install an update signed with a different key over an
existing install), so it shouldn't be something generated somewhere other
than a machine you control long-term.

## Step 0 — decide your real Application ID first

Before generating anything, decide the real package name, e.g.
`com.aquagas.customer` (something you're prepared to keep forever — this
is very painful to change once you're on the Play Store). Then update:

- `android/app/build.gradle.kts` → both `namespace` and `applicationId`
- Register an Android app under that *exact* name in your Firebase
  console, and download the resulting `google-services.json` into
  `android/app/google-services.json` (this file is now git-ignored — see
  the `.gitignore` I added)

Push notifications (see the separate notification-system changes) need
this done too — `Firebase.initializeApp()` in `main.dart` is wrapped in a
try/catch so the app won't crash without it, but it also won't be able to
register a device for push until this step is done.

## Step 1 — generate your upload keystore (run this yourself, once)

Run this on your own machine — not in CI, not by anyone else — and back up
the resulting file and passwords somewhere durable (a password manager,
not just your laptop). If you ever lose it, you lose the ability to
publish updates to whatever it signed.

```bash
keytool -genkey -v -keystore aquagas-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias aquagas
```

You'll be prompted for a keystore password, your name/org details, and a
key password (can be the same as the keystore password). Move the
resulting `aquagas-release.jks` somewhere outside the repo entirely, e.g.
`~/keys/aquagas-release.jks`.

## Step 2 — create `android/key.properties`

Create this file (it's git-ignored, so it stays local/CI-only):

```properties
storePassword=<the keystore password you set>
keyPassword=<the key password you set>
keyAlias=aquagas
storeFile=/absolute/path/to/aquagas-release.jks
```

`build.gradle.kts` now reads this automatically — as soon as this file
exists, `flutter build apk --release` / `flutter build appbundle` sign
with it instead of the debug key. Verify with:

```bash
keytool -list -v -keystore aquagas-release.jks
# compare the SHA-1/SHA-256 fingerprint against:
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

## Step 3 — Firebase App Distribution (the "beta ring")

One-time setup:

```bash
npm install -g firebase-tools
firebase login
```

In the Firebase console: **Release & Monitor → App Distribution**, create
a **tester group** (e.g. `beta-ring`) and add tester emails to it — this
is what makes it a "ring" you can push to repeatedly rather than emailing
an APK around.

Find your Firebase Android app ID (Project settings → General → your
Android app → "App ID", looks like `1:1234567890:android:abcdef`).

Each release:

```bash
flutter build apk --release
# bump versionCode/versionName in pubspec.yaml first — App Distribution
# will reject re-uploading the same versionCode

firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app <your-firebase-android-app-id> \
  --groups "beta-ring" \
  --release-notes "What changed in this build"
```

Testers in that group get an email/App Distribution app notification to
install the update — and because every build is signed with the *same*
keystore now, each one installs cleanly over the last instead of asking
them to uninstall first.

### Alternative: Gradle plugin instead of the CLI

If you'd rather trigger distribution as part of `./gradlew` (useful once
you wire up CI), add the `com.google.firebase.appdistribution` Gradle
plugin and an `appDistribution { }` block to `android/app/build.gradle.kts`
pointing at the same app ID and group. The CLI above is the simpler
starting point — worth revisiting once a CI pipeline exists.

## Quick release checklist (going forward)

1. Bump `version:` in `pubspec.yaml` (`x.y.z+buildNumber` — the number
   after `+` is `versionCode` and must strictly increase every release).
2. `flutter build apk --release`
3. `firebase appdistribution:distribute ...` (Step 3 command above)
4. Confirm in the Firebase console that testers received it.

# Hisaab Mobile

Native Android and iOS client for the Hisaab ledger. It connects to the same
OTP-authenticated server and PostgreSQL database as the web app.

## Included

- GetX state, dependency, and route management
- Phone-number OTP login with a secure 30-day device session
- Local-test OTP prefill only when the server returns `developmentCode`
- Home summary with direct **You gave** and **You got** actions
- Parties directory with search, balance filters, archive/restore, and statements
- Permission-gated contact directory grouped into ledger, Hisaab, and other contacts
- Manual party entry that never depends on contact permission
- One-tap dialer plus WhatsApp, native SMS composer, copy, text, and PDF sharing
- Authoritative, paginated party statements with opening/running/closing balances
- Optional exact-decimal calculator keypad for transaction amounts
- Red `−` / **You gave** and green `+` / **You got** language everywhere
- Optional note, date, and payment-account fields hidden under disclosure
- Simple entry and statement date filters
- Encrypted local ledger, durable pending operations, and offline party/entry creation
- Foreground sync on launch, resume, reconnection, and manual retry
- Learn section, settings, refresh, and logout
- Session cookie stored with Android Keystore / iOS Keychain

## Requirements

- Flutter 3.44 or newer and Dart 3.12 or newer
- Android SDK 36 and Java 17
- Xcode with iOS 13+ deployment support
- A running Hisaab web server

## Run

Pass the server origin explicitly so every build points at the intended
environment:

```sh
cd mobile_app
flutter pub get
flutter run \
  --dart-define=HISAAB_API_URL=https://hisaab.example.com
```

For local Android Emulator development, use the host bridge (for example,
`http://10.0.2.2:3000`) and a debug-only cleartext configuration if needed.
Use a trusted HTTPS URL for devices and all distributed builds. Native requests
intentionally do not send browser `Origin` headers, and authentication uses the
server's session-cookie contract.

## Local testing OTP

When the local server uses `OTP_PROVIDER=console`, it returns a
`developmentCode`. The app clearly marks testing mode and pre-fills that code.
Production Twilio responses do not contain the field, so no code is displayed
or pre-filled.

## Contacts privacy

Hisaab requests read-only contacts permission only after the user taps
**Find from contacts** and accepts a separate privacy primer. Contact names stay
on the device. Valid phone numbers are normalized to E.164 and sent only after
that consent to the same authenticated Hisaab server for ephemeral matching;
the request values are not retained. The server returns presence only for users
who opted in to discoverability—never their name, company, or ledger data.
Manual party entry remains available without permission or discovery.

Platform declarations:

- Android: `READ_CONTACTS`, `INTERNET`, and `ACCESS_NETWORK_STATE` (to
  detect reconnects and resume queued sync)
- iOS: `NSContactsUsageDescription`

## Quality checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug \
  --dart-define=HISAAB_API_URL=https://hisaab.example.com
```

## Android release

Create an upload keystore, copy `android/key.properties.example` to
`android/key.properties`, and replace every placeholder. The real properties
file and keystore are ignored by Git. Release builds fail closed when signing
or a public HTTPS API origin is missing, preventing accidental debug-signed or
private-server publication.

```sh
flutter build appbundle --release \
  --dart-define=HISAAB_API_URL=https://hisaab.example.com
```

## iOS release

Open `ios/Runner.xcworkspace`, select the `com.hisaab.app` Runner target, and
choose the correct Apple Developer team and signing profile. Then build with:

```sh
flutter build ipa --release \
  --dart-define=HISAAB_API_URL=https://hisaab.example.com
```

Never commit signing certificates, provisioning profiles, keystores, API
credentials, Twilio credentials, or session secrets.

## Structure

```text
lib/
  app/             GetMaterialApp routes
  core/            API config, theme, encrypted storage/outbox, sync, formatting
  data/            Backend models and repositories
  features/        Auth, home, parties, entries, learn, and settings
  services/        Native contacts gateway
  shared/widgets/  Reusable direction, balance, party, and entry UI
```

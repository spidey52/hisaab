# Internal artifacts only

Files in this directory are local test artifacts. In particular,
`hisaab-mobile-release-test.apk` is debug-signed and must not be uploaded to
Google Play or shared as a production release.

Production Android releases must be generated as an AAB with the configured
upload keystore. Cloud sign-in uses the hardcoded live API origin in
`lib/core/config/app_config.dart`.

```sh
flutter build appbundle --release
```

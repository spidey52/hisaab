# Internal artifacts only

Files in this directory are local test artifacts. In particular,
`hisaab-mobile-release-test.apk` is debug-signed and must not be uploaded to
Google Play or shared as a production release.

Production Android releases must be generated as an AAB with the configured
upload keystore and a public HTTPS API origin:

```sh
flutter build appbundle --release \
  --dart-define=HISAAB_API_URL=https://api.example.com
```

The build now fails when release signing or the production API origin is
missing.

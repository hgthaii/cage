# Releasing Cage

[Tiếng Việt](RELEASING.md) · [English](RELEASING.en.md)

CI treats `vX.Y.Z` tags as the only release version source. Pull requests and
ordinary pushes run tests, build a Universal 2 app, and verify it. A valid tag
also creates the DMG, Sparkle ZIP, EdDSA-signed appcast, and GitHub Release.

The repository needs three secrets:

- `CAGE_SIGNING_CERTIFICATE_P12_BASE64`
- `CAGE_SIGNING_CERTIFICATE_PASSWORD`
- `SPARKLE_EDDSA_PRIVATE_KEY`

The public Sparkle key is stored in `Resources/Info.plist`. The private key was
created under the `dev.hgthaii.cage` Keychain account; export it with Sparkle's
`generate_keys` tool and save it directly as a GitHub Secret. Never commit it.

Before creating a tag, run:

```sh
swift test --disable-sandbox
bash scripts/app.sh build-and-verify
bash scripts/build-dmg.sh
```

Do not describe a release as notarized until Developer ID signing, notarization,
and stapling have been configured and verified in practice.

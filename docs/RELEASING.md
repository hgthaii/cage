# Phát hành Cage

[Tiếng Việt](RELEASING.md) · [English](RELEASING.en.md)

CI dùng tag `vX.Y.Z` làm nguồn version duy nhất. Pull request và push thường chạy
test, build Universal 2 và verify app. Tag hợp lệ sẽ tạo thêm DMG, Sparkle ZIP,
appcast ký EdDSA và GitHub Release.

Repository cần ba secret:

- `CAGE_SIGNING_CERTIFICATE_P12_BASE64`
- `CAGE_SIGNING_CERTIFICATE_PASSWORD`
- `SPARKLE_EDDSA_PRIVATE_KEY`

Public Sparkle key nằm trong `Resources/Info.plist`. Private key đã được tạo dưới
account Keychain `dev.hgthaii.cage`; xuất key bằng công cụ `generate_keys` của
Sparkle rồi lưu thẳng vào GitHub Secret, không commit vào repository.

Trước khi tạo tag, chạy:

```sh
swift test --disable-sandbox
bash scripts/app.sh build-and-verify
bash scripts/build-dmg.sh
```

Chưa được mô tả bản phát hành là notarized cho tới khi Developer ID, notarization
và stapling được cấu hình và xác minh thực tế.

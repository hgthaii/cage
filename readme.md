<h1 align="center">
  <img src="src/Media.xcassets/AppIcon.appiconset/icon.png" width="110" alt="Cage"/>
  <br>
  Cage
</h1>

<p align="center">Giữ con trỏ trong những ứng dụng bạn chọn.</p>

<p align="center"><strong>Tiếng Việt</strong> · <a href="README.en.md">English</a></p>

Cage là tiện ích menu bar nhẹ cho macOS. Cage giữ con trỏ trong cửa sổ của các
ứng dụng bạn thêm vào danh sách cho phép. Khi bạn chuyển sang ứng dụng khác,
con trỏ được thả ngay; khi quay lại, Cage tự giới hạn con trỏ lần nữa.

## Tính năng

- Hoạt động với mọi ứng dụng macOS được thêm vào danh sách cho phép.
- Thêm ứng dụng bất kỳ bằng cách chọn file `.app` tương ứng.
- Giữ di chuyển, click, kéo và cuộn trong biên cửa sổ đã chọn.
- Settings có General để chọn ứng dụng và bật mở cùng macOS (macOS 13+), cùng tab About riêng.
- Tự cập nhật an toàn qua Sparkle và appcast ký EdDSA.
- Không thay đổi DPI, acceleration hay sensitivity của chuột.

## Cách dùng

1. Mở Cage và cấp quyền Accessibility khi macOS yêu cầu.
2. Mở `Settings…` → `General` → `Add App…` để thêm một ứng dụng.
3. Chuyển sang ứng dụng đó để Cage tự giới hạn con trỏ theo cửa sổ của nó.
4. Dùng `Cmd+Tab` để chuyển đi và thả con trỏ.

## Yêu cầu

- macOS 11 trở lên.
- Quyền Accessibility chỉ được dùng để chặn và điều chỉnh sự kiện chuột.

## Phát triển

```sh
swift test --disable-sandbox
bash scripts/app.sh build-and-verify
bash scripts/build-dmg.sh
```

Xem thêm [kiến trúc](docs/ARCHITECTURE.md) và [quy trình phát hành](docs/RELEASING.md).

## Quyền riêng tư

Cage hoạt động cục bộ. Ứng dụng không lưu chuyển động chuột, thao tác click hay
nội dung trên màn hình. Sparkle chỉ kết nối mạng khi bạn chủ động kiểm tra cập nhật.

## Ghi công

Phát triển bởi **hgthaii**. Dựa trên **MouseLock** của **mxrlkn**.

Dự án gốc: [mxrlkn/mouselock](https://github.com/mxrlkn/mouselock).

## Giấy phép

Xem file [license](license).

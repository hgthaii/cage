# Kiến trúc Cage

[Tiếng Việt](ARCHITECTURE.md) · [English](ARCHITECTURE.en.md)

`CageCore` chứa quy tắc xác định trạng thái và giới hạn con trỏ. `CageApp` kết nối
các quy tắc đó với cửa sổ macOS, quyền Accessibility, menu bar và Sparkle.

Mỗi ứng dụng trong danh sách cho phép được nhận diện bằng bundle identifier.
Người dùng có thể thêm file `.app` từ Settings → General. Cage chỉ giới hạn con trỏ khi một
ứng dụng đã chọn đang ở foreground và có cửa sổ hợp lệ. Chuyển sang ứng dụng
khác sẽ gỡ giới hạn ngay.

Cage áp dụng cùng một biên cho di chuyển, click, kéo và cuộn. Biên được lùi nhẹ
vào trong cửa sổ để tránh Dock, menu bar và hot corner nhận nhầm sự kiện.

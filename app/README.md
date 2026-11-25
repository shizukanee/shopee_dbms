# Ứng dụng BTL2 — 3 kênh: Người mua · Người bán · Quản trị

## 0. Đăng nhập & phân kênh

Đăng ký tại `/register` (chọn **Người mua** hoặc **Người bán**), đăng nhập tại `/login`.
Hệ thống xem `UserID` có trong bảng `BUYER` / `SELLER` / `ADMIN` để đưa vào kênh tương ứng;
tài khoản có nhiều vai trò sẽ được chọn kênh (`/chon-kenh`). Quản trị viên không tự đăng ký.

| Kênh | Tính năng | Thủ tục CSDL |
|---|---|---|
| `/buyer` Người mua | Tìm sản phẩm (chỉ ACTIVE, shop ACTIVE/WARNED) | `sp_tv4_tim_kiem_san_pham` |
| `/seller` Người bán | Thêm / sửa / xóa sản phẩm **của shop mình** (không đặt được BANNED) | `sp_product_them/sua/xoa` |
| | Tìm kiếm, thống kê tồn kho (cố định shop của mình) | `sp_tv4_tim_kiem_san_pham`, `sp_tv4_thong_ke_ton_kho` |
| | Mở cửa hàng (chỉ khi đã được xác minh) | trigger `trg_shop_bi` |
| `/admin` Quản trị | Kiểm duyệt toàn sàn + gỡ sản phẩm (BANNED) | `sp_tv4_tim_kiem_san_pham`, `sp_product_sua` |
| | Thống kê tồn kho toàn sàn | `sp_tv4_thong_ke_ton_kho` |
| | Duyệt người bán (PENDING → VERIFIED / REJECTED) | `UPDATE SELLER` |

### Tài khoản demo

Mật khẩu trong dữ liệu mẫu là chuỗi giả, nên chạy một lần:

```bat
npm run seed-demo
```

Lệnh này đặt mật khẩu `123456` cho: `an.nguyen@gmail.com` (người mua),
`lan.bui@gmail.com` (người mua + người bán), `khang.hoang@gmail.com` (người bán),
`phuc.truong@gmail.com` (người bán chờ xác minh), `son.phan@shopee-admin.vn` (quản trị).

---

# TV3 — Câu 2.1 & Giao diện 3.1

Thư mục này chứa:

| File | Nội dung |
|---|---|
| `../TV3_2.1_thu_tuc_PRODUCT.sql` | 3 thủ tục `sp_product_them`, `sp_product_sua`, `sp_product_xoa` cho bảng `PRODUCT` |
| `../TV3_demo_test_thu_tuc.sql` | Kịch bản minh họa từng trường hợp hợp lệ / lỗi (chạy trong transaction, cuối file `ROLLBACK`) |
| `server.js` | Express server, điều hướng, validate 2 lớp, hiển thị lỗi từ CSDL |
| `productRepository.js` | Gọi 3 thủ tục + các SELECT phục vụ hiển thị |
| `views/products.ejs` | Màn hình 3.1 — form thêm/sửa + bảng danh sách + modal xóa |
| `public/style.css`, `public/app.js` | Giao diện và validate phía trình duyệt |

## 1. Yêu cầu

- MySQL **8.0.16+** (đã dùng CHECK, functional index, cột sinh, `SIGNAL`).
- Node.js **18+** (dùng `dotenv` để đọc `.env`).
- Đã chạy lần lượt:
  1. `TV1_1.1_create_tables_triggers.sql` (tạo database `shopee_db` + 19 bảng + trigger)
  2. `TV2_2.2.2_trigger_TotalAmount.sql` (trigger `TotalAmount`)
  3. `TV2_napdulieu.sql` (dữ liệu mẫu)
  4. `TV3_2.1_thu_tuc_PRODUCT.sql` (3 thủ tục của câu 2.1)

Thứ tự 2 và 3 có thể đổi cho nhau — nếu chạy data trước thì cuối file TV2 có câu tính lại `TotalAmount`.

### Nạp bằng cmd

```bat
mysql -u root -p --default-character-set=utf8mb4 < TV1_1.1_create_tables_triggers.sql
mysql -u root -p --default-character-set=utf8mb4 < TV2_2.2.2_trigger_TotalAmount.sql
mysql -u root -p --default-character-set=utf8mb4 < TV2_napdulieu.sql
mysql -u root -p --default-character-set=utf8mb4 < TV3_2.1_thu_tuc_PRODUCT.sql
```

## 2. Cấu hình & chạy

```bat
cd app
npm install
copy .env.example .env
```

Mở `.env`, sửa `DB_USER`, `DB_PASSWORD`, `DB_PORT` cho đúng máy. Sau đó:

```bat
npm start
```

Mở http://localhost:3000.

> Nếu service MySQL đang **Stopped**, bật trước khi chạy:
> `Start-Service MySQL80` (PowerShell với quyền Administrator), hoặc mở Services.

Chế độ tự khởi động lại khi sửa code: `npm run dev`.

## 3. Chức năng màn hình 3.1

- **Thêm** (kênh người bán, cửa hàng lấy theo tài khoản): chọn danh mục lá, nhập tên/mô tả/trạng thái → gọi `sp_product_them`.
- **Sửa**: bấm “Sửa” trên một dòng → form nạp dữ liệu → gọi `sp_product_sua`.
- **Xóa**: bấm “Xóa” → modal xác nhận → gọi `sp_product_xoa`.
- Validate 2 lớp:
  - Trình duyệt: bắt buộc, độ dài, trạng thái, đánh dấu ô lỗi.
  - Server: kiểm tra lại trước khi gọi thủ tục.
  - CSDL (thủ tục + trigger câu 1.1): cửa hàng, danh mục lá, trùng tên, lịch sử đơn, giỏ hàng, BANNED…
- Lỗi nghiệp vụ hiển thị nguyên văn thông báo `SIGNAL` từ MySQL (ví dụ:
  “Không thể xóa sản phẩm 1: đã phát sinh đơn hàng…”), không phải thông báo chung chung.
- Thành công dùng PRG (redirect + `?ok=...`) nên F5 không gửi lại form.

### Bảng chức năng → thủ tục

| Thao tác | Route | Thủ tục |
|---|---|---|
| Thêm | `POST /seller/products` | `sp_product_them(..., OUT ProductID)` |
| Sửa | `POST /seller/products/:id` | `sp_product_sua(...)` |
| Xóa | `POST /seller/products/:id/delete` | `sp_product_xoa(...)` |
| Mở form sửa | `GET /seller/products/:id/edit` | SELECT để nạp dữ liệu |

## 4. Kịch bản demo (dùng khi báo cáo)

Có thể demo trực tiếp trên giao diện:

1. **Thêm hợp lệ**: shop `Lan Fashion`, danh mục `Thời trang › Áo nam › Áo thun nam`, tên mới, trạng thái `Tạm ẩn` → thành công.
2. **Trùng tên**: thêm “Áo thun nam cotton basic” vào shop 1 → lỗi “Cửa hàng đã có sản phẩm cùng tên…”.
3. **Danh mục cha**: chọn `Thời trang` (không phải lá) → lỗi “còn danh mục con”.
4. **Sửa sản phẩm đã bán**: sửa sản phẩm #1/#4 và đổi cửa hàng → lỗi “đã phát sinh đơn hàng, không được đổi cửa hàng”.
5. **Xóa sản phẩm đã bán**: xóa #1 → lỗi, hướng dẫn chuyển INACTIVE/HIDDEN.
6. **BANNED**: sửa #10 → chuyển `BANNED`; sau đó thử sửa lại → lỗi “đã bị BANNED, không được phép sửa”.
7. **Xóa hợp lệ**: xóa #10 (Tai nghe chụp tai Studio Pro — chưa bán, không có trong giỏ) → thành công.

Kịch bản SQL tương ứng (chạy trong transaction, có `ROLLBACK`):

```bat
mysql -u root -p --default-character-set=utf8mb4 --force < TV3_demo_test_thu_tuc.sql
```

`--force` cần thiết để mysql tiếp tục sau các lệnh cố ý gây lỗi.

## 5. Ghi chú cho TV4 / TV5

- Ứng dụng đã tách lớp: `productRepository.js` là nơi duy nhất gọi thủ tục.
  Khi TV4 hoàn thành 2 thủ tục câu 2.3, chỉ cần thêm hàm gọi procedure vào file này
  và dùng cho màn hình danh sách 3.2.
- Bảng đã chọn cho câu 2.1 là `PRODUCT`; các thủ tục câu 2.3 cần có ít nhất 1 thủ tục
  liên quan `PRODUCT` (theo yêu cầu đề).
- Database mặc định: `shopee_db`; mật khẩu để trong `.env` (không hard-code).
- Nếu đổi cổng web: sửa `PORT` trong `.env`.

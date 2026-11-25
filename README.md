# Shopee DBMS — BTL2 Hệ cơ sở dữ liệu

Mô phỏng cơ sở dữ liệu của một sàn thương mại điện tử (người mua, người bán, cửa hàng, sản phẩm, đơn hàng, thanh toán, vận chuyển, đánh giá, khiếu nại) trên **MySQL 8**. Kèm một ứng dụng web **Node.js + Express** có 3 kênh: **người mua**, **người bán** và **quản trị**. Mọi thao tác thêm/sửa/xóa sản phẩm và mọi truy vấn báo cáo trong ứng dụng đều gọi thủ tục và trigger của CSDL.

## Nội dung theo thành viên

| Thành viên | File | Nội dung |
|---|---|---|
| TV1 | `TV1_1.1_create_tables_triggers.sql` | Tạo database `shopee_db`, các bảng, ràng buộc `CHECK`/`UNIQUE`/khóa ngoại và trigger nghiệp vụ (vai trò người dùng, người bán đã xác minh mới mở shop, cây danh mục không có chu trình, tồn kho, voucher, đơn hàng, thanh toán, vận chuyển, đánh giá, khiếu nại) |
| | `TV1_demo_test_constraints.sql` | Kịch bản kiểm tra các ràng buộc |
| TV2 | `TV2_2.2.2_trigger_TotalAmount.sql` | Trigger tự tính `TotalAmount` của đơn hàng |
| | `TV2_napdulieu.sql` | Dữ liệu mẫu |
| TV3 | `TV3_2.1_thu_tuc_PRODUCT.sql` | Câu 2.1: thủ tục `sp_product_them`, `sp_product_sua`, `sp_product_xoa` |
| | `TV3_demo_test_thu_tuc.sql` | Kịch bản demo câu 2.1 (chạy trong transaction, cuối file `ROLLBACK`) |
| | `app/` | Câu 3.1: giao diện thêm/sửa/xóa sản phẩm (nay thuộc kênh người bán) |
| TV4 | `TV4_2.2.1_trigger_category_leaf.sql` | Câu 2.2.1: sản phẩm chỉ được gắn với **danh mục lá** (trigger trên `PRODUCT` và `CATEGORY`) |
| | `TV4_2.3_thu_tuc_truy_van.sql` | Câu 2.3: `sp_tv4_tim_kiem_san_pham`, `sp_tv4_thong_ke_ton_kho` |

## Cấu trúc thư mục

```
.
├── TV1_*.sql, TV2_*.sql, TV3_*.sql, TV4_*.sql   # script CSDL (xem thứ tự nạp bên dưới)
└── app/                                          # ứng dụng web
    ├── server.js              # khởi tạo Express, session, gắn 3 kênh
    ├── db.js                  # pool kết nối MySQL (đọc .env)
    ├── helpers.js             # định dạng, hằng số, validate
    ├── productRepository.js   # gọi thủ tục TV3 + TV4
    ├── accountRepository.js   # đăng ký, đăng nhập, cửa hàng, duyệt người bán
    ├── routes/                # auth · buyer · seller · admin · reports
    ├── views/                 # giao diện EJS
    ├── public/                # CSS, JS phía trình duyệt
    ├── scripts/seed-demo.js   # đặt mật khẩu cho tài khoản demo
    └── .env.example           # file cấu hình mẫu
```

## Yêu cầu

- **MySQL 8.0.16+** (cần `CHECK`, functional index, `SIGNAL`)
- **Node.js 18+**

## 1. Nạp cơ sở dữ liệu

Chạy **theo đúng thứ tự**:

| # | File |
|---|---|
| 1 | `TV1_1.1_create_tables_triggers.sql` |
| 2 | `TV2_2.2.2_trigger_TotalAmount.sql` |
| 3 | `TV2_napdulieu.sql` |
| 4 | `TV3_2.1_thu_tuc_PRODUCT.sql` |
| 5 | `TV4_2.2.1_trigger_category_leaf.sql` (phải chạy sau file 1 vì dùng `FOLLOWS trg_category_bi`) |
| 6 | `TV4_2.3_thu_tuc_truy_van.sql` |

**PowerShell** (tại thư mục gốc của repo):

```powershell
$mysql = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
foreach ($f in "TV1_1.1_create_tables_triggers.sql", "TV2_2.2.2_trigger_TotalAmount.sql",
               "TV2_napdulieu.sql", "TV3_2.1_thu_tuc_PRODUCT.sql",
               "TV4_2.2.1_trigger_category_leaf.sql", "TV4_2.3_thu_tuc_truy_van.sql") {
  Get-Content -Encoding UTF8 $f | & $mysql -u root -p --default-character-set=utf8mb4
}
```

**cmd**: `mysql -u root -p --default-character-set=utf8mb4 < TEN_FILE.sql` cho từng file.

**MySQL Workbench**: mở từng file → ⚡ **Execute all** (Ctrl+Shift+Enter).

> ⚠️ **Không dùng extension SQL của VS Code để chạy các file có `DELIMITER $$`** (thủ tục, trigger). Extension tách câu lệnh theo dấu `;`, nên thân thủ tục bị cắt và báo lỗi `near '' at line …` ở dòng `END$$`. Extension chỉ nên dùng cho câu đơn như `SELECT`, `CALL`, `SHOW`.

Kiểm tra sau khi nạp:

```sql
SHOW PROCEDURE STATUS WHERE Db = 'shopee_db';
SHOW TRIGGERS FROM shopee_db;
```

## 2. Chạy ứng dụng web

```powershell
cd app
npm install
copy .env.example .env      # rồi sửa DB_USER, DB_PASSWORD, DB_PORT cho đúng máy
npm run seed-demo           # đặt mật khẩu cho các tài khoản demo (chạy 1 lần sau khi nạp dữ liệu)
npm start
```

Mở <http://localhost:3000>. Chế độ tự khởi động lại khi sửa code: `npm run dev`.

> File `.env` chứa mật khẩu MySQL nên **không được đưa lên Git**. Repo chỉ có file mẫu `app/.env.example`.

### Tài khoản demo

Mật khẩu trong `TV2_napdulieu.sql` là chuỗi băm giả, nên không đăng nhập được. Lệnh `npm run seed-demo` đặt mật khẩu **`123456`** cho:

| Email | Vai trò |
|---|---|
| `an.nguyen@gmail.com` | Người mua |
| `khang.hoang@gmail.com` | Người bán (shop Khang Tech) |
| `lan.bui@gmail.com` | Người mua + người bán (hiện trang chọn kênh) |
| `phuc.truong@gmail.com` | Người bán đang chờ xác minh |
| `son.phan@shopee-admin.vn` | Quản trị |

Có thể đăng nhập bằng email hoặc số điện thoại.

## 3. Ba kênh trong ứng dụng

Đăng ký tại `/register` (chọn **Người mua** hoặc **Người bán**), đăng nhập tại `/login`. Vai trò được xác định bằng việc `UserID` có mặt trong bảng `BUYER`, `SELLER` hay `ADMIN`. Một người có thể giữ nhiều vai trò. Tài khoản quản trị không tự đăng ký được.

| Kênh | Chức năng | Thủ tục / trigger được dùng |
|---|---|---|
| **Người mua** `/buyer` | Tìm sản phẩm đang bán (chỉ sản phẩm `ACTIVE` của shop `ACTIVE`/`WARNED`) | `sp_tv4_tim_kiem_san_pham` |
| **Người bán** `/seller` | Thêm / sửa / xóa sản phẩm **của shop mình** | `sp_product_them`, `sp_product_sua`, `sp_product_xoa` + trigger danh mục lá (TV4) |
| | Tìm kiếm, thống kê tồn kho của shop | `sp_tv4_tim_kiem_san_pham`, `sp_tv4_thong_ke_ton_kho` |
| | Mở cửa hàng (chỉ khi đã được xác minh) | trigger `trg_shop_bi` (TV1) |
| **Quản trị** `/admin` | Kiểm duyệt toàn sàn, gỡ sản phẩm vi phạm (`BANNED`) | `sp_tv4_tim_kiem_san_pham`, `sp_product_sua` |
| | Thống kê tồn kho toàn sàn | `sp_tv4_thong_ke_ton_kho` |
| | Duyệt người bán (`PENDING` → `VERIFIED` / `REJECTED`) | `UPDATE SELLER` |

Quy tắc phân quyền ở tầng ứng dụng:

- Mã cửa hàng của người bán luôn lấy từ tài khoản đăng nhập. Người bán không thao tác được trên sản phẩm của shop khác.
- Người bán không tự đặt trạng thái `BANNED`. Đó là quyết định của quản trị và là trạng thái cuối.
- Mật khẩu được băm bằng bcrypt trước khi lưu vào `USER.PasswordHash`.
- Lỗi nghiệp vụ được hiển thị đúng nguyên văn thông báo `SIGNAL` của MySQL.

### Kịch bản demo nhanh

1. Đăng nhập `phuc.truong@gmail.com`: người bán chưa xác minh nên không mở được cửa hàng.
2. Đăng nhập `son.phan@shopee-admin.vn` → **Duyệt người bán** → xác minh người bán #12.
3. Đăng nhập lại `phuc.truong@gmail.com` → mở cửa hàng → thêm sản phẩm. Chọn danh mục không phải lá sẽ bị trigger của TV4 chặn.
4. Quản trị **gỡ** sản phẩm đó: người bán không sửa được nữa, người mua không còn thấy sản phẩm.

## 4. Kịch bản kiểm thử SQL

```powershell
Get-Content -Encoding UTF8 TV1_demo_test_constraints.sql | & $mysql -u root -p --force
Get-Content -Encoding UTF8 TV3_demo_test_thu_tuc.sql     | & $mysql -u root -p --force
```

`--force` giúp chạy tiếp sau các câu cố ý gây lỗi để minh họa ràng buộc.

## Truy cập từ máy khác

Server nghe trên mọi card mạng. Máy cùng mạng LAN/Wi-Fi vào được qua `http://<IP-máy-chạy>:3000`, với điều kiện đã mở cổng 3000 trên Windows Firewall. Tài khoản demo dùng mật khẩu đơn giản, nên chỉ mở ra ngoài trong lúc demo.

Xem thêm chi tiết về ứng dụng tại [`app/README.md`](app/README.md).

TV3 - BTL2 HỆ CSDL
==================

1. NỘI DUNG
-----------
- TV3_2.1_thu_tuc_PRODUCT.sql : 3 thủ tục thêm/sửa/xóa bảng PRODUCT
- TV3_demo_test_thu_tuc.sql   : kịch bản demo câu 2.1 (có ROLLBACK)
- app/                        : web 3.1 (thêm/sửa/xóa sản phẩm)
- TV1_..., TV2_...            : file của nhóm, kèm theo để chạy được demo

2. THỨ TỰ NẠP SQL
-----------------
1) TV1_1.1_create_tables_triggers.sql
2) TV2_2.2.2_trigger_TotalAmount.sql
3) TV2_napdulieu.sql
4) TV3_2.1_thu_tuc_PRODUCT.sql

3. CHẠY WEB
-----------
cd app
npm install
copy .env.example .env
:: sửa DB_USER, DB_PASSWORD, DB_PORT trong .env
npm start
Mở http://localhost:3000

4. DEMO SQL
-----------
mysql -u root -p --default-character-set=utf8mb4 --force < TV3_demo_test_thu_tuc.sql

5. LƯU Ý
---------
- Cần MySQL 8.0.16+ và Node.js 18+.
- Gói không chứa .env (tránh lộ mật khẩu); tạo từ .env.example.
- Bảng của câu 2.1: PRODUCT.
- Thủ tục: sp_product_them, sp_product_sua, sp_product_xoa.

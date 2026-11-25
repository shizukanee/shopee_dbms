-- Demo câu 2.1: thủ tục PRODUCT
-- Chạy: mysql ... --force < TV3_demo_test_thu_tuc.sql
SET NAMES utf8mb4;
USE shopee_db;
START TRANSACTION;

SELECT 'Dữ liệu trước khi thử' AS thong_bao;
SELECT ProductID, ShopID, CategoryID, ProductName, ProductStatus
  FROM PRODUCT ORDER BY ProductID;

-- - ADD PRODUCT
SELECT '1.1 Thêm hợp lệ' AS buoc;
CALL sp_product_them(1, 13, 'Áo thun nam test TV3',
                     'Sản phẩm được tạo bởi thủ tục sp_product_them',
                     'HIDDEN', @new_id);
SELECT @new_id AS san_pham_vua_tao;
SELECT ProductID, ShopID, CategoryID, ProductName, ProductStatus, PostedDate
  FROM PRODUCT WHERE ProductID = @new_id;

SELECT '1.2 Lỗi: trùng tên trong cùng cửa hàng' AS buoc;
CALL sp_product_them(1, 13, 'Áo thun nam cotton basic', NULL, 'ACTIVE', @x);

SELECT '1.3 Lỗi: chọn danh mục cha' AS buoc;
CALL sp_product_them(1, 1, 'Sản phẩm thuộc danh mục cha', NULL, 'ACTIVE', @x);

SELECT '1.4 Lỗi: tên sản phẩm rỗng' AS buoc;
CALL sp_product_them(1, 13, '    ', NULL, 'ACTIVE', @x);

SELECT '1.5 Lỗi: cửa hàng không tồn tại' AS buoc;
CALL sp_product_them(999, 13, 'Sản phẩm của shop lạ', NULL, 'ACTIVE', @x);

SELECT '1.6 Lỗi: tạo mới với trạng thái BANNED' AS buoc;
CALL sp_product_them(1, 13, 'Sản phẩm vi phạm', NULL, 'BANNED', @x);

-- - UPDATE PRODUCT
SELECT '2.1 Sửa hợp lệ sản phẩm vừa tạo' AS buoc;
CALL sp_product_sua(@new_id, 1, 13, 'Áo thun nam test TV3 (đã sửa)',
                    'Mô tả sau khi sửa', 'ACTIVE');
SELECT ProductID, ProductName, Description, ProductStatus
  FROM PRODUCT WHERE ProductID = @new_id;

SELECT '2.2 Lỗi: đổi cửa hàng của sản phẩm đã bán' AS buoc;
CALL sp_product_sua(4, 1, 9, 'Cáp sạc nhanh USB-C 1m', NULL, 'ACTIVE');

SELECT '2.3 Đổi cửa hàng hợp lệ: sản phẩm 10 chưa bán' AS buoc;
CALL sp_product_sua(10, 1, 8, 'Tai nghe chụp tai Studio Pro', NULL, 'INACTIVE');
SELECT ProductID, ShopID, ProductName, ProductStatus FROM PRODUCT WHERE ProductID = 10;

SELECT '2.4 Lỗi: đổi tên trùng trong cùng cửa hàng' AS buoc;
CALL sp_product_sua(@new_id, 1, 13, 'Áo thun nam cotton basic', NULL, 'ACTIVE');

SELECT '2.5 Lỗi: sản phẩm không tồn tại' AS buoc;
CALL sp_product_sua(999, 1, 13, 'Không có sản phẩm này', NULL, 'ACTIVE');

SELECT '2.6 Chuyển sản phẩm vừa tạo sang BANNED' AS buoc;
CALL sp_product_sua(@new_id, 1, 13, 'Áo thun nam test TV3 (đã sửa)', NULL, 'BANNED');
SELECT ProductID, ProductName, ProductStatus FROM PRODUCT WHERE ProductID = @new_id;

SELECT '2.7 Lỗi: sửa sản phẩm đã BANNED' AS buoc;
CALL sp_product_sua(@new_id, 1, 13, 'Sửa sau khi bị BANNED', NULL, 'ACTIVE');

-- - DELETE PRODUCT
SELECT '3.1 Lỗi: xóa sản phẩm đã phát sinh đơn hàng' AS buoc;
CALL sp_product_xoa(1);

SELECT '3.2 Lỗi: xóa sản phẩm đang có trong giỏ hàng' AS buoc;
INSERT INTO CART_ITEM (CartID, ProductID, VariantID, Quantity) VALUES (5, 10, 1, 1);
CALL sp_product_xoa(10);
DELETE FROM CART_ITEM WHERE CartID = 5 AND ProductID = 10;

SELECT '3.3 Xóa hợp lệ sản phẩm 10' AS buoc;
CALL sp_product_xoa(10);
SELECT COUNT(*) AS con_lai_san_pham_10 FROM PRODUCT WHERE ProductID = 10;

SELECT '3.4 Lỗi: xóa lại sản phẩm 10 vừa xóa' AS buoc;
CALL sp_product_xoa(10);

SELECT 'Kiểm tra sau khi rollback' AS thong_bao;
ROLLBACK;

SELECT COUNT(*) AS so_san_pham FROM PRODUCT;
SELECT COUNT(*) AS con_san_pham_10 FROM PRODUCT WHERE ProductID = 10;
SELECT COUNT(*) AS san_pham_test_con_lai
  FROM PRODUCT WHERE ProductName LIKE 'Áo thun nam test TV3%';

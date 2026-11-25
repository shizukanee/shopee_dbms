-- Active: 1795604678545@@127.0.0.1@3306@shopee_db
SET NAMES utf8mb4;
USE shopee_db;
START TRANSACTION;

-- ---------- Dữ liệu nền ----------
INSERT INTO `USER` (UserID, Email, Phone, LastName, MiddleName, FirstName, PasswordHash) VALUES
 (901,'an.nguyen.demo@gmail.com' ,'0901000001','Nguyễn','Văn','An'   ,'$2b$10$hashAn'),
 (902,'binh.tran.demo@gmail.com' ,'0901000002','Trần' ,'Thị','Bình' ,'$2b$10$hashBinh'),
 (903,'cuong.le.demo@gmail.com'  ,'0901000003','Lê'   ,'Minh','Cường','$2b$10$hashCuong'),
 (904,'dung.pham.demo@gmail.com' ,'0901000004','Phạm' ,NULL ,'Dung' ,'$2b$10$hashDung'),
 (905,'em.hoang.demo@shopee.vn'  ,'0901000005','Hoàng','Gia','Em'   ,'$2b$10$hashEm');
-- [LỖI] email sai định dạng (CHECK ck_user_email)
INSERT INTO `USER` (Email, Phone, LastName, FirstName, PasswordHash) VALUES ('abc@', '0901000099', 'Test', 'A', 'x');
-- [LỖI] số điện thoại sai định dạng (CHECK ck_user_phone)
INSERT INTO `USER` (Email, Phone, LastName, FirstName, PasswordHash) VALUES ('ok@gmail.com', '12345', 'Test', 'A', 'x');

INSERT INTO BUYER  (UserID, MembershipTier, RewardPoints) VALUES (901,'GOLD',1200), (902,'BRONZE',0);
INSERT INTO SELLER (UserID, TaxCode, VerifiedDate, VerificationStatus) VALUES
 (903,'0312345678','2025-03-01','VERIFIED'), (904,NULL,NULL,'PENDING');
INSERT INTO `ADMIN` (UserID, EmployeeID, HireDate, AdminLevel) VALUES (905,'AD001','2024-06-01',2);
-- [LỖI] VERIFIED nhưng thiếu ngày xác minh (CHECK ck_seller_verified)
UPDATE SELLER SET VerificationStatus = 'VERIFIED' WHERE UserID = 904;

-- ---------- RB1: chuyên biệt hóa toàn phần ----------
-- [LỖI] 902 chỉ có vai trò BUYER -> không được xóa vai trò cuối cùng
DELETE FROM BUYER WHERE UserID = 902;

-- ---------- RB2: chỉ người bán đã xác minh mới tạo cửa hàng ----------
INSERT INTO SHOP (ShopID, SellerID, ShopName, Address) VALUES (901, 903, 'Cường Fashion', '12 Lý Thường Kiệt, Q.10, TP.HCM');
-- [LỖI] người bán 904 đang PENDING
INSERT INTO SHOP (SellerID, ShopName, Address) VALUES (904, 'Dung Store', '1 Lê Lợi, Q.1');
-- [LỖI] người bán 903 đã có cửa hàng (UNIQUE uq_shop_seller)
INSERT INTO SHOP (SellerID, ShopName, Address) VALUES (903, 'Shop thứ hai', '2 Lê Lợi, Q.1');

-- ---------- Địa chỉ: tối đa 1 địa chỉ mặc định ----------
INSERT INTO ADDRESS (AddressID, BuyerID, RecipientName, Phone, DetailAddress, Ward, Province, IsDefault) VALUES
 (901, 901, 'Nguyễn Văn An', '0901000001', '268 Lý Thường Kiệt', 'Phường Diên Hồng', 'TP. Hồ Chí Minh', TRUE),
 (902, 901, 'Nguyễn Văn An', '0901000001', 'KTX Khu A', 'Phường Đông Hòa', 'TP. Hồ Chí Minh', FALSE),
 (903, 902, 'Trần Thị Bình', '0901000002', '5 Nguyễn Huệ', 'Phường Sài Gòn', 'TP. Hồ Chí Minh', TRUE);
-- [LỖI] người mua 901 đã có địa chỉ mặc định (UNIQUE uq_address_default)
UPDATE ADDRESS SET IsDefault = TRUE WHERE AddressID = 902;

-- ---------- RB3: cây danh mục không có chu trình ----------
INSERT INTO CATEGORY (CategoryID, CategoryName, ParentCategoryID) VALUES
 (901, 'Thời trang (demo)', NULL), (902, 'Áo (demo)', 901), (903, 'Áo thun (demo)', 902), (904, 'Điện tử (demo)', NULL);
-- [LỖI] tự làm cha của chính nó
UPDATE CATEGORY SET ParentCategoryID = 901 WHERE CategoryID = 901;
-- [LỖI] 901 -> 903 -> 902 -> 901 tạo chu trình
UPDATE CATEGORY SET ParentCategoryID = 903 WHERE CategoryID = 901;

-- ---------- Sản phẩm, phân loại ----------
INSERT INTO PRODUCT (ProductID, ShopID, CategoryID, ProductName) VALUES
 (901, 901, 903, 'Áo thun cotton basic'),
 (902, 901, 904, 'Tai nghe Bluetooth');
INSERT INTO PRODUCT_IMAGE VALUES (901, 'https://cdn.example.com/ao-thun-1.jpg');
INSERT INTO PRODUCT_VARIANT (ProductID, VariantID, Color, Size, Price, StockQuantity) VALUES
 (901, 1, 'Trắng', 'M', 150000, 10),
 (901, 2, 'Đen',   'L', 160000,  5),
 (902, 1, NULL,   NULL, 500000,  3);
-- [LỖI] trùng tổ hợp (Trắng, M) trong cùng sản phẩm
INSERT INTO PRODUCT_VARIANT VALUES (901, 3, 'Trắng', 'M', 155000, 1);
-- [LỖI] giá bán phải > 0
INSERT INTO PRODUCT_VARIANT VALUES (901, 4, 'Xanh', 'S', 0, 1);
-- [LỖI] RB4: không xóa phân loại cuối cùng của sản phẩm 902
DELETE FROM PRODUCT_VARIANT WHERE ProductID = 902 AND VariantID = 1;

-- ---------- Voucher ----------
INSERT INTO VOUCHER (VoucherID, Code, DiscountType, DiscountValue, MinOrderValue, StartTime, EndTime, MaxUsage) VALUES
 (901, 'DEMO10',  'PERCENT', 10, 200000, '2026-01-01', '2026-12-31 23:59:59', 1),
 (902, 'DEMOTET', 'FIXED', 50000,     0, '2025-01-01', '2025-02-28 23:59:59', 100);
-- [LỖI] giảm theo % vượt 100
INSERT INTO VOUCHER (Code, DiscountType, DiscountValue, StartTime, EndTime, MaxUsage) VALUES ('X', 'PERCENT', 120, NOW(), NOW(), 1);

-- ---------- RB5, RB6: tạo đơn hàng ----------
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, ShippingFeeAtOrder)
VALUES (901, 901, 901, 901, 901, '2026-11-20 10:00:00', 15000);
SELECT OrderID, RecipientName, DetailAddress, Province FROM `ORDER` WHERE OrderID = 901;  -- địa chỉ đã được sao lưu
-- [LỖI] dùng địa chỉ 903 của người mua khác
INSERT INTO `ORDER` (BuyerID, ShopID, AddressID) VALUES (901, 901, 903);
-- [LỖI] voucher DEMOTET đã hết hạn
INSERT INTO `ORDER` (BuyerID, ShopID, AddressID, VoucherID) VALUES (902, 901, 903, 902);
-- [LỖI] voucher DEMO10 chỉ có 1 lượt, đã dùng cho đơn 901
INSERT INTO `ORDER` (BuyerID, ShopID, AddressID, VoucherID) VALUES (902, 901, 903, 901);
-- [LỖI] đơn mới phải PENDING
INSERT INTO `ORDER` (BuyerID, ShopID, AddressID, OrderStatus) VALUES (902, 901, 903, 'COMPLETED');

-- ---------- RB8: chi tiết đơn hàng ----------
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice)
VALUES (901, NULL, 901, 1, 2, 1);      -- UnitPrice truyền sai (1) -> trigger lấy giá thật 150000, ItemID tự = 1
SELECT OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice FROM ORDER_ITEM WHERE OrderID = 901;
SELECT ProductID, VariantID, StockQuantity FROM PRODUCT_VARIANT WHERE ProductID = 901;  -- tồn kho (901,1): 10 -> 8
-- [LỖI] không đủ tồn kho
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES (901, NULL, 901, 2, 100, 0);
-- Tạo thêm cửa hàng thứ 2 để thử sản phẩm khác cửa hàng
INSERT INTO `USER` (UserID, Email, Phone, LastName, FirstName, PasswordHash) VALUES (906,'phuc.vo.demo@gmail.com','0901000006','Võ','Phúc','$2b$10$x');
INSERT INTO SELLER (UserID, VerifiedDate, VerificationStatus) VALUES (906, '2025-05-05', 'VERIFIED');
INSERT INTO SHOP (ShopID, SellerID, ShopName, Address) VALUES (902, 906, 'Phúc Tech', '3 Võ Văn Tần, Q.3');
INSERT INTO PRODUCT (ProductID, ShopID, CategoryID, ProductName) VALUES (903, 902, 904, 'Chuột không dây');
INSERT INTO PRODUCT_VARIANT VALUES (903, 1, 'Đen', NULL, 200000, 20);
-- [LỖI] sản phẩm 903 thuộc cửa hàng 902, không thuộc cửa hàng 901 của đơn 901
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES (901, NULL, 903, 1, 1, 0);

-- ---------- RB6, RB7: xác nhận đơn ----------
-- [LỖI] giảm 50.000 > 10% của 300.000
UPDATE `ORDER` SET AppliedDiscountAmount = 50000, OrderStatus = 'CONFIRMED' WHERE OrderID = 901;
UPDATE `ORDER` SET AppliedDiscountAmount = 30000, OrderStatus = 'CONFIRMED' WHERE OrderID = 901;  -- hợp lệ
-- [LỖI] đơn đã xác nhận: không sửa chi tiết đơn
UPDATE ORDER_ITEM SET Quantity = 3 WHERE OrderID = 901 AND ItemID = 1;
-- [LỖI] đơn đã xác nhận: không đổi tiền giảm / phí ship
UPDATE `ORDER` SET ShippingFeeAtOrder = 0 WHERE OrderID = 901;
-- [LỖI] không lùi trạng thái
UPDATE `ORDER` SET OrderStatus = 'PENDING' WHERE OrderID = 901;

-- ---------- RB9: thanh toán ----------
-- [LỖI] số tiền SUCCESS phải = 300.000 + 15.000 - 30.000 = 285.000
INSERT INTO PAYMENT (OrderID, Method, Amount, PaymentStatus) VALUES (901, 'E_WALLET', 300000, 'SUCCESS');
INSERT INTO PAYMENT (OrderID, Method, Amount, PaymentStatus) VALUES (901, 'E_WALLET', 285000, 'FAILED');
INSERT INTO PAYMENT (OrderID, Method, Amount, PaymentStatus) VALUES (901, 'E_WALLET', 285000, 'SUCCESS');
-- [LỖI] đơn chỉ có tối đa 1 giao dịch SUCCESS (UNIQUE uq_payment_success)
INSERT INTO PAYMENT (OrderID, Method, Amount, PaymentStatus) VALUES (901, 'BANK_TRANSFER', 285000, 'SUCCESS');

-- ---------- RB10: vận chuyển ----------
UPDATE `ORDER` SET OrderStatus = 'PREPARING' WHERE OrderID = 901;
-- [LỖI] ngày giao thực tế trước ngày đặt hàng
INSERT INTO SHIPMENT (OrderID, TrackingNumber, Carrier, ShippingFee, EstimatedDate, ActualDate, ShipmentStatus)
VALUES (901, 'SPXVN000901', 'SPX Express', 15000, '2026-11-25', '2026-11-19 08:00:00', 'DELIVERED');
INSERT INTO SHIPMENT (OrderID, TrackingNumber, Carrier, ShippingFee, EstimatedDate)
VALUES (901, 'SPXVN000901', 'SPX Express', 15000, '2026-11-25');
UPDATE `ORDER` SET OrderStatus = 'SHIPPING' WHERE OrderID = 901;
-- [LỖI] đơn đã bàn giao vận chuyển không được hủy
UPDATE `ORDER` SET OrderStatus = 'CANCELLED' WHERE OrderID = 901;
-- [LỖI] DELIVERED mà thiếu ngày giao thực tế (CHECK ck_shipment_delivered)
UPDATE SHIPMENT SET ShipmentStatus = 'DELIVERED' WHERE OrderID = 901;
UPDATE SHIPMENT SET ShipmentStatus = 'DELIVERED', ActualDate = '2026-11-23 15:30:00' WHERE OrderID = 901;

-- ---------- RB11: đánh giá ----------
-- [LỖI] đơn chưa hoàn thành
INSERT INTO REVIEW (OrderID, ItemID, BuyerID, Rating, Comment) VALUES (901, 1, 901, 5, 'Áo đẹp');
UPDATE `ORDER` SET OrderStatus = 'COMPLETED' WHERE OrderID = 901;
-- [LỖI] người mua 902 không phải chủ đơn 901 (FK ghép fk_review_orderowner)
INSERT INTO REVIEW (OrderID, ItemID, BuyerID, Rating, Comment) VALUES (901, 1, 902, 1, 'Spam');
-- [LỖI] số sao ngoài 1..5
INSERT INTO REVIEW (OrderID, ItemID, BuyerID, Rating, Comment) VALUES (901, 1, 901, 6, 'Quá tốt');
INSERT INTO REVIEW (OrderID, ItemID, BuyerID, Rating, Comment) VALUES (901, 1, 901, 5, 'Áo đẹp, vải mát');

-- ---------- Hủy đơn -> hoàn kho ----------
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, OrderDate) VALUES (902, 902, 901, 903, '2026-11-21 09:00:00');
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES (902, NULL, 901, 2, 4, 0);
SELECT ProductID, VariantID, StockQuantity AS ton_kho_sau_dat FROM PRODUCT_VARIANT WHERE ProductID = 901 AND VariantID = 2;  -- 5 -> 1
UPDATE `ORDER` SET OrderStatus = 'CANCELLED' WHERE OrderID = 902;
SELECT ProductID, VariantID, StockQuantity AS ton_kho_sau_huy FROM PRODUCT_VARIANT WHERE ProductID = 901 AND VariantID = 2;  -- 1 -> 5
-- [LỖI] đơn đã hủy không thể mở lại
UPDATE `ORDER` SET OrderStatus = 'CONFIRMED' WHERE OrderID = 902;
-- [LỖI] không tạo vận chuyển cho đơn đã hủy
INSERT INTO SHIPMENT (OrderID, TrackingNumber, Carrier) VALUES (902, 'SPXVN000902', 'SPX Express');
-- [LỖI] không thanh toán thành công cho đơn đã hủy
INSERT INTO PAYMENT (OrderID, Method, Amount, PaymentStatus) VALUES (902, 'COD', 640000, 'SUCCESS');

-- ---------- RB12: khiếu nại ----------
-- [LỖI] chưa phân công admin mà đã PROCESSING (CHECK ck_complaint_assign)
INSERT INTO COMPLAINT (BuyerID, OrderID, ComplaintType, Content, Status) VALUES (901, 901, 'DAMAGED', 'Áo bị rách', 'PROCESSING');
-- [LỖI] gửi trước thời điểm đặt hàng
INSERT INTO COMPLAINT (BuyerID, OrderID, ComplaintType, Content, SubmitTime) VALUES (901, 901, 'DAMAGED', 'Áo bị rách', '2026-11-01');
INSERT INTO COMPLAINT (ComplaintID, BuyerID, OrderID, ComplaintType, Content, SubmitTime)
VALUES (901, 901, 901, 'DAMAGED', 'Áo bị rách ở tay', '2026-11-24 08:00:00');
-- [LỖI] RESOLVED nhưng chưa có kết quả / thời gian hoàn tất
UPDATE COMPLAINT SET AdminID = 905, Status = 'RESOLVED' WHERE ComplaintID = 901;
UPDATE COMPLAINT SET AdminID = 905, Status = 'RESOLVED', Resolution = 'Hoàn tiền 150.000đ',
                     ResolvedTime = '2026-11-24 17:00:00' WHERE ComplaintID = 901;
-- [LỖI] khiếu nại đã đóng không được sửa
UPDATE COMPLAINT SET Content = 'Sửa lại' WHERE ComplaintID = 901;

-- ---------- Xóa đơn ----------
-- [LỖI] đơn đã hoàn thành phải giữ lịch sử
DELETE FROM `ORDER` WHERE OrderID = 901;
-- [LỖI] MaxUsage nhỏ hơn số lượt đã dùng (1)
UPDATE VOUCHER SET MaxUsage = 0 WHERE VoucherID = 901;

ROLLBACK;

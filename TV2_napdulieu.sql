-- =====================================================================
-- BTL2 HỆ CSDL - CÂU 1.2: DỮ LIỆU MẪU (MySQL 8, CSDL shopee_db)
-- Chạy SAU script 1.1 của TV1 (TV1_1.1_create_tables_triggers.sql).
--
-- Muốn nạp lại từ đầu: chạy lại script 1.1 (script đó DROP DATABASE rồi tạo lại),
-- sau đó chạy file này. Không dùng DELETE vì các trigger của 1.1 chặn xóa
-- đơn hàng đã giao dịch và chặn xóa vai trò cuối cùng của người dùng.
--
-- Script được viết để ĐI QUA tất cả trigger của câu 1.1, nên thứ tự là:
--   1. Đơn hàng mới luôn tạo ở trạng thái PENDING (trg_order_bi).
--   2. Thêm chi tiết đơn khi đơn còn PENDING; trigger tự lấy đơn giá = giá
--      hiện tại của phân loại và tự trừ tồn kho (trg_orderitem_bi).
--   3. Ghi thanh toán, rồi mới chuyển trạng thái đơn.
--   4. Vận chuyển chỉ tạo khi đơn đã rời PENDING; đánh giá chỉ khi COMPLETED.
--   Đơn hàng được nạp theo thứ tự thời gian, và giá phân loại được cập nhật
--   giữa các đơn để minh họa "bảo toàn đơn giá lúc mua".
-- =====================================================================
SET NAMES utf8mb4;
USE shopee_db;

-- ---------------------------------------------------------------------
-- 1. USER: 1-7 người mua (7 vừa mua vừa bán), 7-13 người bán, 14-18 quản trị viên
-- ---------------------------------------------------------------------
INSERT INTO `USER` (UserID, Email, Phone, LastName, MiddleName, FirstName, PasswordHash, RegisterDate, AccountStatus) VALUES
 (1,  'an.nguyen@gmail.com',       '0901234561', 'Nguyễn', 'Văn',   'An',    '$2b$12$k9Qv1fXo3nWm8ZcT2yLpUeR7sHd4GjA6bN0iVqE5wKtY1uMxCzO2a', '2024-03-12 09:15:00', 'ACTIVE'),
 (2,  'binh.tran@gmail.com',       '0912345672', 'Trần',   'Thị',   'Bình',  '$2b$12$P3wR8tYu1iOp5aSd7fGh9jKl2zXc4vBn6mQw0eRt3yUi8oPa1sDf2', '2024-05-20 14:02:00', 'ACTIVE'),
 (3,  'cuong.le@gmail.com',        '0987654323', 'Lê',     'Hoàng', 'Cường', '$2b$12$Zx7Cv2Bn9Mq4Wa6Se1Dr8Ft3Gy5Hu0Ji7Ko2Lp4Qw9Er6Ty1Ui3Op', '2024-07-01 08:30:00', 'ACTIVE'),
 (4,  'duy.pham@gmail.com',        '0934567894', 'Phạm',   'Minh',  'Duy',   '$2b$12$Lm5Nb8Vc1Xz4Aq7Sw0De3Fr6Gt9Hy2Ju5Ki8Lo1Pm4Qn7Rb0Sc3Td', '2024-09-18 19:45:00', 'ACTIVE'),
 (5,  'ha.vo@gmail.com',           '0976543215', 'Võ',     'Thu',   'Hà',    '$2b$12$Qa2Ws5Ed8Rf1Tg4Yh7Uj0Ik3Ol6Pz9Xc2Vb5Nm8Mq1Aw4Se7Dr0Ft', '2025-01-05 10:10:00', 'ACTIVE'),
 (6,  'huy.dang@gmail.com',        '0909876546', 'Đặng',   'Quốc',  'Huy',   '$2b$12$Yu6Ti9Ro2Ep5Wq8Az1Sx4Dc7Fv0Gb3Hn6Jm9Kl2Pq5Wr8Et1Yt4Ui', '2025-04-22 21:00:00', 'WARNED'),
 (7,  'lan.bui@gmail.com',         '0938123457', 'Bùi',    'Thanh', 'Lan',   '$2b$12$Bv3Nc6Mx9Za2Sq5Wd8Ef1Rg4Th7Yj0Uk3Il6Op9Pa2Sd5Fg8Hj1Kl', '2023-11-02 16:20:00', 'ACTIVE'),
 (8,  'khang.hoang@gmail.com',     '0918234568', 'Hoàng',  'Gia',   'Khang', '$2b$12$Ws4Ed7Rf0Tg3Yh6Uj9Ik2Ol5Pz8Xc1Vb4Nm7Mq0Aw3Se6Dr9Ft2Gy', '2023-12-15 11:11:00', 'ACTIVE'),
 (9,  'linh.ngo@gmail.com',        '0978345679', 'Ngô',    'Mỹ',    'Linh',  '$2b$12$Er5Tg8Yh1Uj4Ik7Ol0Pz3Xc6Vb9Nm2Mq5Aw8Se1Dr4Ft7Gy0Hu3Ji', '2024-02-28 13:40:00', 'ACTIVE'),
 (10, 'nam.do@gmail.com',          '0968456780', 'Đỗ',     'Thành', 'Nam',   '$2b$12$Rt6Yh9Uj2Ik5Ol8Pz1Xc4Vb7Nm0Mq3Aw6Se9Dr2Ft5Gy8Hu1Ji4Ko', '2024-06-10 09:00:00', 'ACTIVE'),
 (11, 'oanh.huynh@gmail.com',      '0948567891', 'Huỳnh',  'Ngọc',  'Oanh',  '$2b$12$Ty7Uj0Ik3Ol6Pz9Xc2Vb5Nm8Mq1Aw4Se7Dr0Ft3Gy6Hu9Ji2Ko5Lp', '2024-08-08 08:08:00', 'ACTIVE'),
 (12, 'phuc.truong@gmail.com',     '0928678902', 'Trương', 'Văn',   'Phúc',  '$2b$12$Uj8Ik1Ol4Pz7Xc0Vb3Nm6Mq9Aw2Se5Dr8Ft1Gy4Hu7Ji0Ko3Lp6Qa', '2026-10-30 15:30:00', 'ACTIVE'),
 (13, 'quynh.ly@gmail.com',        '0908789013', 'Lý',     'Thị',   'Quỳnh', '$2b$12$Ik9Ol2Pz5Xc8Vb1Nm4Mq7Aw0Se3Dr6Ft9Gy2Hu5Ji8Ko1Lp4Qa7Ws', '2026-09-14 10:45:00', 'RESTRICTED'),
 (14, 'son.phan@shopee-admin.vn',  '0283900014', 'Phan',   'Minh',  'Sơn',   '$2b$12$Ol0Pz3Xc6Vb9Nm2Mq5Aw8Se1Dr4Ft7Gy0Hu3Ji6Ko9Lp2Qa5Ws8Ed', '2022-01-10 08:00:00', 'ACTIVE'),
 (15, 'trang.mai@shopee-admin.vn', '0283900015', 'Mai',    'Thùy',  'Trang', '$2b$12$Pz1Xc4Vb7Nm0Mq3Aw6Se9Dr2Ft5Gy8Hu1Ji4Ko7Lp0Qa3Ws6Ed9Rf', '2022-06-01 08:00:00', 'ACTIVE'),
 (16, 'tam.vu@shopee-admin.vn',    '0283900016', 'Vũ',     'Đức',   'Tâm',   '$2b$12$Xc2Vb5Nm8Mq1Aw4Se7Dr0Ft3Gy6Hu9Ji2Ko5Lp8Qa1Ws4Ed7Rf0Tg', '2023-03-15 08:00:00', 'ACTIVE'),
 (17, 'uyen.cao@shopee-admin.vn',  '0283900017', 'Cao',    'Phương','Uyên',  '$2b$12$Vb3Nm6Mq9Aw2Se5Dr8Ft1Gy4Hu7Ji0Ko3Lp6Qa9Ws2Ed5Rf8Tg1Yh', '2024-02-19 08:00:00', 'ACTIVE'),
 (18, 'vinh.ta@shopee-admin.vn',   '0283900018', 'Tạ',     'Quang', 'Vinh',  '$2b$12$Nm4Mq7Aw0Se3Dr6Ft9Gy2Hu5Ji8Ko1Lp4Qa7Ws0Ed3Rf6Tg9Yh2Uj', '2025-08-04 08:00:00', 'ACTIVE');

-- 2. BUYER
INSERT INTO BUYER (UserID, MembershipTier, RewardPoints) VALUES
 (1, 'GOLD', 1250), (2, 'DIAMOND', 4820), (3, 'SILVER', 560), (4, 'SILVER', 730),
 (5, 'BRONZE', 90), (6, 'BRONZE', 150), (7, 'GOLD', 2100);

-- 3. SELLER: 12 đang chờ xác minh, 13 bị từ chối -> cả hai không tạo được SHOP
INSERT INTO SELLER (UserID, TaxCode, VerifiedDate, VerificationStatus) VALUES
 (7,  '0312345671', '2023-11-10', 'VERIFIED'),
 (8,  '0312345682', '2023-12-20', 'VERIFIED'),
 (9,  '0312345693', '2024-03-05', 'VERIFIED'),
 (10, '0312345704', '2024-06-15', 'VERIFIED'),
 (11, '0312345715', '2024-08-12', 'VERIFIED'),
 (12, '0312345726', NULL,         'PENDING'),
 (13, '0312345737', NULL,         'REJECTED');

-- 4. ADMIN
INSERT INTO `ADMIN` (UserID, EmployeeID, HireDate, AdminLevel) VALUES
 (14, 'ADM001', '2022-01-10', 3), (15, 'ADM002', '2022-06-01', 2), (16, 'ADM003', '2023-03-15', 2),
 (17, 'ADM004', '2024-02-19', 1), (18, 'ADM005', '2025-08-04', 1);

-- 5. SHOP: chỉ người bán VERIFIED (trg_shop_bi)
INSERT INTO SHOP (ShopID, SellerID, ShopName, Description, Address, EstablishedDate, ShopStatus) VALUES
 (1, 7,  'Lan Fashion', 'Thời trang nam nữ phong cách basic', '12 Lê Lợi, Phường Sài Gòn, TP. Hồ Chí Minh',          '2023-11-15', 'ACTIVE'),
 (2, 8,  'Khang Tech',  'Phụ kiện công nghệ chính hãng',     '45 Nguyễn Trãi, Phường Bến Thành, TP. Hồ Chí Minh',  '2023-12-25', 'ACTIVE'),
 (3, 9,  'Linh Beauty', 'Mỹ phẩm chăm sóc da',               '88 Trần Phú, Phường Hải Châu, Đà Nẵng',             '2024-03-10', 'ACTIVE'),
 (4, 10, 'Nam Sport',   'Giày và dụng cụ thể thao',          '23 Cầu Giấy, Phường Cầu Giấy, Hà Nội',              '2024-06-20', 'ACTIVE'),
 (5, 11, 'Oanh Books',  'Sách kỹ năng và kinh tế',           '7 Hòa Bình, Phường Ninh Kiều, Cần Thơ',             '2024-08-15', 'WARNED');

-- 6. ADDRESS: mỗi người mua tối đa 1 địa chỉ mặc định (uq_address_default)
INSERT INTO ADDRESS (AddressID, BuyerID, RecipientName, Phone, DetailAddress, Ward, Province, IsDefault) VALUES
 (1, 1, 'Nguyễn Văn An',   '0901234561', '268 Lý Thường Kiệt',           'Phường Diên Hồng',  'TP. Hồ Chí Minh', TRUE),
 (2, 1, 'Nguyễn Văn An',   '0901234561', 'Tòa nhà Bitexco, 2 Hải Triều', 'Phường Sài Gòn',    'TP. Hồ Chí Minh', FALSE),
 (3, 2, 'Trần Thị Bình',   '0912345672', '15 Hàng Bài',                  'Phường Hoàn Kiếm',  'Hà Nội',          TRUE),
 (4, 3, 'Lê Hoàng Cường',  '0987654323', '102 Võ Văn Ngân',              'Phường Thủ Đức',    'TP. Hồ Chí Minh', TRUE),
 (5, 4, 'Phạm Minh Duy',   '0934567894', '56 Bạch Đằng',                 'Phường Hải Châu',   'Đà Nẵng',         TRUE),
 (6, 5, 'Võ Thu Hà',       '0976543215', '9 Nguyễn Văn Cừ',              'Phường Ninh Kiều',  'Cần Thơ',         TRUE),
 (7, 6, 'Đặng Quốc Huy',   '0909876546', '77 Xuân Thủy',                 'Phường Cầu Giấy',   'Hà Nội',          TRUE),
 (8, 7, 'Bùi Thanh Lan',   '0938123457', '12 Lê Lợi',                    'Phường Sài Gòn',    'TP. Hồ Chí Minh', TRUE),
 (9, 3, 'Lê Thị Mai',      '0903111222', '34 Đinh Tiên Hoàng',           'Phường Bình Thạnh', 'TP. Hồ Chí Minh', FALSE);

-- 7. CATEGORY: danh mục cha trước; cây 3 cấp Thời trang > Áo nam > Áo thun nam
INSERT INTO CATEGORY (CategoryID, CategoryName, Description, ParentCategoryID) VALUES
 (1,  'Thời trang',         'Quần áo, phụ kiện thời trang',        NULL),
 (2,  'Điện tử',            'Thiết bị và phụ kiện điện tử',        NULL),
 (3,  'Sức khỏe & Làm đẹp', 'Mỹ phẩm, chăm sóc cá nhân',           NULL),
 (4,  'Thể thao',           'Giày, dụng cụ thể thao',              NULL),
 (5,  'Sách',               'Sách in các thể loại',                NULL),
 (6,  'Áo nam',             'Áo dành cho nam',                     1),
 (7,  'Váy nữ',             'Váy, đầm nữ',                         1),
 (8,  'Tai nghe',           'Tai nghe có dây và không dây',        2),
 (9,  'Sạc & Cáp',          'Củ sạc, cáp sạc',                     2),
 (10, 'Chăm sóc da',        'Sữa rửa mặt, kem dưỡng, chống nắng',  3),
 (11, 'Giày thể thao',      'Giày chạy bộ, tập luyện',             4),
 (12, 'Sách kỹ năng',       'Sách phát triển bản thân',            5),
 (13, 'Áo thun nam',        'Áo thun cổ tròn, cổ tim',             6);

-- 8. PRODUCT
INSERT INTO PRODUCT (ProductID, ShopID, CategoryID, ProductName, Description, PostedDate, ProductStatus) VALUES
 (1,  1, 13, 'Áo thun nam cotton basic',        'Cotton 100%, form regular',         '2023-12-01 10:00:00', 'ACTIVE'),
 (2,  1, 7,  'Váy hoa nhí dáng xòe',            'Vải voan, có lót',                  '2024-04-12 09:30:00', 'ACTIVE'),
 (3,  2, 8,  'Tai nghe Bluetooth TWS X10',      'Bluetooth 5.3, pin 30 giờ',         '2024-01-05 14:00:00', 'ACTIVE'),
 (4,  2, 9,  'Cáp sạc nhanh USB-C 1m',          'Hỗ trợ sạc nhanh 60W',              '2024-01-05 14:10:00', 'ACTIVE'),
 (5,  3, 10, 'Sữa rửa mặt trà xanh 150ml',      'Dịu nhẹ cho da dầu',                '2024-03-20 08:00:00', 'ACTIVE'),
 (6,  3, 10, 'Kem chống nắng SPF50 50ml',       'Chống nắng phổ rộng, không nhờn',   '2024-04-02 08:00:00', 'ACTIVE'),
 (7,  4, 11, 'Giày chạy bộ RunFast',            'Đế êm, thoáng khí',                 '2024-07-01 10:00:00', 'ACTIVE'),
 (8,  5, 12, 'Sách Quản lý thời gian hiệu quả', 'Bìa mềm, 280 trang',                '2024-08-20 09:00:00', 'ACTIVE'),
 (9,  5, 12, 'Sách Tư duy phản biện',           'Bìa mềm, 320 trang',                '2024-09-01 09:00:00', 'ACTIVE'),
 (10, 2, 8,  'Tai nghe chụp tai Studio Pro',    'Chống ồn chủ động',                 '2025-02-14 15:00:00', 'INACTIVE');

-- 9. PRODUCT_IMAGE
INSERT INTO PRODUCT_IMAGE (ProductID, ImageURL) VALUES
 (1, 'https://cdn.shopdemo.vn/p1_trang.jpg'), (1, 'https://cdn.shopdemo.vn/p1_den.jpg'),
 (2, 'https://cdn.shopdemo.vn/p2.jpg'),
 (3, 'https://cdn.shopdemo.vn/p3_den.jpg'),   (3, 'https://cdn.shopdemo.vn/p3_trang.jpg'),
 (4, 'https://cdn.shopdemo.vn/p4.jpg'), (5, 'https://cdn.shopdemo.vn/p5.jpg'),
 (6, 'https://cdn.shopdemo.vn/p6.jpg'), (7, 'https://cdn.shopdemo.vn/p7.jpg'),
 (8, 'https://cdn.shopdemo.vn/p8.jpg'), (9, 'https://cdn.shopdemo.vn/p9.jpg'),
 (10,'https://cdn.shopdemo.vn/p10.jpg');

-- 10. PRODUCT_VARIANT: giá ban đầu (tháng 10/2026). Một số giá được đổi ở
--     các bước sau để minh họa đơn giá lúc mua được giữ nguyên.
--     Tồn kho ở đây là trước khi có đơn; trigger sẽ tự trừ khi đặt hàng.
INSERT INTO PRODUCT_VARIANT (ProductID, VariantID, Color, Size, Price, StockQuantity) VALUES
 (1, 1, 'Trắng', 'M',        129000, 53),
 (1, 2, 'Trắng', 'L',        129000, 41),
 (1, 3, 'Đen',   'L',        135000, 0),     -- hết hàng
 (2, 1, 'Hồng',  'S',        259000, 21),
 (2, 2, 'Hồng',  'M',        259000, 16),
 (3, 1, 'Đen',   NULL,       450000, 31),
 (3, 2, 'Trắng', NULL,       450000, 26),
 (4, 1, 'Trắng', '1m',        55000, 202),   -- sau đơn 2 tăng lên 59.000
 (5, 1, NULL,    '150ml',     95000, 81),
 (6, 1, NULL,    '50ml',     179000, 63),    -- sau đơn 9 tăng lên 189.000
 (7, 1, 'Xanh',  '41',       890000, 10),
 (7, 2, 'Xanh',  '42',       890000, 9),     -- giảm 850.000 trong ngày 11/11 rồi trả lại
 (8, 1, NULL,    'Bìa mềm',   86000, 103),
 (9, 1, NULL,    'Bìa mềm',  112000, 72),
 (10,1, 'Đen',   NULL,      1250000, 5);

-- 11. CART: mỗi người mua 1 giỏ
INSERT INTO CART (CartID, BuyerID) VALUES (1,1),(2,2),(3,3),(4,4),(5,5),(6,6),(7,7);

-- 12. CART_ITEM
INSERT INTO CART_ITEM (CartID, ProductID, VariantID, Quantity) VALUES
 (1,1,1,2), (1,3,1,1), (2,5,1,1), (2,6,1,2), (3,7,2,1), (4,8,1,1), (5,2,2,1), (6,9,1,1);

-- 13. VOUCHER: 4 chưa tới hạn, 5 đã hết hạn, 6 giới hạn 1 lượt (dùng ở đơn 6)
INSERT INTO VOUCHER (VoucherID, Code, DiscountType, DiscountValue, MinOrderValue, StartTime, EndTime, MaxUsage) VALUES
 (1, 'GIAM10',      'PERCENT', 10,    200000, '2026-10-01 00:00:00', '2026-12-31 23:59:59', 100),
 (2, 'FREESHIP30K', 'FIXED',   30000, 150000, '2026-10-01 00:00:00', '2026-11-30 23:59:59', 500),
 (3, 'SALE1111',    'FIXED',   50000, 300000, '2026-11-10 00:00:00', '2026-11-12 23:59:59', 200),
 (4, 'TET2027',     'PERCENT', 15,    500000, '2027-01-15 00:00:00', '2027-02-15 23:59:59', 300),
 (5, 'HETHAN20K',   'FIXED',   20000, 100000, '2026-09-01 00:00:00', '2026-09-30 23:59:59', 50),
 (6, 'MOTLAN25K',   'FIXED',   25000, 100000, '2026-10-01 00:00:00', '2026-12-31 23:59:59', 1);

-- =====================================================================
-- 14-19. ĐƠN HÀNG VÀ CÁC BẢNG LIÊN QUAN (theo thứ tự thời gian)
-- Thông tin địa chỉ trong ORDER do trg_order_bi tự sao chép từ ADDRESS;
-- vẫn ghi ra đây cho rõ ràng và để thỏa NOT NULL.
-- Tổng tiền = tiền hàng + phí ship - tiền giảm (ghi ở comment mỗi đơn).
-- =====================================================================

-- Đơn 1 (05/10) - người mua 1, shop 1, không voucher. Tổng = 387.000 + 25.000 = 412.000
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (1, 1, 1, 1, NULL, '2026-10-05 10:15:00', 'PENDING', 'Giao giờ hành chính',
        'Nguyễn Văn An', '0901234561', '268 Lý Thường Kiệt', 'Phường Diên Hồng', 'TP. Hồ Chí Minh', 0, 25000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (1, 1, 1, 1, 2, 129000), (1, 2, 1, 2, 1, 129000);
INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, PaymentTime, PaymentStatus) VALUES
 (1, 1, 'E_WALLET', 412000, '2026-10-05 10:16:00', 'SUCCESS');
UPDATE `ORDER` SET OrderStatus = 'SHIPPING' WHERE OrderID = 1;
INSERT INTO SHIPMENT (ShipmentID, OrderID, TrackingNumber, Carrier, ShippingFee, EstimatedDate, ActualDate, ShipmentStatus) VALUES
 (1, 1, 'SPXVN00000001', 'SPX Express', 25000, '2026-10-08', '2026-10-07 15:20:00', 'DELIVERED');
UPDATE `ORDER` SET OrderStatus = 'COMPLETED' WHERE OrderID = 1;

-- Đơn 2 (12/10) - người mua 2, shop 2, voucher GIAM10 (-10%).
-- Tổng = 560.000 + 30.000 - 56.000 = 534.000. Lần thanh toán đầu thất bại.
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (2, 2, 2, 3, 1, '2026-10-12 14:30:00', 'PENDING', NULL,
        'Trần Thị Bình', '0912345672', '15 Hàng Bài', 'Phường Hoàn Kiếm', 'Hà Nội', 56000, 30000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (2, 1, 3, 1, 1, 450000), (2, 2, 4, 1, 2, 55000);
INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, PaymentTime, PaymentStatus) VALUES
 (2, 2, 'BANK_TRANSFER', 534000, '2026-10-12 14:31:00', 'FAILED'),
 (3, 2, 'BANK_TRANSFER', 534000, '2026-10-12 14:35:00', 'SUCCESS');
UPDATE `ORDER` SET OrderStatus = 'SHIPPING' WHERE OrderID = 2;
INSERT INTO SHIPMENT (ShipmentID, OrderID, TrackingNumber, Carrier, ShippingFee, EstimatedDate, ActualDate, ShipmentStatus) VALUES
 (2, 2, 'GHN0000000002', 'Giao Hàng Nhanh', 30000, '2026-10-15', '2026-10-16 10:05:00', 'DELIVERED');
UPDATE `ORDER` SET OrderStatus = 'COMPLETED' WHERE OrderID = 2;

-- Sau đơn 2: shop 2 tăng giá cáp sạc 55.000 -> 59.000 (đơn 2 vẫn giữ 55.000)
UPDATE PRODUCT_VARIANT SET Price = 59000 WHERE ProductID = 4 AND VariantID = 1;

-- Đơn 9 (25/10) - người mua 2, shop 3. Tổng = 358.000 + 25.000 = 383.000 (COD)
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (9, 2, 3, 3, NULL, '2026-10-25 13:10:00', 'PENDING', NULL,
        'Trần Thị Bình', '0912345672', '15 Hàng Bài', 'Phường Hoàn Kiếm', 'Hà Nội', 0, 25000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (9, 1, 6, 1, 2, 179000);
UPDATE `ORDER` SET OrderStatus = 'SHIPPING' WHERE OrderID = 9;
INSERT INTO SHIPMENT (ShipmentID, OrderID, TrackingNumber, Carrier, ShippingFee, EstimatedDate, ActualDate, ShipmentStatus) VALUES
 (7, 9, 'JNT0000000007', 'J&T Express', 25000, '2026-10-28', '2026-10-28 14:40:00', 'DELIVERED');
INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, PaymentTime, PaymentStatus) VALUES
 (9, 9, 'COD', 383000, '2026-10-28 14:40:00', 'SUCCESS');
UPDATE `ORDER` SET OrderStatus = 'COMPLETED' WHERE OrderID = 9;

-- Sau đơn 9: kem chống nắng tăng giá 179.000 -> 189.000
UPDATE PRODUCT_VARIANT SET Price = 189000 WHERE ProductID = 6 AND VariantID = 1;

-- Đơn 3 (02/11) - người mua 3, shop 3, voucher FREESHIP30K. Đang giao.
-- Tổng = 284.000 + 30.000 - 30.000 = 284.000
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (3, 3, 3, 4, 2, '2026-11-02 09:00:00', 'PENDING', 'Gọi trước khi giao',
        'Lê Hoàng Cường', '0987654323', '102 Võ Văn Ngân', 'Phường Thủ Đức', 'TP. Hồ Chí Minh', 30000, 30000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (3, 1, 5, 1, 1, 95000), (3, 2, 6, 1, 1, 189000);
INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, PaymentTime, PaymentStatus) VALUES
 (4, 3, 'E_WALLET', 284000, '2026-11-02 09:01:00', 'SUCCESS');
UPDATE `ORDER` SET OrderStatus = 'SHIPPING' WHERE OrderID = 3;
INSERT INTO SHIPMENT (ShipmentID, OrderID, TrackingNumber, Carrier, ShippingFee, EstimatedDate, ActualDate, ShipmentStatus) VALUES
 (3, 3, 'SPXVN00000003', 'SPX Express', 30000, '2026-11-06', NULL, 'IN_TRANSIT');

-- Ngày 11/11: giày RunFast size 42 giảm giá 890.000 -> 850.000
UPDATE PRODUCT_VARIANT SET Price = 850000 WHERE ProductID = 7 AND VariantID = 2;

-- Đơn 4 (11/11) - người mua 4, shop 4, voucher SALE1111 (-50.000), COD.
-- Tổng = 850.000 + 35.000 - 50.000 = 835.000
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (4, 4, 4, 5, 3, '2026-11-11 20:05:00', 'PENDING', NULL,
        'Phạm Minh Duy', '0934567894', '56 Bạch Đằng', 'Phường Hải Châu', 'Đà Nẵng', 50000, 35000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (4, 1, 7, 2, 1, 850000);
UPDATE `ORDER` SET OrderStatus = 'SHIPPING' WHERE OrderID = 4;
INSERT INTO SHIPMENT (ShipmentID, OrderID, TrackingNumber, Carrier, ShippingFee, EstimatedDate, ActualDate, ShipmentStatus) VALUES
 (4, 4, 'GHTK000000004', 'Giao Hàng Tiết Kiệm', 35000, '2026-11-15', '2026-11-14 17:30:00', 'DELIVERED');
INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, PaymentTime, PaymentStatus) VALUES
 (5, 4, 'COD', 835000, '2026-11-14 17:30:00', 'SUCCESS');
UPDATE `ORDER` SET OrderStatus = 'COMPLETED' WHERE OrderID = 4;

-- Hết ngày 11/11: trả giá giày về 890.000 (đơn 4 vẫn giữ 850.000)
UPDATE PRODUCT_VARIANT SET Price = 890000 WHERE ProductID = 7 AND VariantID = 2;

-- Đơn 5 (15/11) - người mua 5, shop 5. Thanh toán thất bại, người mua hủy đơn.
-- Hủy đơn -> trg_order_au tự hoàn lại 2 cuốn sách vào tồn kho.
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (5, 5, 5, 6, NULL, '2026-11-15 08:40:00', 'PENDING', 'Đặt nhầm số lượng',
        'Võ Thu Hà', '0976543215', '9 Nguyễn Văn Cừ', 'Phường Ninh Kiều', 'Cần Thơ', 0, 20000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (5, 1, 8, 1, 2, 86000);
INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, PaymentTime, PaymentStatus) VALUES
 (6, 5, 'E_WALLET', 192000, '2026-11-15 08:41:00', 'FAILED');
UPDATE `ORDER` SET OrderStatus = 'CANCELLED' WHERE OrderID = 5;

-- Đơn 6 (18/11) - người mua 1 giao đến địa chỉ thứ 2, voucher MOTLAN25K
-- (giới hạn 1 lượt -> đơn này dùng hết). Còn chờ xác nhận.
-- Tổng = 450.000 + 30.000 - 25.000 = 455.000
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (6, 1, 2, 2, 6, '2026-11-18 19:20:00', 'PENDING', 'Giao đến văn phòng',
        'Nguyễn Văn An', '0901234561', 'Tòa nhà Bitexco, 2 Hải Triều', 'Phường Sài Gòn', 'TP. Hồ Chí Minh', 25000, 30000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (6, 1, 3, 2, 1, 450000);

-- Đơn 7 (20/11) - người mua 6, shop 1. Tổng = 259.000 + 25.000 = 284.000
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (7, 6, 1, 7, NULL, '2026-11-20 11:00:00', 'PENDING', NULL,
        'Đặng Quốc Huy', '0909876546', '77 Xuân Thủy', 'Phường Cầu Giấy', 'Hà Nội', 0, 25000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (7, 1, 2, 1, 1, 259000);
INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, PaymentTime, PaymentStatus) VALUES
 (7, 7, 'E_WALLET', 284000, '2026-11-20 11:01:00', 'SUCCESS');
UPDATE `ORDER` SET OrderStatus = 'SHIPPING' WHERE OrderID = 7;
INSERT INTO SHIPMENT (ShipmentID, OrderID, TrackingNumber, Carrier, ShippingFee, EstimatedDate, ActualDate, ShipmentStatus) VALUES
 (5, 7, 'SPXVN00000005', 'SPX Express', 25000, '2026-11-23', '2026-11-23 09:45:00', 'DELIVERED');
UPDATE `ORDER` SET OrderStatus = 'COMPLETED' WHERE OrderID = 7;

-- Đơn 8 (21/11) - người mua 7 (cũng là chủ shop 1) mua ở shop 5, voucher GIAM10.
-- Tổng = 310.000 + 20.000 - 31.000 = 299.000
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (8, 7, 5, 8, 1, '2026-11-21 16:45:00', 'PENDING', NULL,
        'Bùi Thanh Lan', '0938123457', '12 Lê Lợi', 'Phường Sài Gòn', 'TP. Hồ Chí Minh', 31000, 20000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (8, 1, 9, 1, 2, 112000), (8, 2, 8, 1, 1, 86000);
INSERT INTO PAYMENT (PaymentID, OrderID, Method, Amount, PaymentTime, PaymentStatus) VALUES
 (8, 8, 'BANK_TRANSFER', 299000, '2026-11-21 16:46:00', 'SUCCESS');
UPDATE `ORDER` SET OrderStatus = 'SHIPPING' WHERE OrderID = 8;
INSERT INTO SHIPMENT (ShipmentID, OrderID, TrackingNumber, Carrier, ShippingFee, EstimatedDate, ActualDate, ShipmentStatus) VALUES
 (6, 8, 'GHN0000000006', 'Giao Hàng Nhanh', 20000, '2026-11-25', NULL, 'IN_TRANSIT');

-- Đơn 10 (22/11) - người mua 3 đặt quà giao cho mẹ (địa chỉ thứ 2). Chờ xác nhận.
-- Tổng = 388.000 + 25.000 = 413.000
INSERT INTO `ORDER` (OrderID, BuyerID, ShopID, AddressID, VoucherID, OrderDate, OrderStatus, Note,
                     RecipientName, Phone, DetailAddress, Ward, Province, AppliedDiscountAmount, ShippingFeeAtOrder)
VALUES (10, 3, 1, 9, NULL, '2026-11-22 21:30:00', 'PENDING', 'Quà tặng mẹ',
        'Lê Thị Mai', '0903111222', '34 Đinh Tiên Hoàng', 'Phường Bình Thạnh', 'TP. Hồ Chí Minh', 0, 25000);
INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES
 (10, 1, 2, 2, 1, 259000), (10, 2, 1, 1, 1, 129000);

-- ---------------------------------------------------------------------
-- 18. REVIEW: chỉ chi tiết thuộc đơn COMPLETED, đúng người mua (trg_review_bi + FK ghép)
-- ---------------------------------------------------------------------
INSERT INTO REVIEW (OrderID, ItemID, BuyerID, Rating, Comment, ReviewTime) VALUES
 (1, 1, 1, 5, 'Áo mặc mát, đúng size, giao nhanh.',   '2026-10-08 20:00:00'),
 (1, 2, 1, 4, 'Vải ổn nhưng hơi nhăn sau khi giặt.',  '2026-10-08 20:05:00'),
 (2, 1, 2, 5, 'Tai nghe pin trâu, kết nối ổn định.',  '2026-10-18 09:30:00'),
 (2, 2, 2, 3, 'Cáp dùng được nhưng sạc hơi nóng.',    '2026-10-18 09:35:00'),
 (4, 1, 4, 5, 'Giày êm, chạy 10km không đau chân.',   '2026-11-16 18:00:00'),
 (7, 1, 6, 4, 'Váy đẹp như hình, màu hơi nhạt hơn.',  '2026-11-24 09:00:00'),
 (9, 1, 2, 2, 'Kem bị vón cục, đã gửi khiếu nại.',    '2026-10-30 09:00:00');

-- ---------------------------------------------------------------------
-- 19. COMPLAINT: chưa phân công admin thì PENDING; RESOLVED phải có kết quả và thời gian
-- ---------------------------------------------------------------------
INSERT INTO COMPLAINT (ComplaintID, BuyerID, OrderID, AdminID, ComplaintType, Content, SubmitTime, Status, Resolution, ResolvedTime) VALUES
 (1, 2, 9, 14, 'DAMAGED',          'Kem chống nắng bị vón cục ngay khi mở hộp.',             '2026-10-30 10:00:00', 'RESOLVED',
     'Hoàn tiền 179.000đ cho 1 sản phẩm lỗi.', '2026-11-02 15:00:00'),
 (2, 2, 2, 15, 'NOT_AS_DESCRIBED', 'Cáp sạc nóng bất thường khi sạc nhanh, không như mô tả.', '2026-10-19 08:20:00', 'RESOLVED',
     'Shop đổi cáp mới cho người mua.', '2026-10-22 10:00:00'),
 (3, 3, 3, NULL, 'NOT_RECEIVED',   'Đơn đã quá ngày giao dự kiến nhưng chưa nhận được hàng.', '2026-11-23 08:00:00', 'PENDING', NULL, NULL),
 (4, 1, 1, 16, 'DAMAGED',          'Hộp bị móp khi nhận hàng, sản phẩm vẫn nguyên vẹn.',      '2026-10-09 19:00:00', 'REJECTED',
     'Sản phẩm không hư hỏng, không đủ điều kiện hoàn tiền; shop gửi lời xin lỗi.', '2026-10-11 09:00:00'),
 (5, 4, 4, 17, 'WRONG_ITEM',       'Đặt size 42 nhưng hộp giày ghi size 41.',                 '2026-11-15 07:45:00', 'PROCESSING', NULL, NULL),
 (6, 5, 5, 18, 'OTHER',            'Ví báo bị trừ tiền dù giao dịch thanh toán thất bại.',    '2026-11-16 12:00:00', 'RESOLVED',
     'Xác minh giao dịch thất bại, tiền chưa bị trừ; hướng dẫn liên hệ ngân hàng.', '2026-11-17 16:00:00');

-- ---------------------------------------------------------------------
-- Khởi tạo thuộc tính dẫn xuất ORDER.TotalAmount cho dữ liệu đã nạp.
-- Nếu TV2 tạo trigger câu 2.2.2 TRƯỚC khi chạy file này thì có thể bỏ đoạn này.
-- ---------------------------------------------------------------------
UPDATE `ORDER` o
   SET o.TotalAmount = IFNULL((SELECT SUM(oi.Quantity * oi.UnitPrice) FROM ORDER_ITEM oi WHERE oi.OrderID = o.OrderID), 0)
                       + o.ShippingFeeAtOrder - o.AppliedDiscountAmount;

-- Kiểm tra nhanh số dòng mỗi bảng
SELECT 'USER' AS bang, COUNT(*) AS so_dong FROM `USER`
UNION ALL SELECT 'BUYER', COUNT(*) FROM BUYER
UNION ALL SELECT 'SELLER', COUNT(*) FROM SELLER
UNION ALL SELECT 'ADMIN', COUNT(*) FROM `ADMIN`
UNION ALL SELECT 'SHOP', COUNT(*) FROM SHOP
UNION ALL SELECT 'ADDRESS', COUNT(*) FROM ADDRESS
UNION ALL SELECT 'CATEGORY', COUNT(*) FROM CATEGORY
UNION ALL SELECT 'PRODUCT', COUNT(*) FROM PRODUCT
UNION ALL SELECT 'PRODUCT_IMAGE', COUNT(*) FROM PRODUCT_IMAGE
UNION ALL SELECT 'PRODUCT_VARIANT', COUNT(*) FROM PRODUCT_VARIANT
UNION ALL SELECT 'CART', COUNT(*) FROM CART
UNION ALL SELECT 'CART_ITEM', COUNT(*) FROM CART_ITEM
UNION ALL SELECT 'VOUCHER', COUNT(*) FROM VOUCHER
UNION ALL SELECT 'ORDER', COUNT(*) FROM `ORDER`
UNION ALL SELECT 'ORDER_ITEM', COUNT(*) FROM ORDER_ITEM
UNION ALL SELECT 'PAYMENT', COUNT(*) FROM PAYMENT
UNION ALL SELECT 'SHIPMENT', COUNT(*) FROM SHIPMENT
UNION ALL SELECT 'REVIEW', COUNT(*) FROM REVIEW
UNION ALL SELECT 'COMPLAINT', COUNT(*) FROM COMPLAINT;

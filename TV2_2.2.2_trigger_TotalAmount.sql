-- =====================================================================
-- BTL2 HỆ CSDL - CÂU 2.2.2: TRIGGER TÍNH THUỘC TÍNH DẪN XUẤT
-- Thuộc tính dẫn xuất: ORDER.TotalAmount (tổng giá trị đơn hàng)
--
--   TotalAmount = Σ Subtotal(các chi tiết đơn) + ShippingFeeAtOrder - AppliedDiscountAmount
--   Subtotal    = Quantity * UnitPrice     (thuộc tính dẫn xuất của ORDER_ITEM, không lưu)
--
-- TotalAmount phụ thuộc vào Subtotal, nên phải tính Subtotal TRƯỚC
-- (hàm fn_subtotal_don_hang bên dưới), không giả sử đã có sẵn.
--
-- Các thao tác DML làm thay đổi TotalAmount:
--   ORDER_ITEM : INSERT, DELETE, UPDATE Quantity        -> trigger AFTER trên ORDER_ITEM
--   ORDER      : INSERT (đơn mới),
--                UPDATE ShippingFeeAtOrder / AppliedDiscountAmount,
--                UPDATE trực tiếp TotalAmount (bị tính lại, không cho sửa tay)
--                                                      -> trigger BEFORE trên ORDER
--   (UPDATE ORDER_ITEM.UnitPrice / OrderID đã bị trigger của câu 1.1 chặn.
--    Xóa ORDER thì chi tiết bị xóa theo, không còn đơn để tính.)
--
-- Chạy sau script 1.1. Nếu chạy trước khi nạp dữ liệu mẫu thì tổng tiền
-- được tính tự động ngay khi nạp; nếu chạy sau, đoạn cuối file tính lại
-- cho các đơn đã có.
-- =====================================================================
USE shopee_db;

DROP FUNCTION IF EXISTS fn_subtotal_don_hang;
DROP TRIGGER  IF EXISTS trg_total_order_bi;
DROP TRIGGER  IF EXISTS trg_total_order_bu;
DROP TRIGGER  IF EXISTS trg_total_orderitem_ai;
DROP TRIGGER  IF EXISTS trg_total_orderitem_au;
DROP TRIGGER  IF EXISTS trg_total_orderitem_ad;

DELIMITER $$

-- Bước 1: tính thuộc tính dẫn xuất Subtotal của từng chi tiết rồi cộng lại
CREATE FUNCTION fn_subtotal_don_hang(p_order_id INT)
RETURNS DECIMAL(15,2)
READS SQL DATA
BEGIN
    DECLARE v_tong DECIMAL(15,2);
    SELECT IFNULL(SUM(Quantity * UnitPrice), 0) INTO v_tong
      FROM ORDER_ITEM
     WHERE OrderID = p_order_id;
    RETURN v_tong;
END$$

-- ---------------------------------------------------------------------
-- Trên ORDER: đơn mới chưa có chi tiết -> tiền hàng = 0.
-- Trong lúc đơn còn PENDING, tiền giảm có thể tạm lớn hơn tiền hàng
-- (chưa thêm đủ sản phẩm) nên lấy GREATEST(...,0) để không vi phạm
-- CHECK ck_order_total. Khi đơn rời PENDING, trigger 1.1 đã bảo đảm
-- tiền giảm <= tiền hàng, nên tổng thật luôn >= 0.
-- FOLLOWS: chạy sau trigger kiểm tra của câu 1.1.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_total_order_bi BEFORE INSERT ON `ORDER`
FOR EACH ROW FOLLOWS trg_order_bi
BEGIN
    SET NEW.TotalAmount = GREATEST(NEW.ShippingFeeAtOrder - NEW.AppliedDiscountAmount, 0);
END$$

-- Mọi lần cập nhật đơn đều tính lại từ dữ liệu gốc:
-- đổi phí ship / tiền giảm thì tổng đổi theo, còn sửa tay TotalAmount bị ghi đè.
CREATE TRIGGER trg_total_order_bu BEFORE UPDATE ON `ORDER`
FOR EACH ROW FOLLOWS trg_order_bu
BEGIN
    SET NEW.TotalAmount = GREATEST(fn_subtotal_don_hang(NEW.OrderID)
                                   + NEW.ShippingFeeAtOrder - NEW.AppliedDiscountAmount, 0);
END$$

-- ---------------------------------------------------------------------
-- Trên ORDER_ITEM: thêm / sửa số lượng / xóa chi tiết -> cập nhật đơn.
-- Lệnh UPDATE ORDER bên dưới kích hoạt trg_total_order_bu, nơi tổng tiền
-- được tính lại từ Subtotal mới nhất.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_total_orderitem_ai AFTER INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE `ORDER`
       SET TotalAmount = GREATEST(fn_subtotal_don_hang(NEW.OrderID)
                                  + ShippingFeeAtOrder - AppliedDiscountAmount, 0)
     WHERE OrderID = NEW.OrderID;
END$$

CREATE TRIGGER trg_total_orderitem_au AFTER UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    IF NEW.Quantity <> OLD.Quantity THEN
        UPDATE `ORDER`
           SET TotalAmount = GREATEST(fn_subtotal_don_hang(NEW.OrderID)
                                      + ShippingFeeAtOrder - AppliedDiscountAmount, 0)
         WHERE OrderID = NEW.OrderID;
    END IF;
END$$

CREATE TRIGGER trg_total_orderitem_ad AFTER DELETE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    UPDATE `ORDER`
       SET TotalAmount = GREATEST(fn_subtotal_don_hang(OLD.OrderID)
                                  + ShippingFeeAtOrder - AppliedDiscountAmount, 0)
     WHERE OrderID = OLD.OrderID;
END$$

DELIMITER ;

-- Tính lại cho các đơn đã có sẵn (nếu dữ liệu mẫu được nạp trước trigger).
-- Lệnh này kích hoạt trg_total_order_bu cho từng đơn.
UPDATE `ORDER` SET TotalAmount = 0 WHERE OrderID > 0;   -- có WHERE để không bị Safe Update Mode chặn

-- =====================================================================
-- MINH HỌA KHI BÁO CÁO (chạy từng nhóm lệnh, xem TotalAmount thay đổi)
-- =====================================================================
-- Đơn 10 (PENDING): 1 váy 259.000 + 1 áo 129.000 + ship 25.000 = 413.000
--   SELECT OrderID, TotalAmount FROM `ORDER` WHERE OrderID = 10;
-- (a) Thêm 1 chi tiết: áo trắng size L 129.000 -> 542.000
--   INSERT INTO ORDER_ITEM (OrderID, ItemID, ProductID, VariantID, Quantity, UnitPrice) VALUES (10, 3, 1, 2, 1, 0);
-- (b) Tăng số lượng váy lên 2 -> 801.000
--   UPDATE ORDER_ITEM SET Quantity = 2 WHERE OrderID = 10 AND ItemID = 1;
-- (c) Xóa dòng áo trắng L -> 672.000
--   DELETE FROM ORDER_ITEM WHERE OrderID = 10 AND ItemID = 3;
-- (d) Đổi phí ship 25.000 -> 15.000 -> 662.000
--   UPDATE `ORDER` SET ShippingFeeAtOrder = 15000 WHERE OrderID = 10;
-- (e) Cố tình sửa tay tổng tiền -> bị tính lại, vẫn 662.000
--   UPDATE `ORDER` SET TotalAmount = 1 WHERE OrderID = 10;
--   SELECT OrderID, TotalAmount FROM `ORDER` WHERE OrderID = 10;

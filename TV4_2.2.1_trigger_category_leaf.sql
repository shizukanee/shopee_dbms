-- Active: 1795604678545@@127.0.0.1@3306@shopee_db
-- BTL2 - TV4 - Câu 2.2.1
-- Ràng buộc: sản phẩm chỉ được gắn với danh mục lá.
-- Bảo vệ cả thao tác trên PRODUCT lẫn thao tác thêm/sửa cây CATEGORY.
-- DML có thể vi phạm:
--   1) INSERT PRODUCT hoặc UPDATE PRODUCT.CategoryID sang danh mục còn con.
--   2) INSERT CATEGORY hoặc UPDATE CATEGORY.ParentCategoryID để thêm con
--      vào danh mục đang được PRODUCT sử dụng.
-- Các thao tác này được kiểm tra bởi trigger tương ứng bên dưới.
USE shopee_db;

DROP TRIGGER IF EXISTS trg_tv4_product_leaf_bi;
DROP TRIGGER IF EXISTS trg_tv4_product_leaf_bu;
DROP TRIGGER IF EXISTS trg_tv4_category_leaf_bi;
DROP TRIGGER IF EXISTS trg_tv4_category_leaf_bu;
DROP PROCEDURE IF EXISTS chk_tv4_product_category_leaf;
DROP PROCEDURE IF EXISTS chk_tv4_category_not_used_by_product;

DELIMITER $$

CREATE PROCEDURE chk_tv4_product_category_leaf(IN p_category_id INT)
BEGIN
    DECLARE v_category_name VARCHAR(100) DEFAULT NULL;

    SELECT CategoryName
      INTO v_category_name
      FROM CATEGORY
     WHERE CategoryID = p_category_id;

    IF v_category_name IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Danh mục sản phẩm không tồn tại.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM CATEGORY
         WHERE ParentCategoryID = p_category_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Sản phẩm phải thuộc danh mục lá; danh mục đang chọn còn danh mục con.';
    END IF;
END$$

CREATE PROCEDURE chk_tv4_category_not_used_by_product(IN p_category_id INT)
BEGIN
    IF EXISTS (
        SELECT 1
          FROM PRODUCT
         WHERE CategoryID = p_category_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể thêm danh mục con: danh mục cha đang được sản phẩm sử dụng.';
    END IF;
END$$

CREATE TRIGGER trg_tv4_product_leaf_bi
BEFORE INSERT ON PRODUCT
FOR EACH ROW
BEGIN
    CALL chk_tv4_product_category_leaf(NEW.CategoryID);
END$$

CREATE TRIGGER trg_tv4_product_leaf_bu
BEFORE UPDATE ON PRODUCT
FOR EACH ROW
BEGIN
    IF NEW.CategoryID <> OLD.CategoryID THEN
        CALL chk_tv4_product_category_leaf(NEW.CategoryID);
    END IF;
END$$

CREATE TRIGGER trg_tv4_category_leaf_bi
BEFORE INSERT ON CATEGORY
FOR EACH ROW FOLLOWS trg_category_bi
BEGIN
    IF NEW.ParentCategoryID IS NOT NULL THEN
        CALL chk_tv4_category_not_used_by_product(NEW.ParentCategoryID);
    END IF;
END$$

CREATE TRIGGER trg_tv4_category_leaf_bu
BEFORE UPDATE ON CATEGORY
FOR EACH ROW FOLLOWS trg_category_bu
BEGIN
    IF NOT (NEW.ParentCategoryID <=> OLD.ParentCategoryID)
       AND NEW.ParentCategoryID IS NOT NULL THEN
        CALL chk_tv4_category_not_used_by_product(NEW.ParentCategoryID);
    END IF;
END$$

DELIMITER ;

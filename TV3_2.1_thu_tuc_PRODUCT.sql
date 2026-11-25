-- Câu 2.1: thủ tục thêm/sửa/xóa bảng PRODUCT
USE shopee_db;

DROP PROCEDURE IF EXISTS sp_product_them;
DROP PROCEDURE IF EXISTS sp_product_sua;
DROP PROCEDURE IF EXISTS sp_product_xoa;

DELIMITER $$

-- - ADD PRODUCT
CREATE PROCEDURE sp_product_them(
    IN  p_shop_id        INT,
    IN  p_category_id    INT,
    IN  p_product_name   VARCHAR(200),
    IN  p_description    TEXT,
    IN  p_product_status VARCHAR(20),
    OUT p_product_id     INT
)
BEGIN
    DECLARE v_shop_status   VARCHAR(20) DEFAULT NULL;
    DECLARE v_category_name VARCHAR(100) DEFAULT NULL;
    DECLARE v_child_count   INT DEFAULT 0;
    DECLARE v_dup_id        INT DEFAULT NULL;
    DECLARE v_name          VARCHAR(200);
    DECLARE v_status        VARCHAR(20);
    DECLARE v_msg           VARCHAR(128);

    SET p_product_id = NULL;
    SET v_name   = TRIM(IFNULL(p_product_name, ''));
    SET v_status = UPPER(TRIM(IFNULL(p_product_status, 'ACTIVE')));

    -- Cửa hàng phải tồn tại và đang hoạt động
    IF p_shop_id IS NULL OR p_shop_id <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mã cửa hàng không hợp lệ (phải là số nguyên dương).';
    END IF;

    SELECT ShopStatus INTO v_shop_status FROM SHOP WHERE ShopID = p_shop_id;
    IF v_shop_status IS NULL THEN
        SET v_msg = CONCAT('Cửa hàng ', p_shop_id, ' không tồn tại.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_shop_status NOT IN ('ACTIVE', 'WARNED') THEN
        SET v_msg = CONCAT('Cửa hàng ', p_shop_id, ' đang ', v_shop_status,
                           ', không được đăng bán sản phẩm mới.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Danh mục phải tồn tại và là danh mục lá
    IF p_category_id IS NULL OR p_category_id <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mã danh mục không hợp lệ (phải là số nguyên dương).';
    END IF;

    SELECT CategoryName INTO v_category_name
      FROM CATEGORY WHERE CategoryID = p_category_id;
    IF v_category_name IS NULL THEN
        SET v_msg = CONCAT('Danh mục ', p_category_id, ' không tồn tại.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT COUNT(*) INTO v_child_count
      FROM CATEGORY WHERE ParentCategoryID = p_category_id;
    IF v_child_count > 0 THEN
        SET v_msg = CONCAT('Danh mục "', v_category_name,
                           '" còn danh mục con; hãy chọn danh mục lá.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Tên sản phẩm
    IF v_name = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tên sản phẩm không được để trống.';
    END IF;
    IF CHAR_LENGTH(v_name) > 200 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tên sản phẩm không được vượt quá 200 ký tự.';
    END IF;

    -- Không trùng tên trong cùng cửa hàng
    SELECT ProductID INTO v_dup_id
      FROM PRODUCT
     WHERE ShopID = p_shop_id AND ProductName = v_name
     LIMIT 1;
    IF v_dup_id IS NOT NULL THEN
        SET v_msg = CONCAT('Cửa hàng đã có sản phẩm cùng tên (ProductID = ',
                           v_dup_id, ').');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Mô tả
    IF CHAR_LENGTH(IFNULL(p_description, '')) > 5000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mô tả sản phẩm không được vượt quá 5.000 ký tự.';
    END IF;

    -- Trạng thái (sản phẩm mới không được BANNED)
    IF v_status NOT IN ('ACTIVE', 'HIDDEN', 'INACTIVE', 'BANNED') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Trạng thái không hợp lệ (ACTIVE/HIDDEN/INACTIVE/BANNED).';
    END IF;
    IF v_status = 'BANNED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Sản phẩm mới không được tạo ở trạng thái BANNED.';
    END IF;

    INSERT INTO PRODUCT (ShopID, CategoryID, ProductName, Description,
                         PostedDate, ProductStatus)
    VALUES (p_shop_id, p_category_id, v_name,
            NULLIF(TRIM(p_description), ''), NOW(), v_status);

    SET p_product_id = LAST_INSERT_ID();
END$$

-- - UPDATE PRODUCT
CREATE PROCEDURE sp_product_sua(
    IN p_product_id     INT,
    IN p_shop_id        INT,
    IN p_category_id    INT,
    IN p_product_name   VARCHAR(200),
    IN p_description    TEXT,
    IN p_product_status VARCHAR(20)
)
BEGIN
    DECLARE v_old_shop      INT DEFAULT NULL;
    DECLARE v_old_status    VARCHAR(20) DEFAULT NULL;
    DECLARE v_shop_status   VARCHAR(20) DEFAULT NULL;
    DECLARE v_category_name VARCHAR(100) DEFAULT NULL;
    DECLARE v_child_count   INT DEFAULT 0;
    DECLARE v_dup_id        INT DEFAULT NULL;
    DECLARE v_name          VARCHAR(200);
    DECLARE v_status        VARCHAR(20);
    DECLARE v_msg           VARCHAR(128);

    IF p_product_id IS NULL OR p_product_id <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mã sản phẩm không hợp lệ (phải là số nguyên dương).';
    END IF;

    SELECT ShopID, ProductStatus INTO v_old_shop, v_old_status
      FROM PRODUCT WHERE ProductID = p_product_id;
    IF v_old_shop IS NULL THEN
        SET v_msg = CONCAT('Sản phẩm ', p_product_id, ' không tồn tại.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_old_status = 'BANNED' THEN
        SET v_msg = CONCAT('Sản phẩm ', p_product_id,
                           ' đã bị BANNED, không được phép sửa.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SET v_name   = TRIM(IFNULL(p_product_name, ''));
    SET v_status = UPPER(TRIM(IFNULL(p_product_status, 'ACTIVE')));

    -- Cửa hàng phải tồn tại và đang hoạt động
    IF p_shop_id IS NULL OR p_shop_id <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mã cửa hàng không hợp lệ (phải là số nguyên dương).';
    END IF;

    SELECT ShopStatus INTO v_shop_status FROM SHOP WHERE ShopID = p_shop_id;
    IF v_shop_status IS NULL THEN
        SET v_msg = CONCAT('Cửa hàng ', p_shop_id, ' không tồn tại.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_shop_status NOT IN ('ACTIVE', 'WARNED') THEN
        SET v_msg = CONCAT('Cửa hàng ', p_shop_id, ' đang ', v_shop_status,
                           ', không được sửa sản phẩm.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Không đổi cửa hàng nếu sản phẩm đã bán hoặc đang trong giỏ
    IF p_shop_id <> v_old_shop THEN
        IF EXISTS (SELECT 1 FROM ORDER_ITEM WHERE ProductID = p_product_id) THEN
            SET v_msg = CONCAT('Sản phẩm ', p_product_id,
                               ' đã phát sinh đơn hàng, không được đổi cửa hàng.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
        IF EXISTS (SELECT 1 FROM CART_ITEM WHERE ProductID = p_product_id) THEN
            SET v_msg = CONCAT('Sản phẩm ', p_product_id,
                               ' đang có trong giỏ hàng, không được đổi cửa hàng.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;

    -- Danh mục phải tồn tại và là danh mục lá
    IF p_category_id IS NULL OR p_category_id <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mã danh mục không hợp lệ (phải là số nguyên dương).';
    END IF;

    SELECT CategoryName INTO v_category_name
      FROM CATEGORY WHERE CategoryID = p_category_id;
    IF v_category_name IS NULL THEN
        SET v_msg = CONCAT('Danh mục ', p_category_id, ' không tồn tại.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT COUNT(*) INTO v_child_count
      FROM CATEGORY WHERE ParentCategoryID = p_category_id;
    IF v_child_count > 0 THEN
        SET v_msg = CONCAT('Danh mục "', v_category_name,
                           '" còn danh mục con; hãy chọn danh mục lá.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Tên sản phẩm
    IF v_name = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tên sản phẩm không được để trống.';
    END IF;
    IF CHAR_LENGTH(v_name) > 200 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tên sản phẩm không được vượt quá 200 ký tự.';
    END IF;

    -- Không trùng tên trong cùng cửa hàng
    SELECT ProductID INTO v_dup_id
      FROM PRODUCT
     WHERE ShopID = p_shop_id
       AND ProductName = v_name
       AND ProductID <> p_product_id
     LIMIT 1;
    IF v_dup_id IS NOT NULL THEN
        SET v_msg = CONCAT('Cửa hàng đã có sản phẩm cùng tên (ProductID = ',
                           v_dup_id, ').');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Mô tả và trạng thái
    IF CHAR_LENGTH(IFNULL(p_description, '')) > 5000 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mô tả sản phẩm không được vượt quá 5.000 ký tự.';
    END IF;
    IF v_status NOT IN ('ACTIVE', 'HIDDEN', 'INACTIVE', 'BANNED') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Trạng thái không hợp lệ (ACTIVE/HIDDEN/INACTIVE/BANNED).';
    END IF;

    UPDATE PRODUCT
       SET ShopID        = p_shop_id,
           CategoryID    = p_category_id,
           ProductName   = v_name,
           Description   = NULLIF(TRIM(p_description), ''),
           ProductStatus = v_status
     WHERE ProductID = p_product_id;
END$$

-- - DELETE PRODUCT
-- Chỉ xóa khi chưa bán và không có trong giỏ hàng
CREATE PROCEDURE sp_product_xoa(
    IN p_product_id INT
)
BEGIN
    DECLARE v_name        VARCHAR(200) DEFAULT NULL;
    DECLARE v_order_count INT DEFAULT 0;
    DECLARE v_cart_count  INT DEFAULT 0;
    DECLARE v_msg         VARCHAR(128);

    IF p_product_id IS NULL OR p_product_id <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mã sản phẩm không hợp lệ (phải là số nguyên dương).';
    END IF;

    SELECT ProductName INTO v_name
      FROM PRODUCT WHERE ProductID = p_product_id;
    IF v_name IS NULL THEN
        SET v_msg = CONCAT('Sản phẩm ', p_product_id, ' không tồn tại.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT COUNT(*) INTO v_order_count
      FROM ORDER_ITEM WHERE ProductID = p_product_id;
    IF v_order_count > 0 THEN
        SET v_msg = CONCAT('Không thể xóa sản phẩm ', p_product_id,
                           ': đã phát sinh đơn hàng. Hãy chuyển INACTIVE/HIDDEN.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT COUNT(*) INTO v_cart_count
      FROM CART_ITEM WHERE ProductID = p_product_id;
    IF v_cart_count > 0 THEN
        SET v_msg = CONCAT('Không thể xóa sản phẩm ', p_product_id,
                           ': đang có trong giỏ hàng. Hãy chuyển INACTIVE/HIDDEN.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    DELETE FROM PRODUCT WHERE ProductID = p_product_id;
END$$

DELIMITER ;

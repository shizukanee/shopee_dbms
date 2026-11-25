-- Active: 1795604678545@@127.0.0.1@3306@shopee_db
SET NAMES utf8mb4;
DROP DATABASE IF EXISTS shopee_db;
CREATE DATABASE shopee_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE shopee_db;

-- =====================================================================
-- PHẦN A. TẠO BẢNG (19 bảng theo lược đồ quan hệ BTL1)
-- =====================================================================

-- 1. USER (Người dùng) ---------------------------------------------------
CREATE TABLE `USER` (
    UserID          INT             NOT NULL AUTO_INCREMENT,
    Email           VARCHAR(100)    NOT NULL,
    Phone           VARCHAR(15)     NOT NULL,
    LastName        VARCHAR(50)     NOT NULL,
    MiddleName      VARCHAR(50)     NULL,
    FirstName       VARCHAR(50)     NOT NULL,
    PasswordHash    VARCHAR(255)    NOT NULL,
    RegisterDate    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- ACTIVE: hoạt động | WARNED: bị cảnh báo | RESTRICTED: bị hạn chế | LOCKED: bị khóa
    AccountStatus   VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT pk_user          PRIMARY KEY (UserID),
    CONSTRAINT uq_user_email    UNIQUE (Email),
    CONSTRAINT uq_user_phone    UNIQUE (Phone),
    CONSTRAINT ck_user_email    CHECK (Email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    CONSTRAINT ck_user_phone    CHECK (Phone REGEXP '^0[0-9]{9}$'),
    CONSTRAINT ck_user_status   CHECK (AccountStatus IN ('ACTIVE','WARNED','RESTRICTED','LOCKED'))
) ENGINE = InnoDB;

-- 2. BUYER (Người mua) - lớp con của USER ---------------------------------
CREATE TABLE BUYER (
    UserID          INT             NOT NULL,
    -- BRONZE: Đồng | SILVER: Bạc | GOLD: Vàng | DIAMOND: Kim cương
    MembershipTier  VARCHAR(20)     NOT NULL DEFAULT 'BRONZE',
    RewardPoints    INT             NOT NULL DEFAULT 0,
    CONSTRAINT pk_buyer         PRIMARY KEY (UserID),
    CONSTRAINT fk_buyer_user    FOREIGN KEY (UserID) REFERENCES `USER`(UserID)
                                ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_buyer_tier    CHECK (MembershipTier IN ('BRONZE','SILVER','GOLD','DIAMOND')),
    CONSTRAINT ck_buyer_points  CHECK (RewardPoints >= 0)
) ENGINE = InnoDB;

-- 3. SELLER (Người bán) - lớp con của USER --------------------------------
CREATE TABLE SELLER (
    UserID              INT         NOT NULL,
    TaxCode             VARCHAR(14) NULL,           -- mã số thuế (nếu có)
    VerifiedDate        DATE        NULL,
    -- PENDING: chờ xác minh | VERIFIED: đã xác minh | REJECTED: bị từ chối
    VerificationStatus  VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    CONSTRAINT pk_seller            PRIMARY KEY (UserID),
    CONSTRAINT fk_seller_user       FOREIGN KEY (UserID) REFERENCES `USER`(UserID)
                                    ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uq_seller_taxcode    UNIQUE (TaxCode),
    CONSTRAINT ck_seller_taxcode    CHECK (TaxCode IS NULL OR TaxCode REGEXP '^[0-9]{10}(-?[0-9]{3})?$'),
    CONSTRAINT ck_seller_status     CHECK (VerificationStatus IN ('PENDING','VERIFIED','REJECTED')),
    -- Đã xác minh thì bắt buộc có ngày xác minh
    CONSTRAINT ck_seller_verified   CHECK (VerificationStatus <> 'VERIFIED' OR VerifiedDate IS NOT NULL)
) ENGINE = InnoDB;

-- 4. ADMIN (Quản trị viên) - lớp con của USER -----------------------------
CREATE TABLE `ADMIN` (
    UserID          INT             NOT NULL,
    EmployeeID      VARCHAR(10)     NOT NULL,
    HireDate        DATE            NOT NULL,
    AdminLevel      TINYINT         NOT NULL DEFAULT 1,   -- 1: nhân viên, 2: quản lý, 3: cấp cao
    CONSTRAINT pk_admin         PRIMARY KEY (UserID),
    CONSTRAINT fk_admin_user    FOREIGN KEY (UserID) REFERENCES `USER`(UserID)
                                ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uq_admin_empid   UNIQUE (EmployeeID),
    CONSTRAINT ck_admin_level   CHECK (AdminLevel BETWEEN 1 AND 3)
) ENGINE = InnoDB;

-- 5. SHOP (Cửa hàng) ------------------------------------------------------
CREATE TABLE SHOP (
    ShopID          INT             NOT NULL AUTO_INCREMENT,
    SellerID        INT             NOT NULL,
    ShopName        VARCHAR(100)    NOT NULL,
    Description     TEXT            NULL,
    Address         VARCHAR(255)    NOT NULL,
    EstablishedDate DATE            NOT NULL DEFAULT (CURRENT_DATE),
    -- ACTIVE: hoạt động | WARNED: cảnh báo | RESTRICTED: hạn chế | SUSPENDED: tạm khóa | CLOSED: đóng
    ShopStatus      VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT pk_shop          PRIMARY KEY (ShopID),
    -- SellerID UNIQUE: mỗi người bán sở hữu tối đa 1 cửa hàng (quan hệ OWNS 1-1)
    CONSTRAINT uq_shop_seller   UNIQUE (SellerID),
    CONSTRAINT fk_shop_seller   FOREIGN KEY (SellerID) REFERENCES SELLER(UserID)
                                ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_shop_name     CHECK (CHAR_LENGTH(TRIM(ShopName)) > 0),
    CONSTRAINT ck_shop_status   CHECK (ShopStatus IN ('ACTIVE','WARNED','RESTRICTED','SUSPENDED','CLOSED'))
) ENGINE = InnoDB;

-- 6. ADDRESS (Địa chỉ nhận hàng) -----------------------------------------
CREATE TABLE ADDRESS (
    AddressID       INT             NOT NULL AUTO_INCREMENT,
    BuyerID         INT             NOT NULL,
    RecipientName   VARCHAR(100)    NOT NULL,
    Phone           VARCHAR(15)     NOT NULL,
    DetailAddress   VARCHAR(255)    NOT NULL,
    Ward            VARCHAR(100)    NOT NULL,
    Province        VARCHAR(100)    NOT NULL,
    IsDefault       BOOLEAN         NOT NULL DEFAULT FALSE,
    -- Cột sinh ẩn: = BuyerID nếu là địa chỉ mặc định, ngược lại NULL.
    -- UNIQUE trên cột này => mỗi người mua có TỐI ĐA 1 địa chỉ mặc định
    -- (UNIQUE cho phép nhiều NULL), không cần trigger.
    DefaultOwnerID  INT GENERATED ALWAYS AS (IF(IsDefault, BuyerID, NULL)) VIRTUAL INVISIBLE,
    CONSTRAINT pk_address           PRIMARY KEY (AddressID),
    -- Khóa ứng viên (AddressID, BuyerID) để ORDER tham chiếu bằng khóa ngoại ghép
    CONSTRAINT uq_address_buyer     UNIQUE (AddressID, BuyerID),
    CONSTRAINT uq_address_default   UNIQUE (DefaultOwnerID),
    CONSTRAINT fk_address_buyer     FOREIGN KEY (BuyerID) REFERENCES BUYER(UserID)
                                    ON DELETE CASCADE,
    CONSTRAINT ck_address_phone     CHECK (Phone REGEXP '^0[0-9]{9}$')
) ENGINE = InnoDB;

-- 7. CATEGORY (Danh mục sản phẩm) - quan hệ đệ quy SUBCATEGORY_OF ---------
CREATE TABLE CATEGORY (
    CategoryID          INT             NOT NULL AUTO_INCREMENT,
    CategoryName        VARCHAR(100)    NOT NULL,
    Description         TEXT            NULL,
    ParentCategoryID    INT             NULL,       -- NULL = danh mục gốc
    CONSTRAINT pk_category          PRIMARY KEY (CategoryID),
    CONSTRAINT uq_category_name     UNIQUE (CategoryName),
    -- RESTRICT: không xóa danh mục còn danh mục con
    CONSTRAINT fk_category_parent   FOREIGN KEY (ParentCategoryID) REFERENCES CATEGORY(CategoryID)
                                    ON DELETE RESTRICT ON UPDATE CASCADE
    -- "Không tự làm cha / không có chu trình" -> trigger trg_category_bi/bu
    -- (MySQL không cho CHECK tham chiếu cột AUTO_INCREMENT)
) ENGINE = InnoDB;

-- 8. PRODUCT (Sản phẩm) ---------------------------------------------------
CREATE TABLE PRODUCT (
    ProductID       INT             NOT NULL AUTO_INCREMENT,
    ShopID          INT             NOT NULL,
    CategoryID      INT             NOT NULL,
    ProductName     VARCHAR(200)    NOT NULL,
    Description     TEXT            NULL,
    PostedDate      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- ACTIVE: đang bán | HIDDEN: tạm ẩn | INACTIVE: ngừng kinh doanh | BANNED: bị gỡ do vi phạm
    ProductStatus   VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT pk_product           PRIMARY KEY (ProductID),
    CONSTRAINT fk_product_shop      FOREIGN KEY (ShopID) REFERENCES SHOP(ShopID)
                                    ON DELETE RESTRICT ON UPDATE CASCADE,
    -- RESTRICT: không xóa danh mục đang có sản phẩm
    CONSTRAINT fk_product_category  FOREIGN KEY (CategoryID) REFERENCES CATEGORY(CategoryID)
                                    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_product_name      CHECK (CHAR_LENGTH(TRIM(ProductName)) > 0),
    CONSTRAINT ck_product_status    CHECK (ProductStatus IN ('ACTIVE','HIDDEN','INACTIVE','BANNED'))
) ENGINE = InnoDB;

-- 9. PRODUCT_IMAGE (Thuộc tính đa trị Images) ----------------------------
CREATE TABLE PRODUCT_IMAGE (
    ProductID       INT             NOT NULL,
    ImageURL        VARCHAR(500)    NOT NULL,
    CONSTRAINT pk_product_image     PRIMARY KEY (ProductID, ImageURL),
    CONSTRAINT fk_image_product     FOREIGN KEY (ProductID) REFERENCES PRODUCT(ProductID)
                                    ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_image_url         CHECK (ImageURL REGEXP '^https?://.+')
) ENGINE = InnoDB;

-- 10. PRODUCT_VARIANT (Phân loại sản phẩm - thực thể yếu) -----------------
CREATE TABLE PRODUCT_VARIANT (
    ProductID       INT             NOT NULL,
    VariantID       INT             NOT NULL,       -- khóa bộ phận (1, 2, 3... trong từng sản phẩm)
    Color           VARCHAR(50)     NULL,
    Size            VARCHAR(30)     NULL,
    Price           DECIMAL(15,2)   NOT NULL,
    StockQuantity   INT             NOT NULL DEFAULT 0,
    CONSTRAINT pk_variant           PRIMARY KEY (ProductID, VariantID),
    CONSTRAINT fk_variant_product   FOREIGN KEY (ProductID) REFERENCES PRODUCT(ProductID)
                                    ON DELETE CASCADE ON UPDATE CASCADE,
    -- Trong cùng sản phẩm, không có 2 phân loại trùng hoàn toàn (Color, Size)
    -- (dùng IFNULL để 2 giá trị NULL cũng bị coi là trùng)
    CONSTRAINT uq_variant_attr      UNIQUE (ProductID, (IFNULL(Color, '')), (IFNULL(Size, ''))),
    CONSTRAINT ck_variant_id        CHECK (VariantID > 0),
    CONSTRAINT ck_variant_price     CHECK (Price > 0),
    -- Tồn kho không âm; vì CHECK kiểm tra trên từng dòng tại thời điểm ghi
    -- nên kể cả nhiều đơn hàng đồng thời cũng không thể làm tồn kho < 0
    CONSTRAINT ck_variant_stock     CHECK (StockQuantity >= 0)
) ENGINE = InnoDB;

-- 11. CART (Giỏ hàng) -----------------------------------------------------
CREATE TABLE CART (
    CartID          INT             NOT NULL AUTO_INCREMENT,
    BuyerID         INT             NOT NULL,
    CONSTRAINT pk_cart          PRIMARY KEY (CartID),
    CONSTRAINT uq_cart_buyer    UNIQUE (BuyerID),          -- mỗi người mua tối đa 1 giỏ hàng
    CONSTRAINT fk_cart_buyer    FOREIGN KEY (BuyerID) REFERENCES BUYER(UserID)
                                ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

-- 12. CART_ITEM (Chi tiết giỏ hàng) ---------------------------------------
CREATE TABLE CART_ITEM (
    CartID          INT             NOT NULL,
    ProductID       INT             NOT NULL,
    VariantID       INT             NOT NULL,
    Quantity        INT             NOT NULL,
    -- PK đảm bảo mỗi phân loại chỉ xuất hiện 1 lần trong 1 giỏ hàng
    CONSTRAINT pk_cart_item         PRIMARY KEY (CartID, ProductID, VariantID),
    CONSTRAINT fk_cartitem_cart     FOREIGN KEY (CartID) REFERENCES CART(CartID)
                                    ON DELETE CASCADE,
    CONSTRAINT fk_cartitem_variant  FOREIGN KEY (ProductID, VariantID)
                                    REFERENCES PRODUCT_VARIANT(ProductID, VariantID)
                                    ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_cartitem_qty      CHECK (Quantity > 0)
) ENGINE = InnoDB;

-- 17. VOUCHER (Mã giảm giá) - tạo trước ORDER vì ORDER tham chiếu ----------
CREATE TABLE VOUCHER (
    VoucherID       INT             NOT NULL AUTO_INCREMENT,
    Code            VARCHAR(30)     NOT NULL,
    DiscountType    VARCHAR(10)     NOT NULL,       -- PERCENT: theo % | FIXED: số tiền cố định
    DiscountValue   DECIMAL(15,2)   NOT NULL,
    MinOrderValue   DECIMAL(15,2)   NOT NULL DEFAULT 0,
    StartTime       DATETIME        NOT NULL,
    EndTime         DATETIME        NOT NULL,
    MaxUsage        INT             NOT NULL,
    CONSTRAINT pk_voucher           PRIMARY KEY (VoucherID),
    CONSTRAINT uq_voucher_code      UNIQUE (Code),
    CONSTRAINT ck_voucher_type      CHECK (DiscountType IN ('PERCENT','FIXED')),
    CONSTRAINT ck_voucher_value     CHECK (DiscountValue > 0),
    CONSTRAINT ck_voucher_percent   CHECK (DiscountType <> 'PERCENT' OR DiscountValue <= 100),
    CONSTRAINT ck_voucher_minorder  CHECK (MinOrderValue >= 0),
    CONSTRAINT ck_voucher_period    CHECK (StartTime <= EndTime),
    CONSTRAINT ck_voucher_maxusage  CHECK (MaxUsage >= 0)
) ENGINE = InnoDB;

-- 13. ORDER (Đơn hàng) ----------------------------------------------------
CREATE TABLE `ORDER` (
    OrderID                 INT             NOT NULL AUTO_INCREMENT,
    BuyerID                 INT             NOT NULL,
    ShopID                  INT             NOT NULL,
    AddressID               INT             NOT NULL,
    VoucherID               INT             NULL,
    OrderDate               DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- PENDING: chờ xác nhận | CONFIRMED: đã xác nhận | PREPARING: đang chuẩn bị
    -- SHIPPING: đang giao | DELIVERED: đã giao | COMPLETED: hoàn thành | CANCELLED: đã hủy
    OrderStatus             VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    Note                    VARCHAR(500)    NULL,
    -- Bản sao địa chỉ giao hàng tại thời điểm đặt (trigger tự sao chép từ ADDRESS)
    RecipientName           VARCHAR(100)    NOT NULL,
    Phone                   VARCHAR(15)     NOT NULL,
    DetailAddress           VARCHAR(255)    NOT NULL,
    Ward                    VARCHAR(100)    NOT NULL,
    Province                VARCHAR(100)    NOT NULL,
    AppliedDiscountAmount   DECIMAL(15,2)   NOT NULL DEFAULT 0,
    ShippingFeeAtOrder      DECIMAL(15,2)   NOT NULL DEFAULT 0,
    -- Thuộc tính dẫn xuất (EERD): = SUM(Quantity*UnitPrice) + ShippingFeeAtOrder - AppliedDiscountAmount
    -- Cột được thêm để lưu giá trị; trigger tính toán do TV2 viết (câu 2.2.2)
    TotalAmount             DECIMAL(15,2)   NOT NULL DEFAULT 0,
    CONSTRAINT pk_order             PRIMARY KEY (OrderID),
    -- Khóa ứng viên để REVIEW, COMPLAINT kiểm tra "người mua là chủ đơn" bằng FK ghép
    CONSTRAINT uq_order_buyer       UNIQUE (OrderID, BuyerID),
    CONSTRAINT fk_order_buyer       FOREIGN KEY (BuyerID) REFERENCES BUYER(UserID)
                                    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_order_shop        FOREIGN KEY (ShopID) REFERENCES SHOP(ShopID)
                                    ON DELETE RESTRICT ON UPDATE CASCADE,
    -- FK ghép: địa chỉ được chọn phải thuộc chính người mua tạo đơn
    CONSTRAINT fk_order_address     FOREIGN KEY (AddressID, BuyerID)
                                    REFERENCES ADDRESS(AddressID, BuyerID)
                                    ON DELETE RESTRICT,
    CONSTRAINT fk_order_voucher     FOREIGN KEY (VoucherID) REFERENCES VOUCHER(VoucherID)
                                    ON DELETE RESTRICT,
    CONSTRAINT ck_order_status      CHECK (OrderStatus IN ('PENDING','CONFIRMED','PREPARING',
                                                           'SHIPPING','DELIVERED','COMPLETED','CANCELLED')),
    CONSTRAINT ck_order_discount    CHECK (AppliedDiscountAmount >= 0),
    CONSTRAINT ck_order_shipfee     CHECK (ShippingFeeAtOrder >= 0),
    CONSTRAINT ck_order_total       CHECK (TotalAmount >= 0),          -- tổng tiền không âm
    -- Không dùng voucher thì không có tiền giảm
    CONSTRAINT ck_order_novoucher   CHECK (VoucherID IS NOT NULL OR AppliedDiscountAmount = 0),
    CONSTRAINT ck_order_phone       CHECK (Phone REGEXP '^0[0-9]{9}$')
) ENGINE = InnoDB;

-- 14. ORDER_ITEM (Chi tiết đơn hàng - thực thể yếu) -----------------------
CREATE TABLE ORDER_ITEM (
    OrderID         INT             NOT NULL,
    ItemID          INT             NOT NULL,       -- khóa bộ phận; để NULL/0 thì trigger tự đánh số
    ProductID       INT             NOT NULL,
    VariantID       INT             NOT NULL,
    Quantity        INT             NOT NULL,
    UnitPrice       DECIMAL(15,2)   NOT NULL,       -- trigger tự lấy giá hiện tại khi thêm
    -- Subtotal = Quantity * UnitPrice là thuộc tính dẫn xuất, không lưu (theo BTL1)
    CONSTRAINT pk_order_item        PRIMARY KEY (OrderID, ItemID),
    CONSTRAINT uq_orderitem_variant UNIQUE (OrderID, ProductID, VariantID),
    CONSTRAINT fk_orderitem_order   FOREIGN KEY (OrderID) REFERENCES `ORDER`(OrderID)
                                    ON DELETE CASCADE,
    -- RESTRICT: không xóa phân loại đã từng được bán (chuyển sản phẩm sang INACTIVE)
    CONSTRAINT fk_orderitem_variant FOREIGN KEY (ProductID, VariantID)
                                    REFERENCES PRODUCT_VARIANT(ProductID, VariantID)
                                    ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_orderitem_itemid  CHECK (ItemID > 0),
    CONSTRAINT ck_orderitem_qty     CHECK (Quantity > 0),
    CONSTRAINT ck_orderitem_price   CHECK (UnitPrice >= 0)
) ENGINE = InnoDB;

-- 15. PAYMENT (Giao dịch thanh toán) --------------------------------------
CREATE TABLE PAYMENT (
    PaymentID       INT             NOT NULL AUTO_INCREMENT,
    OrderID         INT             NOT NULL,
    Method          VARCHAR(20)     NOT NULL,   -- COD: khi nhận hàng | E_WALLET: ví điện tử | BANK_TRANSFER: chuyển khoản
    Amount          DECIMAL(15,2)   NOT NULL,
    PaymentTime     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- PENDING: chờ | SUCCESS: thành công | FAILED: thất bại | REFUNDED: đã hoàn tiền
    PaymentStatus   VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    -- Cột sinh ẩn: = OrderID nếu giao dịch thành công, ngược lại NULL.
    -- UNIQUE => mỗi đơn hàng có TỐI ĐA 1 giao dịch SUCCESS.
    SuccessOrderID  INT GENERATED ALWAYS AS (IF(PaymentStatus = 'SUCCESS', OrderID, NULL)) VIRTUAL INVISIBLE,
    CONSTRAINT pk_payment           PRIMARY KEY (PaymentID),
    CONSTRAINT uq_payment_success   UNIQUE (SuccessOrderID),
    CONSTRAINT fk_payment_order     FOREIGN KEY (OrderID) REFERENCES `ORDER`(OrderID)
                                    ON DELETE RESTRICT,
    CONSTRAINT ck_payment_method    CHECK (Method IN ('COD','E_WALLET','BANK_TRANSFER')),
    CONSTRAINT ck_payment_amount    CHECK (Amount >= 0),
    CONSTRAINT ck_payment_status    CHECK (PaymentStatus IN ('PENDING','SUCCESS','FAILED','REFUNDED'))
) ENGINE = InnoDB;

-- 16. SHIPMENT (Thông tin vận chuyển) -------------------------------------
CREATE TABLE SHIPMENT (
    ShipmentID      INT             NOT NULL AUTO_INCREMENT,
    OrderID         INT             NOT NULL,
    TrackingNumber  VARCHAR(30)     NOT NULL,
    Carrier         VARCHAR(50)     NOT NULL,
    ShippingFee     DECIMAL(15,2)   NOT NULL DEFAULT 0,
    EstimatedDate   DATE            NULL,
    ActualDate      DATETIME        NULL,
    -- WAITING_PICKUP: chờ lấy hàng | IN_TRANSIT: đang giao | DELIVERED: giao thành công
    -- FAILED: giao thất bại | RETURNED: hoàn hàng
    ShipmentStatus  VARCHAR(20)     NOT NULL DEFAULT 'WAITING_PICKUP',
    CONSTRAINT pk_shipment          PRIMARY KEY (ShipmentID),
    CONSTRAINT uq_shipment_order    UNIQUE (OrderID),            -- quan hệ HAS_SHIPMENT 1-1
    CONSTRAINT uq_shipment_tracking UNIQUE (TrackingNumber),
    CONSTRAINT fk_shipment_order    FOREIGN KEY (OrderID) REFERENCES `ORDER`(OrderID)
                                    ON DELETE RESTRICT,
    CONSTRAINT ck_shipment_fee      CHECK (ShippingFee >= 0),
    CONSTRAINT ck_shipment_status   CHECK (ShipmentStatus IN ('WAITING_PICKUP','IN_TRANSIT',
                                                              'DELIVERED','FAILED','RETURNED')),
    -- Giao thành công thì bắt buộc có ngày giao thực tế
    CONSTRAINT ck_shipment_delivered CHECK (ShipmentStatus <> 'DELIVERED' OR ActualDate IS NOT NULL)
) ENGINE = InnoDB;

-- 18. REVIEW (Đánh giá) ---------------------------------------------------
CREATE TABLE REVIEW (
    OrderID         INT             NOT NULL,
    ItemID          INT             NOT NULL,
    BuyerID         INT             NOT NULL,
    Rating          TINYINT         NOT NULL,
    Comment         TEXT            NULL,
    ReviewTime      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- PK = khóa của ORDER_ITEM => mỗi chi tiết đơn được đánh giá tối đa 1 lần
    CONSTRAINT pk_review            PRIMARY KEY (OrderID, ItemID),
    CONSTRAINT fk_review_item       FOREIGN KEY (OrderID, ItemID) REFERENCES ORDER_ITEM(OrderID, ItemID)
                                    ON DELETE RESTRICT,
    CONSTRAINT fk_review_buyer      FOREIGN KEY (BuyerID) REFERENCES BUYER(UserID)
                                    ON DELETE RESTRICT,
    -- FK ghép: người đánh giá phải là người mua của đơn hàng chứa chi tiết đó
    CONSTRAINT fk_review_orderowner FOREIGN KEY (OrderID, BuyerID) REFERENCES `ORDER`(OrderID, BuyerID)
                                    ON DELETE RESTRICT,
    CONSTRAINT ck_review_rating     CHECK (Rating BETWEEN 1 AND 5)
) ENGINE = InnoDB;

-- 19. COMPLAINT (Khiếu nại) -----------------------------------------------
CREATE TABLE COMPLAINT (
    ComplaintID     INT             NOT NULL AUTO_INCREMENT,
    BuyerID         INT             NOT NULL,
    OrderID         INT             NOT NULL,
    AdminID         INT             NULL,           -- NULL = chưa phân công
    -- WRONG_ITEM: giao sai | DAMAGED: hư hỏng | NOT_AS_DESCRIBED: không đúng mô tả
    -- NOT_RECEIVED: chưa nhận hàng | OTHER: khác
    ComplaintType   VARCHAR(20)     NOT NULL,
    Content         TEXT            NOT NULL,
    SubmitTime      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- PENDING: chờ xử lý | PROCESSING: đang xử lý | RESOLVED: đã giải quyết | REJECTED: từ chối
    Status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING',
    Resolution      TEXT            NULL,
    ResolvedTime    DATETIME        NULL,
    CONSTRAINT pk_complaint             PRIMARY KEY (ComplaintID),
    CONSTRAINT fk_complaint_buyer       FOREIGN KEY (BuyerID) REFERENCES BUYER(UserID)
                                        ON DELETE RESTRICT,
    -- FK ghép: người gửi khiếu nại phải là người mua sở hữu đơn hàng
    CONSTRAINT fk_complaint_orderowner  FOREIGN KEY (OrderID, BuyerID) REFERENCES `ORDER`(OrderID, BuyerID)
                                        ON DELETE RESTRICT,
    CONSTRAINT fk_complaint_admin       FOREIGN KEY (AdminID) REFERENCES `ADMIN`(UserID)
                                        ON DELETE RESTRICT,
    CONSTRAINT ck_complaint_type        CHECK (ComplaintType IN ('WRONG_ITEM','DAMAGED','NOT_AS_DESCRIBED',
                                                                 'NOT_RECEIVED','OTHER')),
    CONSTRAINT ck_complaint_status      CHECK (Status IN ('PENDING','PROCESSING','RESOLVED','REJECTED')),
    -- Chưa phân công quản trị viên thì phải ở trạng thái chờ xử lý
    CONSTRAINT ck_complaint_assign      CHECK (AdminID IS NOT NULL OR Status = 'PENDING'),
    -- Đã xử lý xong (RESOLVED/REJECTED) <=> có kết quả và thời gian hoàn tất
    CONSTRAINT ck_complaint_resolved    CHECK (
        (Status IN ('RESOLVED','REJECTED') AND Resolution IS NOT NULL AND ResolvedTime IS NOT NULL)
     OR (Status IN ('PENDING','PROCESSING') AND Resolution IS NULL AND ResolvedTime IS NULL)),
    -- Thời gian hoàn tất không sớm hơn thời gian gửi
    CONSTRAINT ck_complaint_time        CHECK (ResolvedTime IS NULL OR ResolvedTime >= SubmitTime)
) ENGINE = InnoDB;


-- =====================================================================
-- PHẦN B. TRIGGER CHO CÁC RÀNG BUỘC NGỮ NGHĨA KHÔNG KHAI BÁO ĐƯỢC BẰNG CHECK
-- =====================================================================
--  RB1  Chuyên biệt hóa toàn phần: USER phải thuộc ít nhất 1 vai trò
--  RB2  Chỉ người bán đã xác minh mới được tạo cửa hàng
--  RB3  Cây danh mục không có chu trình
--  RB4  Mỗi sản phẩm có ít nhất 1 phân loại
--  RB5  Cửa hàng phải đang hoạt động khi đặt hàng; sao lưu địa chỉ giao hàng
--  RB6  Điều kiện dùng voucher: thời hạn, số lượt, giá trị tối thiểu, mức giảm hợp lệ
--  RB7  Vòng đời trạng thái đơn hàng; đơn đã chốt không đổi số tiền/địa chỉ
--  RB8  Chi tiết đơn: cùng cửa hàng, sản phẩm đang bán, đủ tồn kho, giữ đơn giá
--  RB9  Thanh toán thành công: đơn không bị hủy, số tiền = tổng tiền đơn
--  RB10 Vận chuyển: ngày hợp lệ, đơn đã hủy không được giao
--  RB11 Đánh giá: chỉ cho đơn đã hoàn thành
--  RB12 Khiếu nại: gửi sau khi đặt đơn; khiếu nại đã đóng không được sửa
--  (Các ràng buộc còn lại đã dùng CHECK/UNIQUE/FK ghép ở phần A)
-- =====================================================================

DELIMITER $$

-- ---------------------------------------------------------------------
-- RB1. Chuyên biệt hóa toàn phần USER -> {BUYER, SELLER, ADMIN}
--  Không cho xóa vai trò cuối cùng của 1 người dùng (muốn xóa hẳn thì
--  xóa ở bảng USER; xóa lan truyền ON DELETE CASCADE không kích hoạt trigger).
--  Khi tạo mới, ứng dụng/thủ tục phải thêm USER và vai trò trong cùng 1 giao tác.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_buyer_bd BEFORE DELETE ON BUYER
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM SELLER  WHERE UserID = OLD.UserID)
       AND NOT EXISTS (SELECT 1 FROM `ADMIN` WHERE UserID = OLD.UserID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể xóa vai trò BUYER: đây là vai trò duy nhất của người dùng (mỗi USER phải có ít nhất 1 vai trò).';
    END IF;
END$$

CREATE TRIGGER trg_seller_bd BEFORE DELETE ON SELLER
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM BUYER   WHERE UserID = OLD.UserID)
       AND NOT EXISTS (SELECT 1 FROM `ADMIN` WHERE UserID = OLD.UserID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể xóa vai trò SELLER: đây là vai trò duy nhất của người dùng (mỗi USER phải có ít nhất 1 vai trò).';
    END IF;
END$$

CREATE TRIGGER trg_admin_bd BEFORE DELETE ON `ADMIN`
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM BUYER  WHERE UserID = OLD.UserID)
       AND NOT EXISTS (SELECT 1 FROM SELLER WHERE UserID = OLD.UserID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không thể xóa vai trò ADMIN: đây là vai trò duy nhất của người dùng (mỗi USER phải có ít nhất 1 vai trò).';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB2. Chỉ người bán có VerificationStatus = 'VERIFIED' mới được tạo cửa hàng
--  DML gây vi phạm: INSERT SHOP, UPDATE SHOP.SellerID
-- ---------------------------------------------------------------------
CREATE PROCEDURE chk_seller_verified(IN p_seller_id INT)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_msg    VARCHAR(128);
    SET v_status = (SELECT VerificationStatus FROM SELLER WHERE UserID = p_seller_id);
    IF v_status IS NULL THEN
        SET v_msg = CONCAT('Người dùng ', p_seller_id, ' chưa đăng ký vai trò người bán (SELLER).');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    ELSEIF v_status <> 'VERIFIED' THEN
        SET v_msg = CONCAT('Người bán ', p_seller_id, ' chưa được xác minh (trạng thái: ', v_status,
                           ') nên không được tạo cửa hàng.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_shop_bi BEFORE INSERT ON SHOP
FOR EACH ROW
BEGIN
    CALL chk_seller_verified(NEW.SellerID);
END$$

CREATE TRIGGER trg_shop_bu BEFORE UPDATE ON SHOP
FOR EACH ROW
BEGIN
    IF NEW.SellerID <> OLD.SellerID THEN
        CALL chk_seller_verified(NEW.SellerID);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB3. Cây danh mục không có chu trình (kể cả tự làm cha của chính nó)
--  DML gây vi phạm: INSERT/UPDATE CATEGORY.ParentCategoryID
--  Cách kiểm tra: đi ngược từ danh mục cha mới lên gốc, nếu gặp lại
--  chính danh mục đang sửa thì sẽ tạo chu trình.
-- ---------------------------------------------------------------------
CREATE PROCEDURE chk_category_no_cycle(IN p_category_id INT, IN p_parent_id INT)
BEGIN
    DECLARE v_current INT DEFAULT p_parent_id;
    DECLARE v_depth   INT DEFAULT 0;
    DECLARE v_msg     VARCHAR(128);

    IF p_parent_id IS NOT NULL AND p_parent_id = p_category_id THEN
        SET v_msg = CONCAT('Danh mục ', p_category_id, ' không thể là danh mục cha của chính nó.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    WHILE v_current IS NOT NULL DO
        IF v_current = p_category_id THEN
            SET v_msg = CONCAT('Không thể đặt danh mục ', p_parent_id, ' làm cha của danh mục ',
                               p_category_id, ' vì sẽ tạo chu trình trong cây danh mục.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
        SET v_depth = v_depth + 1;
        IF v_depth > 100 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cây danh mục quá sâu (> 100 cấp) hoặc dữ liệu đang có chu trình.';
        END IF;
        SET v_current = (SELECT ParentCategoryID FROM CATEGORY WHERE CategoryID = v_current);
    END WHILE;
END$$

CREATE TRIGGER trg_category_bi BEFORE INSERT ON CATEGORY
FOR EACH ROW
BEGIN
    CALL chk_category_no_cycle(NEW.CategoryID, NEW.ParentCategoryID);
END$$

CREATE TRIGGER trg_category_bu BEFORE UPDATE ON CATEGORY
FOR EACH ROW
BEGIN
    IF NOT (NEW.ParentCategoryID <=> OLD.ParentCategoryID) OR NEW.CategoryID <> OLD.CategoryID THEN
        CALL chk_category_no_cycle(NEW.CategoryID, NEW.ParentCategoryID);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB4. Mỗi sản phẩm phải có ít nhất 1 phân loại
--  DML gây vi phạm: DELETE PRODUCT_VARIANT, UPDATE PRODUCT_VARIANT.ProductID
--  (Xóa cả PRODUCT thì phân loại bị xóa lan truyền - hợp lệ.)
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_variant_bd BEFORE DELETE ON PRODUCT_VARIANT
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(128);
    IF (SELECT COUNT(*) FROM PRODUCT_VARIANT WHERE ProductID = OLD.ProductID) <= 1 THEN
        SET v_msg = CONCAT('Không thể xóa phân loại cuối cùng của sản phẩm ', OLD.ProductID,
                           '. Hãy chuyển sản phẩm sang INACTIVE.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_variant_bu BEFORE UPDATE ON PRODUCT_VARIANT
FOR EACH ROW
BEGIN
    IF NEW.ProductID <> OLD.ProductID THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được chuyển phân loại sang sản phẩm khác (phân loại là thực thể yếu của sản phẩm).';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB6. Kiểm tra voucher còn dùng được (thời hạn + số lượt còn lại)
--  Dùng chung cho INSERT ORDER và UPDATE ORDER.VoucherID.
--  SELECT ... FOR UPDATE khóa dòng voucher để 2 đơn đồng thời không
--  cùng vượt MaxUsage.
-- ---------------------------------------------------------------------
CREATE PROCEDURE chk_voucher_usable(IN p_voucher_id INT, IN p_order_date DATETIME, IN p_order_id INT)
BEGIN
    DECLARE v_code  VARCHAR(30);
    DECLARE v_start DATETIME;
    DECLARE v_end   DATETIME;
    DECLARE v_max   INT;
    DECLARE v_used  INT;
    DECLARE v_msg   VARCHAR(128);

    SELECT Code, StartTime, EndTime, MaxUsage
      INTO v_code, v_start, v_end, v_max
      FROM VOUCHER WHERE VoucherID = p_voucher_id
       FOR UPDATE;

    IF v_code IS NULL THEN
        SET v_msg = CONCAT('Mã giảm giá ', p_voucher_id, ' không tồn tại.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF p_order_date < v_start OR p_order_date > v_end THEN
        SET v_msg = CONCAT('Voucher ', v_code, ' chỉ có hiệu lực từ ', DATE_FORMAT(v_start, '%d/%m/%Y'),
                           ' đến ', DATE_FORMAT(v_end, '%d/%m/%Y'), '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT COUNT(*) INTO v_used
      FROM `ORDER`
     WHERE VoucherID = p_voucher_id
       AND OrderStatus <> 'CANCELLED'
       AND OrderID <> IFNULL(p_order_id, 0);

    IF v_used >= v_max THEN
        SET v_msg = CONCAT('Voucher ', v_code, ' đã hết lượt sử dụng (', v_used, '/', v_max, ').');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

-- RB6 (tiếp). Khi đơn được xác nhận: đủ giá trị tối thiểu và mức giảm hợp lệ
CREATE PROCEDURE chk_voucher_amount(IN p_order_id INT, IN p_voucher_id INT, IN p_discount DECIMAL(15,2))
BEGIN
    DECLARE v_code      VARCHAR(30);
    DECLARE v_type      VARCHAR(10);
    DECLARE v_value     DECIMAL(15,2);
    DECLARE v_min       DECIMAL(15,2);
    DECLARE v_subtotal  DECIMAL(15,2);
    DECLARE v_max_disc  DECIMAL(15,2);
    DECLARE v_msg       VARCHAR(128);

    SELECT IFNULL(SUM(Quantity * UnitPrice), 0) INTO v_subtotal
      FROM ORDER_ITEM WHERE OrderID = p_order_id;

    IF p_voucher_id IS NOT NULL THEN
        SELECT Code, DiscountType, DiscountValue, MinOrderValue
          INTO v_code, v_type, v_value, v_min
          FROM VOUCHER WHERE VoucherID = p_voucher_id;

        IF v_subtotal < v_min THEN
            SET v_msg = CONCAT('Đơn hàng ', p_order_id, ' có tiền hàng ', FORMAT(v_subtotal, 0),
                               ' < giá trị tối thiểu ', FORMAT(v_min, 0), ' của voucher ', v_code, '.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        SET v_max_disc = IF(v_type = 'PERCENT', ROUND(v_subtotal * v_value / 100, 2), v_value);
        SET v_max_disc = LEAST(v_max_disc, v_subtotal);
        IF p_discount > v_max_disc THEN
            SET v_msg = CONCAT('Số tiền giảm ', FORMAT(p_discount, 0), ' vượt mức tối đa ',
                               FORMAT(v_max_disc, 0), ' của voucher ', v_code, '.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB5 + RB6. Tạo đơn hàng
--  - Đơn mới phải ở trạng thái PENDING (chi tiết đơn được thêm sau)
--  - Cửa hàng tiếp nhận phải đang hoạt động
--  - Sao lưu địa chỉ giao hàng tại thời điểm đặt từ ADDRESS
--    (quyền sở hữu địa chỉ đã được FK ghép fk_order_address bảo đảm;
--     ở đây chỉ báo lỗi rõ ràng trước khi sao chép)
--  - Voucher còn hiệu lực và còn lượt
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_order_bi BEFORE INSERT ON `ORDER`
FOR EACH ROW
BEGIN
    DECLARE v_shop_status VARCHAR(20);
    DECLARE v_msg         VARCHAR(128);
    DECLARE v_name     VARCHAR(100);
    DECLARE v_phone    VARCHAR(15);
    DECLARE v_detail   VARCHAR(255);
    DECLARE v_ward     VARCHAR(100);
    DECLARE v_province VARCHAR(100);

    IF NEW.OrderStatus <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Đơn hàng mới phải có trạng thái PENDING; thêm chi tiết đơn rồi mới cập nhật trạng thái.';
    END IF;

    SET v_shop_status = (SELECT ShopStatus FROM SHOP WHERE ShopID = NEW.ShopID);
    IF v_shop_status IS NOT NULL AND v_shop_status NOT IN ('ACTIVE','WARNED') THEN
        SET v_msg = CONCAT('Cửa hàng ', NEW.ShopID, ' đang ở trạng thái ', v_shop_status, ', không thể nhận đơn hàng.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ADDRESS WHERE AddressID = NEW.AddressID AND BuyerID = NEW.BuyerID) THEN
        SET v_msg = CONCAT('Địa chỉ ', NEW.AddressID, ' không thuộc người mua ', NEW.BuyerID, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Sao lưu địa chỉ giao hàng (bất biến về sau dù ADDRESS thay đổi)
    SELECT RecipientName, Phone, DetailAddress, Ward, Province
      INTO v_name, v_phone, v_detail, v_ward, v_province
      FROM ADDRESS WHERE AddressID = NEW.AddressID;
    SET NEW.RecipientName = v_name,   NEW.Phone = v_phone,
        NEW.DetailAddress = v_detail, NEW.Ward  = v_ward, NEW.Province = v_province;

    IF NEW.VoucherID IS NOT NULL THEN
        CALL chk_voucher_usable(NEW.VoucherID, NEW.OrderDate, NULL);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB7. Cập nhật đơn hàng
--  - Không đổi người mua / cửa hàng của đơn
--  - COMPLETED, CANCELLED là trạng thái cuối
--  - Chỉ hủy được trước khi bàn giao vận chuyển (PENDING/CONFIRMED/PREPARING)
--  - Không lùi trạng thái
--  - Rời PENDING: đơn phải có >= 1 chi tiết, thỏa điều kiện voucher
--  - Đơn đã xác nhận hoặc đã thanh toán: khóa địa chỉ, voucher, phí ship, tiền giảm
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_order_bu BEFORE UPDATE ON `ORDER`
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(128);
    DECLARE v_paid BOOLEAN;
    DECLARE v_name     VARCHAR(100);
    DECLARE v_phone    VARCHAR(15);
    DECLARE v_detail   VARCHAR(255);
    DECLARE v_ward     VARCHAR(100);
    DECLARE v_province VARCHAR(100);

    IF NEW.BuyerID <> OLD.BuyerID OR NEW.ShopID <> OLD.ShopID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không được thay đổi người mua hoặc cửa hàng của đơn hàng đã tạo.';
    END IF;

    IF NEW.OrderStatus <> OLD.OrderStatus THEN
        IF OLD.OrderStatus IN ('COMPLETED','CANCELLED') THEN
            SET v_msg = CONCAT('Đơn hàng ', OLD.OrderID, ' đã ', OLD.OrderStatus, ', không thể chuyển sang ', NEW.OrderStatus, '.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF NEW.OrderStatus = 'CANCELLED' AND OLD.OrderStatus IN ('SHIPPING','DELIVERED') THEN
            SET v_msg = CONCAT('Đơn hàng ', OLD.OrderID, ' đã bàn giao vận chuyển (', OLD.OrderStatus, '), không thể hủy.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF NEW.OrderStatus <> 'CANCELLED'
           AND FIELD(NEW.OrderStatus, 'PENDING','CONFIRMED','PREPARING','SHIPPING','DELIVERED','COMPLETED')
             < FIELD(OLD.OrderStatus, 'PENDING','CONFIRMED','PREPARING','SHIPPING','DELIVERED','COMPLETED') THEN
            SET v_msg = CONCAT('Không thể lùi trạng thái đơn hàng từ ', OLD.OrderStatus, ' về ', NEW.OrderStatus, '.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF OLD.OrderStatus = 'PENDING' AND NEW.OrderStatus <> 'CANCELLED' THEN
            IF NOT EXISTS (SELECT 1 FROM ORDER_ITEM WHERE OrderID = OLD.OrderID) THEN
                SET v_msg = CONCAT('Đơn hàng ', OLD.OrderID, ' chưa có sản phẩm nào, không thể xác nhận.');
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
            END IF;
            CALL chk_voucher_amount(OLD.OrderID, NEW.VoucherID, NEW.AppliedDiscountAmount);
        END IF;
    END IF;

    -- Khóa thông tin tiền / địa chỉ khi đơn đã chốt
    SET v_paid = EXISTS (SELECT 1 FROM PAYMENT WHERE OrderID = OLD.OrderID AND PaymentStatus = 'SUCCESS');
    IF (OLD.OrderStatus <> 'PENDING' OR v_paid)
       AND (   NEW.AddressID <> OLD.AddressID
            OR NOT (NEW.VoucherID <=> OLD.VoucherID)
            OR NEW.AppliedDiscountAmount <> OLD.AppliedDiscountAmount
            OR NEW.ShippingFeeAtOrder    <> OLD.ShippingFeeAtOrder
            OR NEW.OrderDate             <> OLD.OrderDate
            OR NEW.RecipientName <> OLD.RecipientName OR NEW.Phone    <> OLD.Phone
            OR NEW.DetailAddress <> OLD.DetailAddress OR NEW.Ward     <> OLD.Ward
            OR NEW.Province      <> OLD.Province) THEN
        SET v_msg = CONCAT('Đơn hàng ', OLD.OrderID, ' đã được xác nhận/thanh toán: không được sửa địa chỉ, voucher, phí ship, tiền giảm.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Đơn còn PENDING đổi địa chỉ: sao lưu lại địa chỉ mới
    IF NEW.AddressID <> OLD.AddressID THEN
        SELECT RecipientName, Phone, DetailAddress, Ward, Province
          INTO v_name, v_phone, v_detail, v_ward, v_province
          FROM ADDRESS WHERE AddressID = NEW.AddressID AND BuyerID = NEW.BuyerID;
        SET NEW.RecipientName = v_name,   NEW.Phone = v_phone,
            NEW.DetailAddress = v_detail, NEW.Ward  = v_ward, NEW.Province = v_province;
    END IF;

    -- Đơn còn PENDING đổi voucher: kiểm tra voucher mới
    IF NEW.VoucherID IS NOT NULL AND NOT (NEW.VoucherID <=> OLD.VoucherID) THEN
        CALL chk_voucher_usable(NEW.VoucherID, NEW.OrderDate, OLD.OrderID);
    END IF;
END$$

-- RB8 (hoàn kho). Đơn bị hủy -> trả lại số lượng đã giữ cho các phân loại
CREATE TRIGGER trg_order_au AFTER UPDATE ON `ORDER`
FOR EACH ROW
BEGIN
    IF NEW.OrderStatus = 'CANCELLED' AND OLD.OrderStatus <> 'CANCELLED' THEN
        UPDATE PRODUCT_VARIANT pv
          JOIN ORDER_ITEM oi ON oi.ProductID = pv.ProductID AND oi.VariantID = pv.VariantID
           SET pv.StockQuantity = pv.StockQuantity + oi.Quantity
         WHERE oi.OrderID = NEW.OrderID;
    END IF;
END$$

-- Chỉ được xóa đơn PENDING/CANCELLED (đơn đã giao dịch phải giữ lịch sử).
-- Xóa đơn PENDING thì hoàn kho trước (ORDER_ITEM bị xóa lan truyền không kích hoạt trigger).
CREATE TRIGGER trg_order_bd BEFORE DELETE ON `ORDER`
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(128);
    IF OLD.OrderStatus NOT IN ('PENDING','CANCELLED') THEN
        SET v_msg = CONCAT('Không được xóa đơn hàng ', OLD.OrderID, ' (', OLD.OrderStatus, '); chỉ có thể hủy đơn.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF OLD.OrderStatus = 'PENDING' THEN
        UPDATE PRODUCT_VARIANT pv
          JOIN ORDER_ITEM oi ON oi.ProductID = pv.ProductID AND oi.VariantID = pv.VariantID
           SET pv.StockQuantity = pv.StockQuantity + oi.Quantity
         WHERE oi.OrderID = OLD.OrderID;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB8. Chi tiết đơn hàng
--  - Chỉ thêm/sửa/xóa khi đơn PENDING và chưa thanh toán thành công
--  - Phân loại phải thuộc sản phẩm của CHÍNH cửa hàng nhận đơn
--  - Sản phẩm phải đang bán (ACTIVE)
--  - UnitPrice = giá hiện tại của phân loại tại thời điểm đặt, sau đó bất biến
--  - Giữ tồn kho: trừ tồn kho nguyên tử (UPDATE ... WHERE Stock >= SL),
--    nếu không trừ được thì báo không đủ hàng (an toàn khi đặt đồng thời)
-- ---------------------------------------------------------------------
CREATE PROCEDURE chk_order_editable(IN p_order_id INT)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_msg    VARCHAR(128);
    SET v_status = (SELECT OrderStatus FROM `ORDER` WHERE OrderID = p_order_id);
    IF v_status IS NULL THEN
        SET v_msg = CONCAT('Đơn hàng ', p_order_id, ' không tồn tại.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_status <> 'PENDING' THEN
        SET v_msg = CONCAT('Đơn hàng ', p_order_id, ' đang ở trạng thái ', v_status, ', không được thay đổi chi tiết đơn.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF EXISTS (SELECT 1 FROM PAYMENT WHERE OrderID = p_order_id AND PaymentStatus = 'SUCCESS') THEN
        SET v_msg = CONCAT('Đơn hàng ', p_order_id, ' đã thanh toán thành công, không được thay đổi chi tiết đơn.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE PROCEDURE reserve_stock(IN p_product_id INT, IN p_variant_id INT, IN p_qty INT)
BEGIN
    DECLARE v_stock INT;
    DECLARE v_msg   VARCHAR(128);
    UPDATE PRODUCT_VARIANT
       SET StockQuantity = StockQuantity - p_qty
     WHERE ProductID = p_product_id AND VariantID = p_variant_id
       AND StockQuantity >= p_qty;
    IF ROW_COUNT() = 0 THEN
        SET v_stock = (SELECT StockQuantity FROM PRODUCT_VARIANT
                        WHERE ProductID = p_product_id AND VariantID = p_variant_id);
        SET v_msg = CONCAT('Không đủ tồn kho cho phân loại (', p_product_id, ',', p_variant_id,
                           '): còn ', IFNULL(v_stock, 0), ', yêu cầu ', p_qty, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_orderitem_bi BEFORE INSERT ON ORDER_ITEM
FOR EACH ROW
BEGIN
    DECLARE v_order_shop   INT;
    DECLARE v_prod_shop    INT;
    DECLARE v_prod_status  VARCHAR(20);
    DECLARE v_price        DECIMAL(15,2);
    DECLARE v_msg          VARCHAR(128);

    CALL chk_order_editable(NEW.OrderID);

    SET v_order_shop = (SELECT ShopID FROM `ORDER` WHERE OrderID = NEW.OrderID);
    SELECT p.ShopID, p.ProductStatus, pv.Price
      INTO v_prod_shop, v_prod_status, v_price
      FROM PRODUCT_VARIANT pv JOIN PRODUCT p ON p.ProductID = pv.ProductID
     WHERE pv.ProductID = NEW.ProductID AND pv.VariantID = NEW.VariantID;

    IF v_price IS NULL THEN
        SET v_msg = CONCAT('Phân loại (', NEW.ProductID, ',', NEW.VariantID, ') không tồn tại.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_prod_shop <> v_order_shop THEN
        SET v_msg = CONCAT('Sản phẩm ', NEW.ProductID, ' thuộc cửa hàng ', v_prod_shop,
                           ', không thuộc cửa hàng ', v_order_shop, ' của đơn hàng ', NEW.OrderID, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_prod_status <> 'ACTIVE' THEN
        SET v_msg = CONCAT('Sản phẩm ', NEW.ProductID, ' đang ở trạng thái ', v_prod_status, ', không thể đặt mua.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- Đơn giá = giá bán tại thời điểm đặt hàng
    SET NEW.UnitPrice = v_price;

    -- Tự đánh số dòng chi tiết trong đơn nếu không truyền ItemID
    IF NEW.ItemID IS NULL OR NEW.ItemID = 0 THEN
        SET NEW.ItemID = (SELECT IFNULL(MAX(ItemID), 0) + 1 FROM ORDER_ITEM WHERE OrderID = NEW.OrderID);
    END IF;

    -- Giữ hàng (trừ tồn kho); Quantity <= 0 sẽ bị CHECK ck_orderitem_qty chặn
    IF NEW.Quantity > 0 THEN
        CALL reserve_stock(NEW.ProductID, NEW.VariantID, NEW.Quantity);
    END IF;
END$$

CREATE TRIGGER trg_orderitem_bu BEFORE UPDATE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    CALL chk_order_editable(OLD.OrderID);

    IF NEW.OrderID <> OLD.OrderID OR NEW.ItemID <> OLD.ItemID
       OR NEW.ProductID <> OLD.ProductID OR NEW.VariantID <> OLD.VariantID THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được đổi đơn hàng/phân loại của dòng chi tiết; hãy xóa dòng cũ và thêm dòng mới.';
    END IF;

    IF NEW.UnitPrice <> OLD.UnitPrice THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Đơn giá được ghi nhận tại thời điểm đặt hàng, không được thay đổi.';
    END IF;

    -- Điều chỉnh tồn kho theo chênh lệch số lượng
    IF NEW.Quantity > OLD.Quantity THEN
        CALL reserve_stock(NEW.ProductID, NEW.VariantID, NEW.Quantity - OLD.Quantity);
    ELSEIF NEW.Quantity < OLD.Quantity AND NEW.Quantity > 0 THEN
        UPDATE PRODUCT_VARIANT
           SET StockQuantity = StockQuantity + (OLD.Quantity - NEW.Quantity)
         WHERE ProductID = OLD.ProductID AND VariantID = OLD.VariantID;
    END IF;
END$$

CREATE TRIGGER trg_orderitem_bd BEFORE DELETE ON ORDER_ITEM
FOR EACH ROW
BEGIN
    CALL chk_order_editable(OLD.OrderID);
    UPDATE PRODUCT_VARIANT
       SET StockQuantity = StockQuantity + OLD.Quantity
     WHERE ProductID = OLD.ProductID AND VariantID = OLD.VariantID;
END$$

-- ---------------------------------------------------------------------
-- RB9. Thanh toán
--  - Không có giao dịch SUCCESS cho đơn đã hủy
--  - Số tiền giao dịch SUCCESS = tổng tiền đơn
--    (tính trực tiếp từ ORDER_ITEM, không phụ thuộc cột dẫn xuất TotalAmount)
--  (Tối đa 1 giao dịch SUCCESS / đơn: UNIQUE uq_payment_success)
-- ---------------------------------------------------------------------
CREATE PROCEDURE chk_payment(IN p_order_id INT, IN p_status VARCHAR(20), IN p_amount DECIMAL(15,2))
BEGIN
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_total        DECIMAL(15,2);
    DECLARE v_msg          VARCHAR(128);

    IF p_status = 'SUCCESS' THEN
        SELECT o.OrderStatus,
               IFNULL((SELECT SUM(oi.Quantity * oi.UnitPrice) FROM ORDER_ITEM oi WHERE oi.OrderID = o.OrderID), 0)
                 + o.ShippingFeeAtOrder - o.AppliedDiscountAmount
          INTO v_order_status, v_total
          FROM `ORDER` o WHERE o.OrderID = p_order_id;

        IF v_order_status = 'CANCELLED' THEN
            SET v_msg = CONCAT('Đơn hàng ', p_order_id, ' đã hủy, không thể ghi nhận thanh toán thành công.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;

        IF p_amount <> v_total THEN
            SET v_msg = CONCAT('Số tiền thanh toán ', FORMAT(p_amount, 0), ' khác tổng tiền đơn hàng ',
                               p_order_id, ' là ', FORMAT(v_total, 0), '.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_payment_bi BEFORE INSERT ON PAYMENT
FOR EACH ROW
BEGIN
    CALL chk_payment(NEW.OrderID, NEW.PaymentStatus, NEW.Amount);
END$$

CREATE TRIGGER trg_payment_bu BEFORE UPDATE ON PAYMENT
FOR EACH ROW
BEGIN
    IF NEW.OrderID <> OLD.OrderID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không được chuyển giao dịch thanh toán sang đơn hàng khác.';
    END IF;
    IF OLD.PaymentStatus IN ('FAILED','REFUNDED') AND NEW.PaymentStatus <> OLD.PaymentStatus THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Giao dịch thất bại/đã hoàn tiền không được đổi trạng thái; hãy tạo giao dịch mới.';
    END IF;
    IF NEW.PaymentStatus <> OLD.PaymentStatus OR NEW.Amount <> OLD.Amount THEN
        CALL chk_payment(NEW.OrderID, NEW.PaymentStatus, NEW.Amount);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB10. Vận chuyển
--  - Chỉ tạo vận chuyển cho đơn đã xác nhận (không PENDING, không CANCELLED)
--  - Đơn đã hủy không được chuyển sang IN_TRANSIT / DELIVERED
--  - ActualDate, EstimatedDate không sớm hơn ngày đặt hàng
--  (Giao thành công phải có ActualDate: CHECK ck_shipment_delivered)
-- ---------------------------------------------------------------------
CREATE PROCEDURE chk_shipment(IN p_order_id INT, IN p_status VARCHAR(20),
                              IN p_estimated DATE, IN p_actual DATETIME, IN p_is_insert BOOLEAN)
BEGIN
    DECLARE v_order_status VARCHAR(20);
    DECLARE v_order_date   DATETIME;
    DECLARE v_msg          VARCHAR(128);

    SELECT OrderStatus, OrderDate INTO v_order_status, v_order_date
      FROM `ORDER` WHERE OrderID = p_order_id;

    IF p_is_insert AND v_order_status IN ('PENDING','CANCELLED') THEN
        SET v_msg = CONCAT('Đơn hàng ', p_order_id, ' đang ', v_order_status, ', chưa thể tạo thông tin vận chuyển.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF v_order_status = 'CANCELLED' AND p_status IN ('IN_TRANSIT','DELIVERED') THEN
        SET v_msg = CONCAT('Đơn hàng ', p_order_id, ' đã bị hủy, không thể chuyển sang ', p_status, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF p_actual IS NOT NULL AND p_actual < v_order_date THEN
        SET v_msg = CONCAT('Ngày giao thực tế ', DATE_FORMAT(p_actual, '%d/%m/%Y'),
                           ' sớm hơn ngày đặt hàng ', DATE_FORMAT(v_order_date, '%d/%m/%Y'), '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF p_estimated IS NOT NULL AND p_estimated < DATE(v_order_date) THEN
        SET v_msg = CONCAT('Ngày giao dự kiến ', DATE_FORMAT(p_estimated, '%d/%m/%Y'),
                           ' sớm hơn ngày đặt hàng ', DATE_FORMAT(v_order_date, '%d/%m/%Y'), '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

CREATE TRIGGER trg_shipment_bi BEFORE INSERT ON SHIPMENT
FOR EACH ROW
BEGIN
    CALL chk_shipment(NEW.OrderID, NEW.ShipmentStatus, NEW.EstimatedDate, NEW.ActualDate, TRUE);
END$$

CREATE TRIGGER trg_shipment_bu BEFORE UPDATE ON SHIPMENT
FOR EACH ROW
BEGIN
    IF NEW.OrderID <> OLD.OrderID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không được chuyển thông tin vận chuyển sang đơn hàng khác.';
    END IF;
    CALL chk_shipment(NEW.OrderID, NEW.ShipmentStatus, NEW.EstimatedDate, NEW.ActualDate, FALSE);
END$$

-- ---------------------------------------------------------------------
-- RB6 (tiếp). Không giảm MaxUsage xuống dưới số lượt voucher đã được dùng
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_voucher_bu BEFORE UPDATE ON VOUCHER
FOR EACH ROW
BEGIN
    DECLARE v_used INT;
    DECLARE v_msg  VARCHAR(128);
    IF NEW.MaxUsage < OLD.MaxUsage THEN
        SELECT COUNT(*) INTO v_used FROM `ORDER`
         WHERE VoucherID = OLD.VoucherID AND OrderStatus <> 'CANCELLED';
        IF NEW.MaxUsage < v_used THEN
            SET v_msg = CONCAT('Voucher ', OLD.Code, ' đã được dùng ', v_used,
                               ' lần, không thể giảm MaxUsage xuống ', NEW.MaxUsage, '.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB11. Đánh giá chỉ cho chi tiết thuộc đơn COMPLETED, sau thời điểm đặt
--  (Người đánh giá là chủ đơn: FK ghép fk_review_orderowner;
--   mỗi chi tiết 1 đánh giá: PK; Rating 1..5: CHECK)
-- ---------------------------------------------------------------------
CREATE PROCEDURE chk_review(IN p_order_id INT, IN p_review_time DATETIME)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_date   DATETIME;
    DECLARE v_msg    VARCHAR(128);

    SELECT OrderStatus, OrderDate INTO v_status, v_date FROM `ORDER` WHERE OrderID = p_order_id;

    IF v_status <> 'COMPLETED' THEN
        SET v_msg = CONCAT('Đơn hàng ', p_order_id, ' đang ', v_status, '; chỉ được đánh giá khi đơn đã hoàn thành.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF p_review_time < v_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thời gian đánh giá không được sớm hơn thời gian đặt hàng.';
    END IF;
END$$

CREATE TRIGGER trg_review_bi BEFORE INSERT ON REVIEW
FOR EACH ROW
BEGIN
    CALL chk_review(NEW.OrderID, NEW.ReviewTime);
END$$

CREATE TRIGGER trg_review_bu BEFORE UPDATE ON REVIEW
FOR EACH ROW
BEGIN
    IF NEW.OrderID <> OLD.OrderID OR NEW.ItemID <> OLD.ItemID OR NEW.BuyerID <> OLD.BuyerID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không được đổi chi tiết đơn hàng hoặc người viết của một đánh giá.';
    END IF;
    IF NEW.ReviewTime <> OLD.ReviewTime THEN
        CALL chk_review(NEW.OrderID, NEW.ReviewTime);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- RB12. Khiếu nại
--  - Thời gian gửi không sớm hơn thời gian đặt hàng
--  - Khiếu nại đã đóng (RESOLVED/REJECTED) không được sửa
--  (Người gửi là chủ đơn: FK ghép; điều kiện kết quả/thời gian hoàn tất: CHECK)
-- ---------------------------------------------------------------------
CREATE PROCEDURE chk_complaint_time(IN p_order_id INT, IN p_submit DATETIME)
BEGIN
    IF p_submit < (SELECT OrderDate FROM `ORDER` WHERE OrderID = p_order_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Thời gian gửi khiếu nại không được sớm hơn thời gian đặt hàng.';
    END IF;
END$$

CREATE TRIGGER trg_complaint_bi BEFORE INSERT ON COMPLAINT
FOR EACH ROW
BEGIN
    CALL chk_complaint_time(NEW.OrderID, NEW.SubmitTime);
END$$

CREATE TRIGGER trg_complaint_bu BEFORE UPDATE ON COMPLAINT
FOR EACH ROW
BEGIN
    IF OLD.Status IN ('RESOLVED','REJECTED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Khiếu nại đã đóng (RESOLVED/REJECTED), không được chỉnh sửa.';
    END IF;
    IF NEW.BuyerID <> OLD.BuyerID OR NEW.OrderID <> OLD.OrderID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Không được đổi người gửi hoặc đơn hàng của khiếu nại.';
    END IF;
    IF NEW.SubmitTime <> OLD.SubmitTime THEN
        CALL chk_complaint_time(NEW.OrderID, NEW.SubmitTime);
    END IF;
END$$

DELIMITER ;

-- =====================================================================
-- KẾT THÚC PHẦN 1.1
-- =====================================================================

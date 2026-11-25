-- Active: 1795604678545@@127.0.0.1@3306@shopee_db
-- BTL2 - TV4 - Câu 2.3
-- Các thủ tục chỉ SELECT dữ liệu phục vụ màn hình danh sách/báo cáo.
USE shopee_db;

DROP PROCEDURE IF EXISTS sp_tv4_tim_kiem_san_pham;
DROP PROCEDURE IF EXISTS sp_tv4_thong_ke_ton_kho;

DELIMITER $$

-- Query 1: danh sách sản phẩm theo bộ lọc, liên kết PRODUCT/SHOP/CATEGORY.
CREATE PROCEDURE sp_tv4_tim_kiem_san_pham(
    IN p_keyword        VARCHAR(200),
    IN p_shop_id        INT,
    IN p_category_id    INT,
    IN p_product_status VARCHAR(20)
)
BEGIN
    SELECT p.ProductID,
           p.ShopID,
           s.ShopName,
           s.ShopStatus,
           p.CategoryID,
           c.CategoryName,
           p.ProductName,
           p.Description,
           p.PostedDate,
           p.ProductStatus,
           IFNULL(v.VariantCount, 0) AS VariantCount,
           v.MinPrice,
           v.MaxPrice,
           IFNULL(v.TotalStock, 0) AS TotalStock
      FROM PRODUCT p
      JOIN SHOP s ON s.ShopID = p.ShopID
      JOIN CATEGORY c ON c.CategoryID = p.CategoryID
      LEFT JOIN (
            SELECT ProductID,
                   COUNT(*) AS VariantCount,
                   MIN(Price) AS MinPrice,
                   MAX(Price) AS MaxPrice,
                   SUM(StockQuantity) AS TotalStock
              FROM PRODUCT_VARIANT
             GROUP BY ProductID
      ) v ON v.ProductID = p.ProductID
     WHERE (p_keyword IS NULL OR TRIM(p_keyword) = ''
            OR p.ProductName LIKE CONCAT('%', TRIM(p_keyword), '%')
            OR IFNULL(p.Description, '') LIKE CONCAT('%', TRIM(p_keyword), '%'))
       AND (p_shop_id IS NULL OR p.ShopID = p_shop_id)
       AND (p_category_id IS NULL OR p.CategoryID = p_category_id)
       AND (p_product_status IS NULL OR p.ProductStatus = p_product_status)
     ORDER BY p.PostedDate DESC, p.ProductID DESC;
END$$

-- Query 2: thống kê số sản phẩm, phân loại, tồn kho và giá theo cửa hàng/danh mục.
CREATE PROCEDURE sp_tv4_thong_ke_ton_kho(
    IN p_shop_id            INT,
    IN p_product_status     VARCHAR(20),
    IN p_min_product_count  INT,
    IN p_min_total_stock    INT
)
BEGIN
    SELECT s.ShopID,
           s.ShopName,
           c.CategoryID,
           c.CategoryName,
           COUNT(DISTINCT p.ProductID) AS ProductCount,
           COUNT(v.VariantID) AS VariantCount,
           IFNULL(SUM(v.StockQuantity), 0) AS TotalStock,
           AVG(v.Price) AS AverageVariantPrice
      FROM SHOP s
      JOIN PRODUCT p ON p.ShopID = s.ShopID
      JOIN CATEGORY c ON c.CategoryID = p.CategoryID
      LEFT JOIN PRODUCT_VARIANT v ON v.ProductID = p.ProductID
     WHERE (p_shop_id IS NULL OR s.ShopID = p_shop_id)
       AND (p_product_status IS NULL OR p.ProductStatus = p_product_status)
     GROUP BY s.ShopID, s.ShopName, c.CategoryID, c.CategoryName
    HAVING COUNT(DISTINCT p.ProductID) >= IFNULL(p_min_product_count, 0)
       AND IFNULL(SUM(v.StockQuantity), 0) >= IFNULL(p_min_total_stock, 0)
     ORDER BY s.ShopName, c.CategoryName;
END$$

DELIMITER ;

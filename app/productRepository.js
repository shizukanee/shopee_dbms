import pool from './db.js';

/**
 * Lớp truy cập dữ liệu sản phẩm (dùng cho cả 3 kênh).
 *
 * - Thêm / sửa / xóa: BẮT BUỘC gọi 3 thủ tục của câu 2.1
 *   (sp_product_them, sp_product_sua, sp_product_xoa) để mọi kiểm tra
 *   nghiệp vụ nằm ở CSDL, ứng dụng chỉ hiển thị lỗi.
 * - Các câu SELECT dưới đây chỉ phục vụ hiển thị (danh sách sản phẩm,
 *   combobox cửa hàng / danh mục). Màn hình danh sách ở câu 3.2 sẽ gọi
 *   thủ tục của câu 2.3.
 */

/** Cửa hàng cho combobox (kèm trạng thái để disable cửa hàng không hợp lệ). */
export async function listShops() {
  const [rows] = await pool.query(`
    SELECT ShopID, ShopName, ShopStatus
      FROM SHOP
     ORDER BY (ShopStatus IN ('ACTIVE', 'WARNED')) DESC, ShopName`);
  return rows;
}

/**
 * Danh mục cho combobox: chỉ lấy danh mục LÁ (không còn danh mục con) và
 * dựng sẵn đường dẫn "Cha › Con" để người dùng chọn đúng.
 */
export async function listLeafCategories() {
  const [rows] = await pool.query(`
    SELECT c.CategoryID, c.CategoryName, c.ParentCategoryID,
           (SELECT COUNT(*) FROM CATEGORY ch
             WHERE ch.ParentCategoryID = c.CategoryID) AS ChildCount
      FROM CATEGORY c`);

  const byId = new Map(rows.map((r) => [r.CategoryID, r]));
  for (const row of rows) {
    const parts = [];
    let current = row;
    let guard = 0;
    while (current && guard < 20) {
      parts.unshift(current.CategoryName);
      current = byId.get(current.ParentCategoryID);
      guard += 1;
    }
    row.Path = parts.join(' › ');
  }

  return rows
    .filter((r) => Number(r.ChildCount) === 0)
    .sort((a, b) => a.Path.localeCompare(b.Path, 'vi'));
}

/**
 * Danh sách sản phẩm kèm thống kê phân loại / giá / tồn kho.
 * Truyền shopId để chỉ lấy sản phẩm của một cửa hàng (kênh người bán),
 * productId để lấy đúng một sản phẩm.
 */
export async function listProducts({ shopId = null, productId = null } = {}) {
  const [rows] = await pool.query(`
    SELECT p.ProductID, p.ShopID, p.CategoryID, p.ProductName, p.Description,
           p.PostedDate, p.ProductStatus,
           s.ShopName, s.ShopStatus,
           c.CategoryName,
           IFNULL(v.VariantCount, 0) AS VariantCount,
           v.MinPrice, v.MaxPrice,
           IFNULL(v.TotalStock, 0)  AS TotalStock
      FROM PRODUCT p
      JOIN SHOP s     ON s.ShopID = p.ShopID
      JOIN CATEGORY c ON c.CategoryID = p.CategoryID
      LEFT JOIN (
            SELECT ProductID,
                   COUNT(*)          AS VariantCount,
                   MIN(Price)        AS MinPrice,
                   MAX(Price)        AS MaxPrice,
                   SUM(StockQuantity) AS TotalStock
              FROM PRODUCT_VARIANT
             GROUP BY ProductID
      ) v ON v.ProductID = p.ProductID
     WHERE (? IS NULL OR p.ShopID = ?)
       AND (? IS NULL OR p.ProductID = ?)
     ORDER BY p.ProductID DESC`,
    [shopId, shopId, productId, productId]);
  return rows;
}

export async function findProduct(productId) {
  const rows = await listProducts({ productId });
  return rows[0] || null;
}

/**
 * Gọi sp_product_them. Dùng một connection riêng vì biến @new_product_id
 * là biến phiên (session variable) của MySQL.
 */
export async function insertProduct(value) {
  const conn = await pool.getConnection();
  try {
    await conn.query(
      'CALL sp_product_them(?, ?, ?, ?, ?, @new_product_id)',
      [
        value.ShopID,
        value.CategoryID,
        value.ProductName,
        value.Description || null,
        value.ProductStatus
      ]
    );
    const [rows] = await conn.query('SELECT @new_product_id AS ProductID');
    return rows[0].ProductID;
  } finally {
    conn.release();
  }
}

export async function updateProduct(productId, value) {
  const conn = await pool.getConnection();
  try {
    await conn.query(
      'CALL sp_product_sua(?, ?, ?, ?, ?, ?)',
      [
        productId,
        value.ShopID,
        value.CategoryID,
        value.ProductName,
        value.Description || null,
        value.ProductStatus
      ]
    );
  } finally {
    conn.release();
  }
}

// ---------------------------------------------------------------------
// TV4 — câu 2.3: hai thủ tục truy vấn (chỉ SELECT)
// CALL trả về [resultSet, okPacket] nên lấy phần tử đầu tiên.
// ---------------------------------------------------------------------
export async function searchProducts({ keyword, shopId, categoryId, status }) {
  const [results] = await pool.query(
    'CALL sp_tv4_tim_kiem_san_pham(?, ?, ?, ?)',
    [keyword || null, shopId || null, categoryId || null, status || null]
  );
  return results[0];
}

export async function inventoryStats({ shopId, status, minProducts, minStock }) {
  const [results] = await pool.query(
    'CALL sp_tv4_thong_ke_ton_kho(?, ?, ?, ?)',
    [shopId || null, status || null, minProducts ?? null, minStock ?? null]
  );
  return results[0];
}

export async function deleteProduct(productId) {
  const conn = await pool.getConnection();
  try {
    await conn.query('CALL sp_product_xoa(?)', [productId]);
  } finally {
    conn.release();
  }
}

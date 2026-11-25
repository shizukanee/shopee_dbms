import pool from './db.js';

/**
 * Tài khoản dùng chung schema của TV1:
 *   USER (Email, Phone, PasswordHash, AccountStatus)
 *   └─ vai trò = có dòng trong BUYER / SELLER / ADMIN (một người có thể nhiều vai trò)
 */

/** Đăng nhập bằng email hoặc số điện thoại. */
export async function findUserByLogin(login) {
  const [rows] = await pool.query(
    `SELECT UserID, Email, Phone, LastName, MiddleName, FirstName,
            PasswordHash, AccountStatus
       FROM \`USER\`
      WHERE Email = ? OR Phone = ?
      LIMIT 1`,
    [login, login]
  );
  return rows[0] || null;
}

/** Trả về danh sách vai trò theo thứ tự ưu tiên: admin, seller, buyer. */
export async function getRoles(userId) {
  const [rows] = await pool.query(
    `SELECT EXISTS(SELECT 1 FROM \`ADMIN\` WHERE UserID = ?) AS isAdmin,
            EXISTS(SELECT 1 FROM SELLER    WHERE UserID = ?) AS isSeller,
            EXISTS(SELECT 1 FROM BUYER     WHERE UserID = ?) AS isBuyer`,
    [userId, userId, userId]
  );
  const r = rows[0];
  const roles = [];
  if (Number(r.isAdmin)) roles.push('admin');
  if (Number(r.isSeller)) roles.push('seller');
  if (Number(r.isBuyer)) roles.push('buyer');
  return roles;
}

/**
 * Đăng ký: thêm USER + BUYER hoặc SELLER trong cùng một transaction.
 * Quản trị viên không tự đăng ký được (tạo bằng script seed).
 */
export async function createAccount(v, passwordHash) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [result] = await conn.query(
      `INSERT INTO \`USER\` (Email, Phone, LastName, MiddleName, FirstName, PasswordHash)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [v.Email, v.Phone, v.LastName, v.MiddleName || null, v.FirstName, passwordHash]
    );
    const userId = result.insertId;

    if (v.role === 'seller') {
      await conn.query(
        `INSERT INTO SELLER (UserID, TaxCode, VerificationStatus) VALUES (?, ?, 'PENDING')`,
        [userId, v.TaxCode || null]
      );
    } else {
      await conn.query('INSERT INTO BUYER (UserID) VALUES (?)', [userId]);
    }

    await conn.commit();
    return userId;
  } catch (error) {
    await conn.rollback();
    throw error;
  } finally {
    conn.release();
  }
}

/** Đổi lỗi trùng khóa UNIQUE thành thông báo cho từng ô. */
export function duplicateFieldError(error) {
  if (error?.code !== 'ER_DUP_ENTRY') return null;
  const msg = String(error.sqlMessage || '');
  if (msg.includes('uq_user_email')) return { Email: 'Email này đã được đăng ký.' };
  if (msg.includes('uq_user_phone')) return { Phone: 'Số điện thoại này đã được đăng ký.' };
  if (msg.includes('uq_seller_taxcode')) return { TaxCode: 'Mã số thuế đã được người bán khác sử dụng.' };
  return null;
}

// ---------------------------------------------------------------------
// Người bán & cửa hàng
// ---------------------------------------------------------------------
export async function getSellerContext(userId) {
  const [[seller]] = await pool.query(
    'SELECT UserID, TaxCode, VerifiedDate, VerificationStatus FROM SELLER WHERE UserID = ?',
    [userId]
  );
  const [[shop]] = await pool.query(
    `SELECT ShopID, ShopName, Description, Address, EstablishedDate, ShopStatus
       FROM SHOP WHERE SellerID = ?`,
    [userId]
  );
  return { seller: seller || null, shop: shop || null };
}

/** INSERT SHOP — trigger trg_shop_bi (TV1) chặn nếu người bán chưa VERIFIED. */
export async function createShop(sellerId, v) {
  const [result] = await pool.query(
    'INSERT INTO SHOP (SellerID, ShopName, Description, Address) VALUES (?, ?, ?, ?)',
    [sellerId, v.ShopName, v.Description || null, v.Address]
  );
  return result.insertId;
}

// ---------------------------------------------------------------------
// Quản trị: duyệt người bán
// ---------------------------------------------------------------------
export async function listSellers() {
  const [rows] = await pool.query(
    `SELECT u.UserID, u.Email, u.Phone, u.LastName, u.MiddleName, u.FirstName,
            u.RegisterDate, u.AccountStatus,
            s.TaxCode, s.VerifiedDate, s.VerificationStatus,
            sh.ShopID, sh.ShopName, sh.ShopStatus
       FROM SELLER s
       JOIN \`USER\` u ON u.UserID = s.UserID
       LEFT JOIN SHOP sh ON sh.SellerID = s.UserID
      ORDER BY FIELD(s.VerificationStatus, 'PENDING', 'REJECTED', 'VERIFIED'), u.RegisterDate DESC`
  );
  return rows;
}

export async function setSellerVerification(userId, status) {
  const [result] = await pool.query(
    `UPDATE SELLER
        SET VerificationStatus = ?,
            VerifiedDate = IF(? = 'VERIFIED', CURRENT_DATE, NULL)
      WHERE UserID = ? AND VerificationStatus <> 'VERIFIED'`,
    [status, status, userId]
  );
  return result.affectedRows;
}

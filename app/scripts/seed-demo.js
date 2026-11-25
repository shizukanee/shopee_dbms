/**
 * Đặt mật khẩu demo cho vài tài khoản có sẵn trong TV2_napdulieu.sql.
 * (PasswordHash trong dữ liệu mẫu là chuỗi giả, không đăng nhập được.)
 *
 *   npm run seed-demo
 *
 * Chỉ cập nhật cột PasswordHash của các UserID bên dưới. Chạy lại bao nhiêu lần cũng được.
 */
import bcrypt from 'bcryptjs';
import pool from '../db.js';

const DEMO_PASSWORD = '123456';
const DEMO_USERS = [
  [1, 'Người mua'],
  [7, 'Người mua + Người bán (có cửa hàng) → hiện trang chọn kênh'],
  [8, 'Người bán (có cửa hàng)'],
  [12, 'Người bán đang chờ xác minh (chưa có cửa hàng)'],
  [14, 'Quản trị viên']
];

const hash = await bcrypt.hash(DEMO_PASSWORD, 10);
const ids = DEMO_USERS.map(([id]) => id);
await pool.query('UPDATE `USER` SET PasswordHash = ? WHERE UserID IN (?)', [hash, ids]);

const [rows] = await pool.query(
  'SELECT UserID, Email, Phone FROM `USER` WHERE UserID IN (?) ORDER BY UserID',
  [ids]
);
const note = new Map(DEMO_USERS);
console.log(`Đã đặt mật khẩu “${DEMO_PASSWORD}” cho ${rows.length} tài khoản demo:\n`);
console.table(rows.map((r) => ({ ID: r.UserID, Email: r.Email, 'SĐT': r.Phone, 'Vai trò': note.get(r.UserID) })));
await pool.end();

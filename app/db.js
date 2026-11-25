import 'dotenv/config';
import mysql from 'mysql2/promise';

/**
 * Kết nối CSDL shopee_db.
 * Cấu hình lấy từ biến môi trường (xem .env.example), có giá trị mặc định
 * để chạy được ngay trên máy cài MySQL local.
 */
const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'shopee_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  charset: 'utf8mb4',
  // Trả DATETIME dạng chuỗi 'YYYY-MM-DD HH:MM:SS' để tránh lệch múi giờ
  dateStrings: true
});

export default pool;

import express from 'express';
import session from 'express-session';
import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pool from './db.js';
import { registerViewHelpers, databaseError } from './helpers.js';
import authRouter, { exposeUser, requireRole } from './routes/auth.js';
import buyerRouter from './routes/buyer.js';
import sellerRouter from './routes/seller.js';
import adminRouter from './routes/admin.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = Number(process.env.PORT || 3000);

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.urlencoded({ extended: false }));
app.use(express.static(path.join(__dirname, 'public')));
registerViewHelpers(app);

// Phiên đăng nhập (lưu trong bộ nhớ — đủ cho demo; khởi động lại server sẽ phải đăng nhập lại).
app.use(
  session({
    name: 'sid',
    secret: process.env.SESSION_SECRET || crypto.randomBytes(32).toString('hex'),
    resave: false,
    saveUninitialized: false,
    cookie: { httpOnly: true, sameSite: 'lax', maxAge: 8 * 60 * 60 * 1000 }
  })
);
app.use(exposeUser);

// ---------------------------------------------------------------------
// 3 kênh: /buyer, /seller, /admin — mỗi kênh chỉ mở cho đúng vai trò
// ---------------------------------------------------------------------
app.use('/', authRouter);
app.use('/buyer', requireRole('buyer'), buyerRouter);
app.use('/seller', requireRole('seller'), sellerRouter);
app.use('/admin', requireRole('admin'), adminRouter);

app.use((req, res) => {
  res.status(404).render('error', {
    title: 'Không tìm thấy trang',
    message: `Đường dẫn ${req.originalUrl} không tồn tại.`
  });
});

app.use((error, req, res, next) => {
  console.error(error);
  res.status(500).render('error', {
    title: 'Lỗi hệ thống',
    message: databaseError(error)
  });
});

async function start() {
  try {
    await pool.query('SELECT 1');
    console.log(
      `Đã kết nối MySQL: ${process.env.DB_USER || 'root'}@` +
        `${process.env.DB_HOST || '127.0.0.1'}:${process.env.DB_PORT || 3306}/` +
        `${process.env.DB_NAME || 'shopee_db'}`
    );
  } catch (error) {
    console.error('Không kết nối được CSDL:', databaseError(error));
    console.error('Kiểm tra file .env (xem .env.example) và bảo đảm MySQL đang chạy.');
    process.exit(1);
  }

  app.listen(PORT, () => {
    console.log(`Ứng dụng đang chạy tại http://localhost:${PORT}`);
    console.log(`  Đăng nhập : http://localhost:${PORT}/login`);
    console.log(`  Đăng ký   : http://localhost:${PORT}/register`);
    console.log(`  Kênh      : /buyer (người mua) · /seller (người bán) · /admin (quản trị)`);
  });
}

start();

import { Router } from 'express';
import bcrypt from 'bcryptjs';
import {
  findUserByLogin,
  getRoles,
  createAccount,
  duplicateFieldError
} from '../accountRepository.js';
import {
  ROLE_LABEL,
  fullName,
  queryMessage,
  readRegisterForm,
  validateRegister,
  databaseError
} from '../helpers.js';

/** Đường dẫn trang chủ của từng kênh. */
export const CHANNEL_HOME = {
  buyer: '/buyer',
  seller: '/seller',
  admin: '/admin'
};

/** Menu của từng kênh (hiển thị trên thanh trên cùng). */
const CHANNEL_NAV = {
  buyer: [{ href: '/buyer', label: 'Tìm sản phẩm' }],
  seller: [
    { href: '/seller', label: 'Sản phẩm của tôi' },
    { href: '/seller/tim-kiem', label: 'Tìm kiếm' },
    { href: '/seller/thong-ke', label: 'Thống kê tồn kho' },
    { href: '/seller/cua-hang', label: 'Cửa hàng' }
  ],
  admin: [
    { href: '/admin', label: 'Kiểm duyệt sản phẩm' },
    { href: '/admin/thong-ke', label: 'Thống kê tồn kho' },
    { href: '/admin/nguoi-ban', label: 'Duyệt người bán' }
  ]
};

/** Đưa thông tin đăng nhập vào mọi view. */
export function exposeUser(req, res, next) {
  res.locals.user = req.session.user || null;
  res.locals.channel = null;
  res.locals.nav = [];
  res.locals.currentPath = req.path;
  // URL hiện tại, bỏ ?ok= / ?err= để dùng làm đường quay lại sau khi thao tác.
  const url = new URL(req.originalUrl, 'http://local');
  url.searchParams.delete('ok');
  url.searchParams.delete('err');
  res.locals.currentUrl = url.pathname + url.search;
  next();
}

/** Chặn truy cập nếu chưa đăng nhập hoặc không có vai trò tương ứng. */
export function requireRole(role) {
  return (req, res, next) => {
    const user = req.session.user;
    if (!user) {
      return res.redirect(`/login?next=${encodeURIComponent(req.originalUrl)}`);
    }
    if (!user.roles.includes(role)) {
      return res.status(403).render('error', {
        title: 'Không có quyền truy cập',
        message: `Tài khoản của bạn không có vai trò “${ROLE_LABEL[role]}”.`
      });
    }
    res.locals.channel = role;
    res.locals.nav = CHANNEL_NAV[role];
    next();
  };
}

/** Chỉ cho phép quay về đường dẫn nội bộ thuộc kênh mà người dùng có quyền. */
function safeNext(next, roles) {
  if (typeof next !== 'string' || !next.startsWith('/') || next.startsWith('//')) return null;
  const role = Object.keys(CHANNEL_HOME).find((r) => next.startsWith(CHANNEL_HOME[r]));
  return role && roles.includes(role) ? next : null;
}

function afterLogin(user) {
  return user.roles.length === 1 ? CHANNEL_HOME[user.roles[0]] : '/chon-kenh';
}

const router = Router();

router.get('/', (req, res) => {
  if (!req.session.user) return res.redirect('/login');
  return res.redirect(afterLogin(req.session.user));
});

// ------------------------------- Đăng nhập -------------------------------
router.get('/login', (req, res) => {
  if (req.session.user) return res.redirect(afterLogin(req.session.user));
  res.render('auth/login', {
    login: String(req.query.login ?? ''),
    next: String(req.query.next ?? ''),
    error: null,
    success: queryMessage(req.query.ok)
  });
});

router.post('/login', async (req, res, nextMiddleware) => {
  const login = String(req.body.login ?? '').trim();
  const password = String(req.body.password ?? '');
  const next = String(req.body.next ?? '');
  const fail = (message, status = 401) =>
    res.status(status).render('auth/login', { login, next, error: message, success: null });

  if (!login || !password) return fail('Vui lòng nhập email/số điện thoại và mật khẩu.', 400);

  const row = await findUserByLogin(login.toLowerCase().includes('@') ? login.toLowerCase() : login);
  const ok = row && (await bcrypt.compare(password, row.PasswordHash).catch(() => false));
  if (!ok) return fail('Email/số điện thoại hoặc mật khẩu không đúng.');
  if (row.AccountStatus === 'LOCKED') return fail('Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.', 403);

  const roles = await getRoles(row.UserID);
  if (roles.length === 0) return fail('Tài khoản chưa được gán vai trò nào.', 403);

  const user = {
    id: row.UserID,
    name: fullName(row),
    email: row.Email,
    status: row.AccountStatus,
    roles
  };

  // Tạo session mới sau khi đăng nhập (chống session fixation).
  req.session.regenerate((err) => {
    if (err) return nextMiddleware(err);
    req.session.user = user;
    req.session.save(() => res.redirect(safeNext(next, roles) || afterLogin(user)));
  });
});

router.post('/logout', (req, res) => {
  req.session.destroy(() => {
    res.clearCookie('sid');
    res.redirect('/login?ok=' + encodeURIComponent('Đã đăng xuất.'));
  });
});

// ------------------------------- Chọn kênh -------------------------------
router.get('/chon-kenh', (req, res) => {
  const user = req.session.user;
  if (!user) return res.redirect('/login');
  if (user.roles.length === 1) return res.redirect(CHANNEL_HOME[user.roles[0]]);
  res.render('auth/choose', { channelHome: CHANNEL_HOME });
});

// -------------------------------- Đăng ký --------------------------------
function emptyRegister() {
  return readRegisterForm({ role: 'buyer' });
}

router.get('/register', (req, res) => {
  if (req.session.user) return res.redirect(afterLogin(req.session.user));
  res.render('auth/register', { form: emptyRegister(), fieldErrors: {}, error: null });
});

router.post('/register', async (req, res) => {
  const form = readRegisterForm(req.body);
  const fieldErrors = validateRegister(form);
  const fail = (errors, message) =>
    res.status(400).render('auth/register', {
      form: { ...form, Password: '', ConfirmPassword: '' },
      fieldErrors: errors,
      error: message
    });

  if (Object.keys(fieldErrors).length > 0) {
    return fail(fieldErrors, 'Vui lòng sửa các ô được đánh dấu đỏ.');
  }

  try {
    const hash = await bcrypt.hash(form.Password, 10);
    await createAccount(form, hash);
  } catch (error) {
    const dup = duplicateFieldError(error);
    if (dup) return fail(dup, 'Thông tin đã tồn tại trong hệ thống.');
    return fail({}, databaseError(error));
  }

  const note =
    form.role === 'seller'
      ? 'Đăng ký người bán thành công. Tài khoản đang chờ quản trị viên xác minh trước khi mở cửa hàng.'
      : 'Đăng ký thành công. Hãy đăng nhập để bắt đầu mua sắm.';
  res.redirect(`/login?login=${encodeURIComponent(form.Email)}&ok=${encodeURIComponent(note)}`);
});

export default router;

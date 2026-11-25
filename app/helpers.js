/**
 * Hằng số, định dạng hiển thị và validate dùng chung cho cả 3 kênh.
 */

export const PRODUCT_STATUSES = ['ACTIVE', 'HIDDEN', 'INACTIVE', 'BANNED'];
/** Người bán không được tự đặt BANNED — đó là quyết định của quản trị. */
export const SELLER_STATUSES = ['ACTIVE', 'HIDDEN', 'INACTIVE'];

export const PRODUCT_STATUS_LABEL = {
  ACTIVE: 'Đang bán',
  HIDDEN: 'Tạm ẩn',
  INACTIVE: 'Ngừng bán',
  BANNED: 'Bị gỡ'
};
export const SHOP_STATUS_LABEL = {
  ACTIVE: 'Đang hoạt động',
  WARNED: 'Bị cảnh báo',
  RESTRICTED: 'Bị hạn chế',
  SUSPENDED: 'Tạm khóa',
  CLOSED: 'Đã đóng'
};
export const ROLE_LABEL = {
  buyer: 'Người mua',
  seller: 'Người bán',
  admin: 'Quản trị'
};
export const VERIFICATION_LABEL = {
  PENDING: 'Chờ xác minh',
  VERIFIED: 'Đã xác minh',
  REJECTED: 'Bị từ chối'
};

const vndFormatter = new Intl.NumberFormat('vi-VN', {
  style: 'currency',
  currency: 'VND',
  maximumFractionDigits: 0
});
const numberFormatter = new Intl.NumberFormat('vi-VN');

export function formatVnd(value) {
  if (value === null || value === undefined || value === '') return '—';
  return vndFormatter.format(Number(value));
}

export function formatNumber(value) {
  if (value === null || value === undefined || value === '') return '0';
  return numberFormatter.format(Number(value));
}

export function formatDateTime(value) {
  if (!value) return '—';
  const text = value instanceof Date ? value.toISOString() : String(value);
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?/);
  if (!match) return text;
  const date = `${match[3]}/${match[2]}/${match[1]}`;
  return match[4] ? `${date} ${match[4]}:${match[5]}` : date;
}

export function priceRange(product) {
  if (product.MinPrice === null || product.MinPrice === undefined) {
    return 'Chưa có phân loại';
  }
  const min = Number(product.MinPrice);
  const max = Number(product.MaxPrice);
  if (min === max) return formatVnd(min);
  return `${formatVnd(min)} – ${formatVnd(max)}`;
}

export function truncate(text, maxLength) {
  if (!text) return '';
  return text.length > maxLength ? `${text.slice(0, maxLength)}…` : text;
}

export function fullName(user) {
  return [user.LastName, user.MiddleName, user.FirstName].filter(Boolean).join(' ');
}

/** Gắn các hàm/hằng số trên vào app.locals để mọi view dùng được. */
export function registerViewHelpers(app) {
  Object.assign(app.locals, {
    formatVnd,
    formatNumber,
    formatDateTime,
    priceRange,
    truncate,
    productStatusLabel: PRODUCT_STATUS_LABEL,
    shopStatusLabel: SHOP_STATUS_LABEL,
    roleLabel: ROLE_LABEL,
    verificationLabel: VERIFICATION_LABEL,
    PRODUCT_STATUSES
  });
}

// ---------------------------------------------------------------------
// Đọc tham số
// ---------------------------------------------------------------------
export function databaseError(error) {
  const message = error?.sqlMessage || error?.message || 'Lỗi CSDL không xác định.';
  return String(message).slice(0, 300);
}

export function queryMessage(value) {
  if (!value) return null;
  return String(value).slice(0, 300);
}

export function parseId(value) {
  const id = Number(value);
  return Number.isInteger(id) && id > 0 ? id : null;
}

/** '' → null, số nguyên → số, còn lại → NaN (để báo lỗi bộ lọc). */
export function optionalInt(value) {
  if (value === undefined || value === null || String(value).trim() === '') return null;
  const n = Number(value);
  return Number.isInteger(n) ? n : NaN;
}

/** '' → null, trạng thái hợp lệ → trạng thái, còn lại → undefined. */
export function optionalStatus(value) {
  const s = String(value ?? '').trim().toUpperCase();
  if (!s) return null;
  return PRODUCT_STATUSES.includes(s) ? s : undefined;
}

export function withMessage(path, key, message) {
  const sep = path.includes('?') ? '&' : '?';
  return `${path}${sep}${key}=${encodeURIComponent(message)}`;
}

// ---------------------------------------------------------------------
// Sản phẩm
// ---------------------------------------------------------------------
export function readProductForm(body = {}) {
  return {
    CategoryID: Number.parseInt(body.CategoryID, 10),
    ProductName: String(body.ProductName ?? '').trim(),
    Description: String(body.Description ?? '').trim(),
    ProductStatus: String(body.ProductStatus ?? 'ACTIVE').trim().toUpperCase()
  };
}

/** Validate phía server (lớp thứ hai). Quy tắc sâu hơn do thủ tục CSDL quyết định. */
export function validateProduct(values) {
  const errors = {};

  if (!Number.isInteger(values.CategoryID) || values.CategoryID <= 0) {
    errors.CategoryID = 'Vui lòng chọn danh mục lá.';
  }
  if (!values.ProductName) {
    errors.ProductName = 'Tên sản phẩm không được để trống.';
  } else if (values.ProductName.length > 200) {
    errors.ProductName = `Tên sản phẩm tối đa 200 ký tự (hiện tại ${values.ProductName.length}).`;
  }
  if (values.Description.length > 5000) {
    errors.Description = `Mô tả tối đa 5.000 ký tự (hiện tại ${values.Description.length}).`;
  }
  if (!SELLER_STATUSES.includes(values.ProductStatus)) {
    errors.ProductStatus = 'Trạng thái không hợp lệ (người bán chỉ chọn ACTIVE / HIDDEN / INACTIVE).';
  }
  return errors;
}

// ---------------------------------------------------------------------
// Tài khoản
// ---------------------------------------------------------------------
const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
const PHONE_RE = /^0[0-9]{9}$/;
const TAX_RE = /^[0-9]{10}(-?[0-9]{3})?$/;

export function readRegisterForm(body = {}) {
  const role = String(body.role ?? '').trim();
  return {
    role: role === 'seller' ? 'seller' : role === 'buyer' ? 'buyer' : '',
    Email: String(body.Email ?? '').trim().toLowerCase(),
    Phone: String(body.Phone ?? '').trim(),
    LastName: String(body.LastName ?? '').trim(),
    MiddleName: String(body.MiddleName ?? '').trim(),
    FirstName: String(body.FirstName ?? '').trim(),
    TaxCode: String(body.TaxCode ?? '').trim(),
    Password: String(body.Password ?? ''),
    ConfirmPassword: String(body.ConfirmPassword ?? '')
  };
}

/** Kiểm tra giống các CHECK của bảng USER / SELLER để báo lỗi sớm, rõ ràng. */
export function validateRegister(v) {
  const errors = {};
  if (!v.role) errors.role = 'Vui lòng chọn vai trò.';
  if (!EMAIL_RE.test(v.Email) || v.Email.length > 100) errors.Email = 'Email không hợp lệ.';
  if (!PHONE_RE.test(v.Phone)) errors.Phone = 'Số điện thoại gồm 10 chữ số, bắt đầu bằng 0.';
  if (!v.LastName) errors.LastName = 'Vui lòng nhập họ.';
  else if (v.LastName.length > 50) errors.LastName = 'Tối đa 50 ký tự.';
  if (v.MiddleName.length > 50) errors.MiddleName = 'Tối đa 50 ký tự.';
  if (!v.FirstName) errors.FirstName = 'Vui lòng nhập tên.';
  else if (v.FirstName.length > 50) errors.FirstName = 'Tối đa 50 ký tự.';
  if (v.role === 'seller' && v.TaxCode && !TAX_RE.test(v.TaxCode)) {
    errors.TaxCode = 'Mã số thuế gồm 10 chữ số (có thể thêm -XXX).';
  }
  if (v.Password.length < 6) errors.Password = 'Mật khẩu tối thiểu 6 ký tự.';
  else if (v.Password.length > 72) errors.Password = 'Mật khẩu tối đa 72 ký tự.';
  if (v.ConfirmPassword !== v.Password) errors.ConfirmPassword = 'Mật khẩu nhập lại không khớp.';
  return errors;
}

import { Router } from 'express';
import {
  listLeafCategories,
  listProducts,
  findProduct,
  insertProduct,
  updateProduct,
  deleteProduct
} from '../productRepository.js';
import { getSellerContext, createShop } from '../accountRepository.js';
import {
  SELLER_STATUSES,
  databaseError,
  parseId,
  queryMessage,
  readProductForm,
  validateProduct,
  withMessage
} from '../helpers.js';
import { renderSearch, renderStats } from './reports.js';

/**
 * KÊNH NGƯỜI BÁN
 * - Thêm / sửa / xóa sản phẩm: thủ tục TV3 (câu 2.1). ShopID luôn lấy từ tài
 *   khoản đăng nhập, người bán chỉ thao tác được trên sản phẩm của shop mình.
 * - Tìm kiếm / thống kê: thủ tục TV4 (câu 2.3) với p_shop_id cố định.
 * - Cửa hàng: người bán VERIFIED mới tạo được (trigger trg_shop_bi của TV1).
 */
const router = Router();
const SHOP_USABLE = ['ACTIVE', 'WARNED'];

// Nạp thông tin người bán + cửa hàng cho mọi trang của kênh.
router.use(async (req, res, next) => {
  const { seller, shop } = await getSellerContext(req.session.user.id);
  res.locals.seller = seller;
  res.locals.shop = shop;
  next();
});

// ------------------------------- Cửa hàng -------------------------------
router.get('/cua-hang', (req, res) => {
  res.render('seller/shop', {
    form: { ShopName: '', Address: '', Description: '' },
    fieldErrors: {},
    error: queryMessage(req.query.err),
    success: queryMessage(req.query.ok)
  });
});

router.post('/cua-hang', async (req, res) => {
  const form = {
    ShopName: String(req.body.ShopName ?? '').trim(),
    Address: String(req.body.Address ?? '').trim(),
    Description: String(req.body.Description ?? '').trim()
  };
  const fieldErrors = {};
  if (!form.ShopName) fieldErrors.ShopName = 'Vui lòng nhập tên cửa hàng.';
  else if (form.ShopName.length > 100) fieldErrors.ShopName = 'Tối đa 100 ký tự.';
  if (!form.Address) fieldErrors.Address = 'Vui lòng nhập địa chỉ.';
  else if (form.Address.length > 255) fieldErrors.Address = 'Tối đa 255 ký tự.';

  const fail = (error) =>
    res.status(400).render('seller/shop', { form, fieldErrors, error, success: null });

  if (res.locals.shop) return fail('Mỗi người bán chỉ được sở hữu một cửa hàng.');
  if (Object.keys(fieldErrors).length > 0) return fail('Vui lòng sửa các ô được đánh dấu đỏ.');

  try {
    await createShop(req.session.user.id, form);
  } catch (error) {
    return fail(databaseError(error)); // ví dụ: người bán chưa được xác minh
  }
  res.redirect(withMessage('/seller', 'ok', `Đã mở cửa hàng “${form.ShopName}”.`));
});

// Các trang còn lại cần có cửa hàng.
router.use((req, res, next) => {
  if (!res.locals.shop) return res.redirect('/seller/cua-hang');
  next();
});

// --------------------------- Quản lý sản phẩm ---------------------------
function emptyForm() {
  return { CategoryID: '', ProductName: '', Description: '', ProductStatus: 'ACTIVE' };
}

async function renderManage(req, res, options) {
  const shop = res.locals.shop;
  const [categories, products] = await Promise.all([
    listLeafCategories(),
    listProducts({ shopId: shop.ShopID })
  ]);
  const stats = {
    total: products.length,
    active: products.filter((p) => p.ProductStatus === 'ACTIVE').length,
    lowStock: products.filter((p) => Number(p.VariantCount) > 0 && Number(p.TotalStock) <= 5).length
  };
  const form = options.form || emptyForm();
  const current = form.ProductID
    ? products.find((p) => Number(p.ProductID) === Number(form.ProductID)) || null
    : null;

  res.status(options.status || 200).render('products', {
    mode: options.mode || 'create',
    form,
    current,
    fieldErrors: options.fieldErrors || {},
    error: options.error || null,
    success: options.success || null,
    shopUsable: SHOP_USABLE.includes(shop.ShopStatus),
    statuses: SELLER_STATUSES,
    categories,
    products,
    stats
  });
}

/** Lấy sản phẩm và bảo đảm nó thuộc cửa hàng của người bán đang đăng nhập. */
async function ownProduct(req, res) {
  const productId = parseId(req.params.id);
  if (!productId) {
    res.redirect(withMessage('/seller', 'err', 'Mã sản phẩm không hợp lệ.'));
    return null;
  }
  const product = await findProduct(productId);
  if (!product || Number(product.ShopID) !== Number(res.locals.shop.ShopID)) {
    res.redirect(withMessage('/seller', 'err', `Không tìm thấy sản phẩm #${productId} trong cửa hàng của bạn.`));
    return null;
  }
  return product;
}

router.get('/', (req, res) =>
  renderManage(req, res, {
    success: queryMessage(req.query.ok),
    error: queryMessage(req.query.err)
  })
);

router.get('/products/:id/edit', async (req, res) => {
  const product = await ownProduct(req, res);
  if (!product) return;
  await renderManage(req, res, { mode: 'edit', form: product });
});

router.post('/products', async (req, res) => {
  const values = { ...readProductForm(req.body), ShopID: res.locals.shop.ShopID };
  const fieldErrors = validateProduct(values);
  if (Object.keys(fieldErrors).length > 0) {
    return renderManage(req, res, {
      form: values, fieldErrors, status: 400,
      error: 'Vui lòng sửa các ô được đánh dấu đỏ.'
    });
  }
  try {
    const productId = await insertProduct(values);
    res.redirect(withMessage('/seller', 'ok', `Đã thêm sản phẩm #${productId} — ${values.ProductName}.`));
  } catch (error) {
    await renderManage(req, res, { form: values, error: databaseError(error), status: 400 });
  }
});

router.post('/products/:id', async (req, res) => {
  const product = await ownProduct(req, res);
  if (!product) return;

  const values = {
    ...readProductForm(req.body),
    ShopID: res.locals.shop.ShopID,
    ProductID: product.ProductID
  };
  const fieldErrors = validateProduct(values);
  if (Object.keys(fieldErrors).length > 0) {
    return renderManage(req, res, {
      mode: 'edit', form: values, fieldErrors, status: 400,
      error: 'Vui lòng sửa các ô được đánh dấu đỏ.'
    });
  }
  try {
    await updateProduct(product.ProductID, values);
    res.redirect(withMessage('/seller', 'ok', `Đã cập nhật sản phẩm #${product.ProductID} — ${values.ProductName}.`));
  } catch (error) {
    await renderManage(req, res, { mode: 'edit', form: values, error: databaseError(error), status: 400 });
  }
});

router.post('/products/:id/delete', async (req, res) => {
  const product = await ownProduct(req, res);
  if (!product) return;
  try {
    await deleteProduct(product.ProductID);
    res.redirect(withMessage('/seller', 'ok', `Đã xóa sản phẩm #${product.ProductID}.`));
  } catch (error) {
    res.redirect(withMessage('/seller', 'err', databaseError(error)));
  }
});

// --------------------------- Tìm kiếm / thống kê ---------------------------
router.get('/tim-kiem', (req, res) =>
  renderSearch(req, res, {
    scope: 'seller',
    basePath: '/seller/tim-kiem',
    forcedShopId: res.locals.shop.ShopID,
    title: 'Tìm kiếm sản phẩm của cửa hàng',
    subtitle: 'Gọi thủ tục sp_tv4_tim_kiem_san_pham với cửa hàng của bạn.'
  })
);

router.get('/thong-ke', (req, res) =>
  renderStats(req, res, {
    scope: 'seller',
    basePath: '/seller/thong-ke',
    forcedShopId: res.locals.shop.ShopID,
    title: 'Thống kê tồn kho theo danh mục',
    subtitle: 'Gọi thủ tục sp_tv4_thong_ke_ton_kho với cửa hàng của bạn.'
  })
);

export default router;

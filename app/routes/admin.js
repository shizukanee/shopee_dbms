import { Router } from 'express';
import { findProduct, updateProduct } from '../productRepository.js';
import { listSellers, setSellerVerification } from '../accountRepository.js';
import { databaseError, parseId, queryMessage, withMessage } from '../helpers.js';
import { renderSearch, renderStats } from './reports.js';

/**
 * KÊNH QUẢN TRỊ
 * - Kiểm duyệt sản phẩm: tìm kiếm toàn sàn (TV4 · 2.3) + gỡ sản phẩm vi phạm
 *   (chuyển BANNED qua sp_product_sua của TV3).
 * - Thống kê tồn kho toàn sàn (TV4 · 2.3).
 * - Duyệt người bán: PENDING → VERIFIED / REJECTED (điều kiện để mở SHOP).
 */
const router = Router();

router.get('/', (req, res) =>
  renderSearch(req, res, {
    scope: 'admin',
    basePath: '/admin',
    title: 'Kiểm duyệt sản phẩm',
    subtitle: 'Tìm kiếm toàn sàn bằng sp_tv4_tim_kiem_san_pham; gỡ sản phẩm vi phạm bằng sp_product_sua.'
  })
);

router.post('/products/:id/ban', async (req, res) => {
  const back = typeof req.body.back === 'string' && req.body.back.startsWith('/admin')
    ? req.body.back
    : '/admin';
  const productId = parseId(req.params.id);
  const product = productId ? await findProduct(productId) : null;
  if (!product) return res.redirect(withMessage(back, 'err', 'Sản phẩm không tồn tại.'));

  try {
    // Giữ nguyên mọi thông tin, chỉ đổi trạng thái → BANNED (trạng thái cuối).
    await updateProduct(product.ProductID, {
      ShopID: product.ShopID,
      CategoryID: product.CategoryID,
      ProductName: product.ProductName,
      Description: product.Description,
      ProductStatus: 'BANNED'
    });
    res.redirect(withMessage(back, 'ok', `Đã gỡ sản phẩm #${product.ProductID} — ${product.ProductName}.`));
  } catch (error) {
    res.redirect(withMessage(back, 'err', databaseError(error)));
  }
});

router.get('/thong-ke', (req, res) =>
  renderStats(req, res, {
    scope: 'admin',
    basePath: '/admin/thong-ke',
    title: 'Thống kê tồn kho toàn sàn',
    subtitle: 'Gọi thủ tục sp_tv4_thong_ke_ton_kho theo cửa hàng / danh mục.'
  })
);

// ------------------------------ Duyệt người bán ------------------------------
router.get('/nguoi-ban', async (req, res) => {
  const sellers = await listSellers();
  res.render('admin/sellers', {
    sellers,
    error: queryMessage(req.query.err),
    success: queryMessage(req.query.ok)
  });
});

for (const [action, status, verb] of [
  ['duyet', 'VERIFIED', 'Đã xác minh'],
  ['tu-choi', 'REJECTED', 'Đã từ chối']
]) {
  router.post(`/nguoi-ban/:id/${action}`, async (req, res) => {
    const userId = parseId(req.params.id);
    if (!userId) return res.redirect(withMessage('/admin/nguoi-ban', 'err', 'Mã người bán không hợp lệ.'));
    try {
      const changed = await setSellerVerification(userId, status);
      if (!changed) {
        return res.redirect(withMessage('/admin/nguoi-ban', 'err',
          `Người bán #${userId} không tồn tại hoặc đã được xác minh trước đó.`));
      }
      res.redirect(withMessage('/admin/nguoi-ban', 'ok', `${verb} người bán #${userId}.`));
    } catch (error) {
      res.redirect(withMessage('/admin/nguoi-ban', 'err', databaseError(error)));
    }
  });
}

export default router;

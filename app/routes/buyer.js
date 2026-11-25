import { Router } from 'express';
import { listShops, listLeafCategories, searchProducts } from '../productRepository.js';
import { databaseError, optionalInt } from '../helpers.js';

/**
 * KÊNH NGƯỜI MUA
 * - Tìm sản phẩm: gọi sp_tv4_tim_kiem_san_pham (TV4 · câu 2.3).
 * - Người mua chỉ thấy sản phẩm ACTIVE của cửa hàng đang hoạt động / bị cảnh báo.
 */
const VISIBLE_SHOP = ['ACTIVE', 'WARNED'];
const router = Router();

router.get('/', async (req, res) => {
  const filters = {
    keyword: String(req.query.keyword ?? '').trim().slice(0, 200),
    shopId: optionalInt(req.query.shopId),
    categoryId: optionalInt(req.query.categoryId),
    status: 'ACTIVE'
  };

  const [allShops, categories] = await Promise.all([listShops(), listLeafCategories()]);
  const shops = allShops.filter((s) => VISIBLE_SHOP.includes(s.ShopStatus));

  let rows = [];
  let error = null;
  if (Number.isNaN(filters.shopId) || Number.isNaN(filters.categoryId)) {
    error = 'Bộ lọc không hợp lệ.';
  } else {
    try {
      rows = (await searchProducts(filters)).filter((p) => VISIBLE_SHOP.includes(p.ShopStatus));
    } catch (e) {
      error = databaseError(e);
    }
  }

  res.render('search', {
    scope: 'buyer',
    basePath: '/buyer',
    title: 'Tìm sản phẩm',
    subtitle: 'Sản phẩm đang bán trên sàn.',
    filters,
    rows,
    shops,
    categories,
    error,
    success: null
  });
});

export default router;

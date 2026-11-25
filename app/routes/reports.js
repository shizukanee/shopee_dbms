import {
  listShops,
  listLeafCategories,
  searchProducts,
  inventoryStats
} from '../productRepository.js';
import { databaseError, optionalInt, optionalStatus, queryMessage } from '../helpers.js';

/**
 * Màn hình tìm kiếm / thống kê dùng chung cho kênh người bán và quản trị.
 * Gọi 2 thủ tục của TV4 (câu 2.3). Với người bán, ShopID bị cố định theo
 * tài khoản đăng nhập — tham số shopId trên URL bị bỏ qua.
 */

export async function renderSearch(req, res, { scope, basePath, forcedShopId = null, title, subtitle }) {
  const filters = {
    keyword: String(req.query.keyword ?? '').trim().slice(0, 200),
    shopId: forcedShopId ?? optionalInt(req.query.shopId),
    categoryId: optionalInt(req.query.categoryId),
    status: optionalStatus(req.query.status)
  };
  const [shops, categories] = await Promise.all([
    forcedShopId ? [] : listShops(),
    listLeafCategories()
  ]);

  let rows = [];
  let error = queryMessage(req.query.err);
  if (Number.isNaN(filters.shopId) || Number.isNaN(filters.categoryId) || filters.status === undefined) {
    error = 'Bộ lọc không hợp lệ.';
  } else {
    try {
      rows = await searchProducts(filters);
    } catch (e) {
      error = databaseError(e);
    }
  }

  res.render('search', {
    scope,
    basePath,
    title,
    subtitle,
    filters,
    rows,
    shops,
    categories,
    error,
    success: queryMessage(req.query.ok)
  });
}

export async function renderStats(req, res, { scope, basePath, forcedShopId = null, title, subtitle }) {
  const filters = {
    shopId: forcedShopId ?? optionalInt(req.query.shopId),
    status: optionalStatus(req.query.status),
    minProducts: optionalInt(req.query.minProducts),
    minStock: optionalInt(req.query.minStock)
  };
  const shops = forcedShopId ? [] : await listShops();

  let rows = [];
  let error = null;
  const bad = [filters.shopId, filters.minProducts, filters.minStock].some(Number.isNaN);
  if (bad || filters.status === undefined) {
    error = 'Bộ lọc không hợp lệ.';
  } else if ((filters.minProducts ?? 0) < 0 || (filters.minStock ?? 0) < 0) {
    error = 'Ngưỡng tối thiểu không được âm.';
  } else {
    try {
      rows = await inventoryStats(filters);
    } catch (e) {
      error = databaseError(e);
    }
  }

  res.render('stats', { scope, basePath, title, subtitle, filters, rows, shops, error });
}

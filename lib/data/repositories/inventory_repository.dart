import '../models/product.dart';
import '../models/lot.dart';

abstract class InventoryRepository {
  Future<List<Product>> getProducts(String labId);
  Future<Product?> getProductByBarcode(String barcode);
  Future<Product> createProduct(Product product);
  Future<Product> updateProduct(Product product);
  Future<void> deleteProduct(String productId);

  Future<List<Lot>> getLotsByProduct(String productId);
  Future<Lot> createLot(Lot lot);
  Future<Lot> updateLot(Lot lot);

  /// Returns products at or below their reorder point.
  Future<List<Product>> getRestockNeeded(String labId);

  /// Returns lots expiring within [withinDays] days.
  Future<List<Lot>> getExpiringSoon(String labId, {int withinDays = 90});
}

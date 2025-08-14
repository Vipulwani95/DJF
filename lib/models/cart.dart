import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  double get total => product.price * quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });
}

class Cart {
  List<CartItem> items = [];
  List<Product>? _products;

  double get total => items.fold(0, (sum, item) => sum + item.total);

  void setProducts(List<Product> products) {
    _products = products;
  }

  void addProduct(Product product, int quantity) {
    if (quantity <= 0) {
      removeProduct(product.id);
      return;
    }

    final existingItemIndex = items.indexWhere((item) => item.product.id == product.id);
    if (existingItemIndex != -1) {
      items[existingItemIndex].quantity = quantity;
    } else {
      items.add(CartItem(product: product, quantity: quantity));
    }
  }

  void removeProduct(String productId) {
    items.removeWhere((item) => item.product.id == productId);
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final existingItemIndex = items.indexWhere((item) => item.product.id == productId);
    if (existingItemIndex != -1) {
      items[existingItemIndex].quantity = quantity;
    } else if (_products != null) {
      final product = _products!.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found'),
      );
      items.add(CartItem(product: product, quantity: quantity));
    }
  }

  int getQuantity(String productId) {
    final item = items.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => CartItem(
        product: Product(
          id: productId,
          name: '',
          hsn: '',
          tax: '',
          price: 0,
          stock: 0,
        ),
        quantity: 0,
      ),
    );
    return item.quantity;
  }

  void clear() {
    items.clear();
  }

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.length;
} 
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import 'local_database_service.dart';

class ProductService {
  static Future<List<Product>> fetchProducts(String scriptUrl) async {
    try {
      final response = await http.get(Uri.parse(scriptUrl));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Product> products = data.map((item) {
          return Product(
            id: item['id']?.toString() ?? '',
            name: item['name']?.toString() ?? '',
            hsn: item['hsn']?.toString() ?? '',
            tax: item['tax']?.toString() ?? '',
            price: double.tryParse(item['price']?.toString() ?? '0') ?? 0.0,
            stock: int.tryParse(item['stock']?.toString() ?? '0') ?? 0,
            imageUrl: item['imageUrl']?.toString(),
            subNames: item['subNames'] != null 
                ? List<String>.from(item['subNames'])
                : [],
          );
        }).toList();

        // Save products to local storage
        await LocalDatabaseService.saveProducts(products);
        return products;
      } else {
        print('Failed to fetch products: ${response.statusCode}');
        // Return local products if available
        return await LocalDatabaseService.getLocalProducts();
      }
    } catch (e) {
      print('Error fetching products: $e');
      // Return local products if available
      return await LocalDatabaseService.getLocalProducts();
    }
  }

  static Future<void> updateProductStock(String productId, int newStock) async {
    try {
      final db = await LocalDatabaseService.database;
      await db.update(
        'products',
        {'stock': newStock},
        where: 'id = ?',
        whereArgs: [productId],
      );
    } catch (e) {
      print('Error updating product stock: $e');
    }
  }

  static Future<Product?> getProductById(String productId) async {
    try {
      final db = await LocalDatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (maps.isNotEmpty) {
        final map = maps.first;
        return Product(
          id: map['id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          hsn: map['hsn']?.toString() ?? '',
          tax: map['tax']?.toString() ?? '',
          price: double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
          stock: int.tryParse(map['stock']?.toString() ?? '0') ?? 0,
          imageUrl: map['imageUrl']?.toString(),
          subNames: map['subNames'] != null 
              ? List<String>.from(json.decode(map['subNames']))
              : [],
        );
      }
      return null;
    } catch (e) {
      print('Error getting product by ID: $e');
      return null;
    }
  }
} 
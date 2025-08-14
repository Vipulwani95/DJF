import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import 'local_database_service.dart';
import 'package:flutter/material.dart';

class OrderService {
  static Future<void> submitOrder({
    required String invoiceNumber,
    required String username,
    required double totalAmount,
    required String paymentMethod,
    required String cashHandler,
    required List<Map<String, dynamic>> items,
    required String scriptUrl,
  }) async {
    // Check if online first
    final isOnline = await LocalDatabaseService.isOnline();
    if (!isOnline) {
      throw Exception('No internet connection. Please check your connection and try again.');
    }

    final orderData = {
      'action': 'submitOrder',
      'invoiceNumber': invoiceNumber,
      'date': DateTime.now().toIso8601String(),
      'username': username,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod.toLowerCase(),
      'cashHandler': paymentMethod.toLowerCase() == 'cash' ? cashHandler : 'N/A',
      'status': 'completed',
      'items': items,
    };

    // Submit order online immediately
    final response = await http.post(
      Uri.parse(scriptUrl),
      headers: {"Content-Type": "application/json"},
      body: json.encode(orderData),
    );

    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('Failed to submit order: ${response.statusCode}');
    }

    // Update local stock after successful submission
    for (var item in items) {
      final productId = item['id'];
      final quantity = item['quantity'];
      final product = await LocalDatabaseService.getProductById(productId);
      if (product != null) {
        final newStock = product.stock - quantity;
        await LocalDatabaseService.updateProductStock(productId, newStock);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getLocalOrders() async {
    try {
      final db = await LocalDatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query('orders');
      return maps.map((map) {
        return {
          'id': map['id'],
          'date': map['date'],
          'username': map['username'],
          'totalAmount': map['totalAmount'],
          'paymentMethod': map['paymentMethod'],
          'cashHandler': map['cashHandler'],
          'status': map['status'],
          'items': json.decode(map['items']),
        };
      }).toList();
    } catch (e) {
      print('Error getting local orders: $e');
      return [];
    }
  }

  static Future<void> saveLocalOrder(Map<String, dynamic> orderData) async {
    try {
      final db = await LocalDatabaseService.database;
      await db.insert(
        'orders',
        {
          'id': orderData['invoiceNumber'],
          'date': orderData['date'],
          'username': orderData['username'],
          'totalAmount': orderData['totalAmount'],
          'paymentMethod': orderData['paymentMethod'],
          'cashHandler': orderData['cashHandler'],
          'status': orderData['status'],
          'items': json.encode(orderData['items']),
        },
      );
    } catch (e) {
      print('Error saving local order: $e');
    }
  }

  static Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final db = await LocalDatabaseService.database;
      await db.update(
        'orders',
        {'status': status},
        where: 'id = ?',
        whereArgs: [orderId],
      );
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  // Get orders by payment method
  static Future<List<Map<String, dynamic>>> getOrdersByPaymentMethod(String paymentMethod) async {
    try {
      final db = await LocalDatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'orders',
        where: 'paymentMethod = ?',
        whereArgs: [paymentMethod.toLowerCase()],
      );
      return maps.map((map) {
        return {
          'id': map['id'],
          'date': map['date'],
          'username': map['username'],
          'totalAmount': map['totalAmount'],
          'paymentMethod': map['paymentMethod'],
          'cashHandler': map['cashHandler'],
          'status': map['status'],
          'items': json.decode(map['items']),
        };
      }).toList();
    } catch (e) {
      print('Error getting orders by payment method: $e');
      return [];
    }
  }

  // Get orders by cash handler
  static Future<List<Map<String, dynamic>>> getOrdersByCashHandler(String cashHandler) async {
    try {
      final db = await LocalDatabaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'orders',
        where: 'cashHandler = ?',
        whereArgs: [cashHandler],
      );
      return maps.map((map) {
        return {
          'id': map['id'],
          'date': map['date'],
          'username': map['username'],
          'totalAmount': map['totalAmount'],
          'paymentMethod': map['paymentMethod'],
          'cashHandler': map['cashHandler'],
          'status': map['status'],
          'items': json.decode(map['items']),
        };
      }).toList();
    } catch (e) {
      print('Error getting orders by cash handler: $e');
      return [];
    }
  }
} 
import 'package:flutter/material.dart';

class Product {
  final String id;
  final String name;
  final String hsn;
  final String tax;
  final double price;
  int stock;
  int quantity;
  final String? imageUrl;
  final List<String> subNames;

  Product({
    required this.id,
    required this.name,
    required this.hsn,
    required this.tax,
    required this.price,
    required this.stock,
    this.quantity = 0,
    this.imageUrl,
    this.subNames = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hsn': hsn,
      'tax': tax,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
      'subNames': subNames,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['S.No']?.toString() ?? '',
      name: map['Particulars']?.toString() ?? '',
      hsn: map['HSN']?.toString() ?? '',
      tax: map['Tax']?.toString() ?? '',
      price: double.tryParse(map['Rate']?.toString() ?? '0') ?? 0.0,
      stock: int.tryParse(map['Bal']?.toString() ?? '0') ?? 0,
      imageUrl: map['imageUrl']?.toString(),
      subNames: map['subNames'] is List ? List<String>.from(map['subNames']) : [],
    );
  }
} 
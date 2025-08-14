import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path_lib;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class LocalDatabaseService {
  static Database? _database;
  static SharedPreferences? _prefs;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Check if we're online (web-safe)
  static Future<bool> isOnline() async {
    try {
      if (kIsWeb) {
        // Use a lightweight HTTP request for web (no dart:io)
        final uri = Uri.parse('https://www.google.com/generate_204');
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 204 || response.statusCode == 200;
      } else {
        final result = await InternetAddress.lookup('google.com');
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // On web we don't use sqflite; return a dummy in-memory database interface is not supported.
      // Any direct DB access should be avoided on web in this service. Methods below handle web via SharedPreferences.
      throw UnsupportedError('SQLite database is not supported on Web in LocalDatabaseService');
    }

    String dbPath = path_lib.join(await getDatabasesPath(), 'retail_app.db');
    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            name TEXT,
            hsn TEXT,
            tax TEXT,
            price REAL,
            stock INTEGER,
            imageUrl TEXT,
            subNames TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE orders (
            id TEXT PRIMARY KEY,
            date TEXT,
            username TEXT,
            totalAmount REAL,
            paymentMethod TEXT,
            cashHandler TEXT,
            status TEXT,
            items TEXT
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE products ADD COLUMN subNames TEXT');
          } catch (e) {
            print('Column subNames might already exist: $e');
          }
        }
      },
    );
  }

  // Save products to local storage
  static Future<void> saveProducts(List<Product> products) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final productsJson = products.map((p) => json.encode({
            'id': p.id,
            'name': p.name,
            'hsn': p.hsn,
            'tax': p.tax,
            'price': p.price,
            'stock': p.stock,
            'imageUrl': p.imageUrl,
            'subNames': p.subNames,
          })).toList();
      await prefs.setStringList('products', productsJson);
      await prefs.setString('last_sync', DateTime.now().toIso8601String());
      return;
    }

    final db = await database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert(
        'products',
        {
          'id': product.id,
          'name': product.name,
          'hsn': product.hsn,
          'tax': product.tax,
          'price': product.price,
          'stock': product.stock,
          'imageUrl': product.imageUrl,
          'subNames': json.encode(product.subNames),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync', DateTime.now().toIso8601String());
  }

  // Get products from local storage
  static Future<List<Product>> getLocalProducts() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final productsJson = prefs.getStringList('products') ?? [];
      return productsJson.map((jsonStr) {
        final map = json.decode(jsonStr);
        return Product(
          id: map['id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          hsn: map['hsn']?.toString() ?? '',
          tax: map['tax']?.toString() ?? '',
          price: double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
          stock: int.tryParse(map['stock']?.toString() ?? '0') ?? 0,
          imageUrl: map['imageUrl']?.toString(),
          subNames: (map['subNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        );
      }).toList();
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) {
      final map = maps[i];
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
    });
  }

  // Save login state
  static Future<void> saveLoginState(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setBool('isLoggedIn', true);
  }

  // Check login state
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // Get saved username
  static Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  // Clear login state
  static Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.setBool('isLoggedIn', false);
  }
} 
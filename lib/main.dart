import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path_lib;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Utility class to handle product names with brackets
class ProductNameUtils {
  // Extract display name (without brackets) from full name
  // Only removes brackets that contain exactly 3 alphabetic characters (like SAP, OND)
  static String getDisplayName(String fullName) {
    // Pattern: matches (exactly 3 alphabetic characters) with optional space before
    final regex = RegExp(r'\s*\([A-Za-z]{3}\)');
    return fullName.replaceAll(regex, '').trim();
  }

  // Get image name from full name (same as display name)
  static String getImageName(String fullName) {
    return getDisplayName(fullName);
  }

  // Check if name has brackets with exactly 3 alphabetic characters
  static bool hasBrackets(String name) {
    final regex = RegExp(r'\([A-Za-z]{3}\)');
    return regex.hasMatch(name);
  }

  // Get the bracketed part for backend calculations
  static String getBracketedPart(String fullName) {
    final regex = RegExp(r'\(([A-Za-z]{3})\)');
    final match = regex.firstMatch(fullName);
    return match?.group(1) ?? '';
  }

  // Get display name from item data (for orders)
  static String getItemDisplayName(dynamic item) {
    final name = item['name']?.toString() ?? '';
    return getDisplayName(name);
  }

  // Get possible image names (tries both display name and original name)
  static List<String> getPossibleImageNames(String fullName) {
    final displayName = getDisplayName(fullName);
    final hasBracketsFlag = hasBrackets(fullName);
    
    if (hasBracketsFlag) {
      // If original name has 3-letter brackets, try both display name and original name
      return [displayName, fullName];
    } else {
      // If no 3-letter brackets, just use the original name
      return [fullName];
    }
  }

  // Test function to verify bracket removal functionality
  static void testBracketRemoval() {
    final testCases = [
      'Aloevera Juice',
      'Aloevera Juice (SAP)',
      'Aloevera Juice (OND)',
      'Black Salt (Kala Namak) 100g',
      'Product Name (with spaces)',
      'Product (123) Name',
      'Product Name (multiple) (brackets)',
      'Aloevera Juice (old)',
      'Product (ABC) Name',
      'Product (123) Name',
      'Product (A1B) Name',
    ];

    print('Testing bracket removal functionality:');
    for (final testCase in testCases) {
      final displayName = getDisplayName(testCase);
      final hasBracketsFlag = hasBrackets(testCase);
      final bracketedPart = getBracketedPart(testCase);
      final possibleImageNames = getPossibleImageNames(testCase);
      
      print('Original: "$testCase"');
      print('Display: "$displayName"');
      print('Has 3-letter brackets: $hasBracketsFlag');
      print('Bracketed part: "$bracketedPart"');
      print('Image loading strategy:');
      if (hasBracketsFlag) {
        print('  1. Try: assets/images/$displayName.jpg');
        print('  2. Fallback: assets/images/$testCase.jpg');
        print('  3. Default: assets/images/djf_logo.png');
      } else {
        print('  1. Try: assets/images/$testCase.jpg');
        print('  2. Default: assets/images/djf_logo.png');
      }
      print('---');
    }
  }
}

void main() async {
  try {
    print('Starting app initialization...');
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize FFI for desktop platforms
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      print('Initializing FFI for desktop platform...');
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default database factory for desktop
      databaseFactory = databaseFactoryFfi;
    }
    
    // Test bracket removal functionality
    ProductNameUtils.testBracketRemoval();
    
    if (kIsWeb) {
      print('Running on web platform');
    } else {
      print('Running on native platform');
    }
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print('Stack trace: $stackTrace');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('Building MyApp widget');
    return MaterialApp(
      title: 'RetailPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    print('SplashScreen initState called');
    if (kIsWeb) {
      // Skip version check on web to avoid CORS/network issues
      _checkLoginStatus();
    } else {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      // 1. Fetch version.json
      final response = await http.get(Uri.parse('https://drive.google.com/uc?export=download&id=1q0ps7evbXqI78oublXBMCTRtHsojznSF'));
      if (response.statusCode == 200) {
        final versionData = json.decode(response.body);
        final latestVersion = versionData['latest_version']?.toString();
        final apkUrl = versionData['apk_url']?.toString();
        // 2. Get current app version
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        print('Current version: $currentVersion, Latest version: $latestVersion');
        // 3. Compare
        if (latestVersion != null && apkUrl != null && currentVersion != latestVersion) {
          // 4. Show force update dialog
          if (mounted) {
            _showForceUpdateDialog(apkUrl, latestVersion);
          }
          return;
        }
      }
    } catch (e) {
      print('Error checking for update: $e');
    }
    // If no update needed, continue normal flow
    _checkLoginStatus();
  }

  void _showForceUpdateDialog(String apkUrl, String latestVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A new version ($latestVersion) is available. Please update to continue.'),
              const SizedBox(height: 12),
              const Text(
                'What\'s new:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Bug fixes for oder duplicacy'),
              // Add more lines here manually as needed
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(apkUrl))) {
                  await launchUrl(Uri.parse(apkUrl), mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Download Update'),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _checkLoginStatus() async {
    try {
      print('Checking login status...');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      String? username = prefs.getString('username');

      print('Login status - isLoggedIn: $isLoggedIn, username: $username');

      // Small delay for splash effect
      await Future.delayed(Duration(milliseconds: 1000));

      if (mounted) {
        if (isLoggedIn && username != null) {
          print('Navigating to RetailDashboard');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RetailDashboard(username: username),
            ),
          );
        } else {
          print('Navigating to LoginPage');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error in _checkLoginStatus: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building SplashScreen');
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Color(0xFF4A90E2),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Items',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Orders',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Items';
      case 2:
        return 'Order Management';
      default:
        return 'RetailPro';
    }
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildInventory();
      case 2:
        return _buildSales();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return Center(
      child: Text(
        'Dashboard',
        style: TextStyle(fontSize: 24),
      ),
    );
  }

  Widget _buildInventory() {
    return Center(
      child: Text(
        'Inventory',
        style: TextStyle(fontSize: 24),
      ),
    );
  }

  Widget _buildSales() {
    return Center(
      child: Text(
        'Sales',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final String scriptUrl = 'https://script.google.com/macros/s/AKfycbzP_kh7Ha1daunpvgWv1z4nZhQ4JhVsD7ErkVq64pn7KXwsuA1l-NAZE037sHJbMrZCQg/exec';

  bool isLoading = false;

  Future<void> submitData() async {
    final String username = usernameController.text.trim();
    final String password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Please enter both username and password."),
      ));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      http.Response response;
      final uri = Uri.parse(scriptUrl);
      if (kIsWeb) {
        // Avoid preflight by using text/plain with JSON payload
        response = await http.post(
          uri,
          headers: {
            'Content-Type': 'text/plain;charset=utf-8',
          },
          body: json.encode({
            'action': 'login',
            'Login': username,
            'Password': password,
          }),
        );
      } else {
        response = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            'action': 'login',
            'Login': username,
            'Password': password,
          }),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 302) {
        // Try to parse JSON { success: bool, message: string }
        bool ok = false;
        String message = '';
        try {
          final map = json.decode(response.body);
          ok = map['success'] == true;
          message = (map['message']?.toString() ?? '').trim();
        } catch (_) {
          // Fallback if backend returns plain text
          ok = true;
          message = 'Login successful';
        }

        if (ok) {
          // Save login state
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('username', username);

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("✅ ${message.isEmpty ? 'Login successful!' : message}"),
          ));

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RetailDashboard(username: username),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("❌ ${message.isEmpty ? 'Invalid credentials' : message}"),
          ));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("❌ Failed: ${response.statusCode}"),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("❌ Error: $e"),
      ));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFBBB5F6),
              Color(0xFFFFC1C5),
              Color(0xFFF8D2B9)
            ],
            stops: [0, 0.5, 1],
            begin: AlignmentDirectional(-1, -1),
            end: AlignmentDirectional(1, 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Logo container (independent size)
                  Container(
                    width: 150,  // Increased from 150
                    height: 150, // Increased from 150
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/djf_full.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  // Username field
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: Colors.indigo.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.indigo.shade400, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.indigo.shade700, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      prefixIcon: Icon(Icons.person, color: Colors.indigo.shade600),
                    ),
                    style: TextStyle(color: Colors.indigo.shade800),
                  ),
                  SizedBox(height: 20),
                  // Password field
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.indigo.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.indigo.shade400, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.indigo.shade700, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                      prefixIcon: Icon(Icons.lock, color: Colors.indigo.shade600),
                    ),
                    style: TextStyle(color: Colors.indigo.shade800),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: isLoading ? null : submitData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size(double.infinity, 55),
                      elevation: 4,
                    ),
                    child: isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Login',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>> items;
  final String invoiceNumber;
  final Function(bool, String, String) onPaymentConfirmed;

  const PaymentScreen({
    Key? key,
    required this.totalAmount,
    required this.items,
    required this.invoiceNumber,
    required this.onPaymentConfirmed,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedPaymentMethod;
  final TextEditingController _customerNameController = TextEditingController();

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  void _handlePaymentConfirmation() {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    // Use "Ashram" as default if customer name is empty
    String customerName = _customerNameController.text.trim().isEmpty
        ? 'Ashram'
        : _customerNameController.text.trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Confirm payment of ₹${widget.totalAmount.toStringAsFixed(2)} via ${_selectedPaymentMethod == 'cash' ? 'Cash' : 'Online'} payment?\n\nCustomer: $customerName',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onPaymentConfirmed(
                true,
                _selectedPaymentMethod!,
                customerName,
              );
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Order completed successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF4A90E2),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Inv: ${widget.invoiceNumber}'),
                      const SizedBox(height: 8),
                      Text(
                        'Total Amount: ₹${widget.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Payment Method',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Cash Payment Option
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPaymentMethod = 'cash';
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedPaymentMethod == 'cash'
                                  ? const Color(0xFF4A90E2)
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedPaymentMethod == 'cash'
                                ? const Color(0xFF4A90E2).withOpacity(0.1)
                                : Colors.white,
                          ),
                          child: ListTile(
                            title: const Text(
                              'Cash Payment',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            leading: Radio<String>(
                              value: 'cash',
                              groupValue: _selectedPaymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPaymentMethod = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Online Payment Option
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedPaymentMethod = 'online';
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedPaymentMethod == 'online'
                                  ? const Color(0xFF4A90E2)
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedPaymentMethod == 'online'
                                ? const Color(0xFF4A90E2).withOpacity(0.1)
                                : Colors.white,
                          ),
                          child: ListTile(
                            title: const Text(
                              'Online Payment',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            leading: Radio<String>(
                              value: 'online',
                              groupValue: _selectedPaymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPaymentMethod = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      if (_selectedPaymentMethod == 'online') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Scan QR Code to Pay',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Amount: ₹${widget.totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A90E2),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                alignment: Alignment.centerRight,
                                child: QrImageView(
                                  data: 'upi://pay?pa=q977863280@ybl&pn=Merchant&am=${widget.totalAmount.toStringAsFixed(2)}&cu=INR',
                                  version: QrVersions.auto,
                                  size: 250.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Customer Name Input Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Name',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          hintText: 'Enter customer name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handlePaymentConfirmation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Confirm Payment',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Model classes
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
    required this.quantity,
    this.imageUrl,
    this.subNames = const [],
  });

  // Getter for display name (without 3-letter brackets)
  String get displayName => ProductNameUtils.getDisplayName(name);

  // Getter for image name (without 3-letter brackets)
  String get imageName => ProductNameUtils.getImageName(name);

  // Getter for possible image names (tries both display name and original name)
  List<String> get possibleImageNames => ProductNameUtils.getPossibleImageNames(name);

  // Getter to check if name has 3-letter brackets
  bool get hasBrackets => ProductNameUtils.hasBrackets(name);

  // Getter for bracketed part (3-letter codes only)
  String get bracketedPart => ProductNameUtils.getBracketedPart(name);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hsn': hsn,
      'tax': tax,
      'price': price,
      'stock': stock,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'subNames': subNames,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    print('Creating Product from map: $map');
    
    // Extract and validate required fields
    final id = map['S.No']?.toString() ?? '';
    final name = map['Particulars']?.toString() ?? '';
    final hsn = map['HSN']?.toString() ?? '';
    final tax = map['Tax']?.toString() ?? '';
    final price = double.tryParse(map['Rate']?.toString() ?? '0') ?? 0.0;
    final stock = int.tryParse(map['Bal']?.toString() ?? '0') ?? 0;
    final quantity = int.tryParse(map['Qty']?.toString() ?? '0') ?? 0;
    
    print('Parsed values:');
    print('ID: $id');
    print('Name: $name');
    print('Display Name: ${ProductNameUtils.getDisplayName(name)}');
    print('HSN: $hsn');
    print('Tax: $tax');
    print('Price: $price');
    print('Stock: $stock');
    print('Quantity: $quantity');
    
    return Product(
      id: id,
      name: name,
      hsn: hsn,
      tax: tax,
      price: price,
      stock: stock,
      quantity: quantity,
      imageUrl: map['imageUrl']?.toString(),
      subNames: map['subNames'] is List ? List<String>.from(map['subNames']) : [],
    );
  }
}

class CartItem {
  Product product;
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
    print('Setting products in cart: ${products.length} products');
    _products = products;
    // Update product references in cart items
    for (var item in items) {
      final updatedProduct = products.firstWhere(
        (p) => p.id == item.product.id,
        orElse: () => item.product,
      );
      print('Updating cart item: ${item.product.name}, quantity: ${item.quantity}, product quantity: ${updatedProduct.quantity}');
      item.product = updatedProduct;
    }
  }

  void addProduct(Product product, int quantity) {
    print('Adding product to cart: ${product.name}, quantity: $quantity, product quantity: ${product.quantity}');
    if (quantity <= 0) {
      removeProduct(product.id);
      return;
    }

    final existingItemIndex = items.indexWhere((item) => item.product.id == product.id);
    if (existingItemIndex != -1) {
      items[existingItemIndex].quantity = quantity;
      print('Updated existing item quantity to: $quantity');
    } else {
      items.add(CartItem(product: product, quantity: quantity));
      print('Added new item with quantity: $quantity');
    }
  }

  void updateQuantity(String productId, int quantity) {
    print('Updating quantity for product: $productId to: $quantity');
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final existingItemIndex = items.indexWhere((item) => item.product.id == productId);
    if (existingItemIndex != -1) {
      items[existingItemIndex].quantity = quantity;
      print('Updated existing item quantity to: $quantity');
    } else {
      final product = _products?.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found'),
      );
      if (product != null) {
        items.add(CartItem(product: product, quantity: quantity));
        print('Added new item with quantity: $quantity');
      }
    }
  }

  int getQuantity(String productId) {
    try {
      final item = items.firstWhere(
        (item) => item.product.id == productId,
        orElse: () {
          print('Product not found in cart: $productId');
          return CartItem(
            product: Product(
              id: productId,
              name: '',
              hsn: '',
              tax: '',
              price: 0,
              stock: 0,
              quantity: 0,
            ),
            quantity: 0,
          );
        },
      );
      print('Getting quantity for product: $productId, quantity: ${item.quantity}');
      return item.quantity;
    } catch (e) {
      print('Error getting quantity for product: $productId, error: $e');
      return 0;
    }
  }

  void removeProduct(String productId) {
    print('Removing product from cart: $productId');
    items.removeWhere((item) => item.product.id == productId);
  }

  void clear() {
    print('Clearing cart');
    items.clear();
  }
}

class SalesSummary {
  final double todaySales;
  final double weekSales;
  final double monthSales;
  final int pendingOrders;
  final Map<String, double> todayPaymentMethods;
  final Map<String, double> weekPaymentMethods;
  final Map<String, double> monthPaymentMethods;
  final Map<String, List<String>> cashHandlers;

  SalesSummary({
    required this.todaySales,
    required this.weekSales,
    required this.monthSales,
    required this.pendingOrders,
    required this.todayPaymentMethods,
    required this.weekPaymentMethods,
    required this.monthPaymentMethods,
    required this.cashHandlers,
  });

  factory SalesSummary.fromOrders(List<dynamic> orders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    double todayTotal = 0;
    double weekTotal = 0;
    double monthTotal = 0;
    Map<String, double> todayPayments = {'online': 0, 'cash': 0};
    Map<String, double> weekPayments = {'online': 0, 'cash': 0};
    Map<String, double> monthPayments = {'online': 0, 'cash': 0};
    Map<String, List<String>> handlers = {};

    for (var order in orders) {
      try {
        final orderDate = DateFormat('dd MMM yyyy, hh:mm a').parse(order['date']);
        final amount = (order['totalAmount'] as num).toDouble();
        final paymentMethod = (order['paymentMethod']?.toString().toLowerCase() ?? 'cash');
        final cashHandler = order['cashHandler']?.toString() ?? '';

        if (orderDate.isAfter(today)) {
          todayTotal += amount;
          todayPayments[paymentMethod] = (todayPayments[paymentMethod] ?? 0) + amount;
          if (paymentMethod == 'cash' && cashHandler.isNotEmpty) {
            handlers[today.toString()] = handlers[today.toString()] ?? [];
            if (!handlers[today.toString()]!.contains(cashHandler)) {
              handlers[today.toString()]!.add(cashHandler);
            }
          }
        }
        if (orderDate.isAfter(weekAgo)) {
          weekTotal += amount;
          weekPayments[paymentMethod] = (weekPayments[paymentMethod] ?? 0) + amount;
          if (paymentMethod == 'cash' && cashHandler.isNotEmpty) {
            handlers[weekAgo.toString()] = handlers[weekAgo.toString()] ?? [];
            if (!handlers[weekAgo.toString()]!.contains(cashHandler)) {
              handlers[weekAgo.toString()]!.add(cashHandler);
            }
          }
        }
        if (orderDate.isAfter(monthAgo)) {
          monthTotal += amount;
          monthPayments[paymentMethod] = (monthPayments[paymentMethod] ?? 0) + amount;
          if (paymentMethod == 'cash' && cashHandler.isNotEmpty) {
            handlers[monthAgo.toString()] = handlers[monthAgo.toString()] ?? [];
            if (!handlers[monthAgo.toString()]!.contains(cashHandler)) {
              handlers[monthAgo.toString()]!.add(cashHandler);
            }
          }
        }
      } catch (e) {
        print('Error processing order: $e');
      }
    }

    return SalesSummary(
      todaySales: todayTotal,
      weekSales: weekTotal,
      monthSales: monthTotal,
      pendingOrders: orders.where((o) => o['status'] != 'Completed').length,
      todayPaymentMethods: todayPayments,
      weekPaymentMethods: weekPayments,
      monthPaymentMethods: monthPayments,
      cashHandlers: handlers,
    );
  }
}

class RetailDashboard extends StatefulWidget {
  final String username;

  const RetailDashboard({super.key, required this.username});

  @override
  State<RetailDashboard> createState() => _RetailDashboardState();
}

class _RetailDashboardState extends State<RetailDashboard> {
  int _currentIndex = 0;
  late SalesSummary salesSummary = SalesSummary(
    todaySales: 0,
    weekSales: 0,
    monthSales: 0,
    pendingOrders: 0,
    todayPaymentMethods: {'online': 0, 'cash': 0},
    weekPaymentMethods: {'online': 0, 'cash': 0},
    monthPaymentMethods: {'online': 0, 'cash': 0},
    cashHandlers: {},
  );
  List<Product> products = [];
  List<Product> filteredProducts = [];
  bool isLoading = false;
  final Cart cart = Cart();
  final TextEditingController searchController = TextEditingController();

  // Add these new variables here
  List<dynamic> userOrders = [];
  bool isLoadingOrders = false;

  // Update this URL
  final String scriptUrl = 'https://script.google.com/macros/s/AKfycbzP_kh7Ha1daunpvgWv1z4nZhQ4JhVsD7ErkVq64pn7KXwsuA1l-NAZE037sHJbMrZCQg/exec';

  final TextEditingController _searchController = TextEditingController();
  String selectedHSN = '';
  List<String> availableHSNs = [];
  String? selectedPaymentMethod;
  String cashHandlerName = '';
  bool _isLoading = false;
  bool _isSearching = false;
  List<Product> _searchResults = [];
  List<String> _cashHandlers = ['John', 'Jane', 'Mike'];
  // Admin/username filtering for Orders
  String selectedUsername = 'All';
  List<String> availableUsernames = ['All'];
  bool get isAdmin => widget.username.toLowerCase() == 'admin';
  
  // Stock checking variables
  Map<String, int> stockCheckCounts = {};
  bool isStockCheckingMode = false;
  String stockCheckFilter = 'all'; // 'all', 'Z_Official Only (Stock checking)', 'pending'
  Map<String, TextEditingController> stockCheckControllers = {};
  
  // Date filter variables
  DateTime? startDate;
  DateTime? endDate;
  // Unified date range selection
  DateTimeRange? dateRange;
  List<dynamic> filteredOrders = [];

  @override
  void initState() {
    super.initState();
    _loadSavedHSN();
    // Ensure payment filter defaults to 'All'
    selectedPaymentMethod ??= 'All';
    // Initialize username selection
    selectedUsername = isAdmin ? 'All' : widget.username;
    fetchOrders().then((_) {
      setState(() {
        salesSummary = SalesSummary.fromOrders(userOrders);
        _filterOrdersByDate(); // Initialize filtered orders
      });
    });
    fetchInventory();
  }

  // Normalize and parse order date safely
  DateTime? _parseOrderDate(String raw) {
    try {
      final trimmed = raw.trim();
      // Try ISO-8601 first (e.g., 2025-08-10T13:07:00Z or without Z)
      final iso = DateTime.tryParse(trimmed);
      if (iso != null) return iso;
      // Normalize am/pm to uppercase (e.g., 'pm' -> 'PM')
      final normalized = trimmed.replaceAllMapped(
        RegExp(r'\b(am|pm)\b', caseSensitive: false),
        (m) => m.group(1)!.toUpperCase(),
      );
      try {
        return DateFormat('dd MMM yyyy, hh:mm a', 'en_US').parse(normalized);
      } catch (_) {
        // Fallback without leading zero hour
        try {
          return DateFormat('dd MMM yyyy, h:mm a', 'en_US').parse(normalized);
        } catch (_) {
          // Last resort: try parsing without comma just in case
          final noComma = normalized.replaceFirst(', ', ' ');
          return DateFormat('dd MMM yyyy hh:mm a', 'en_US').parse(noComma);
        }
      }
    } catch (e) {
      print('Error parsing order date: $raw, error: $e');
      return null;
    }
  }

  // Method to filter orders by date range
  void _filterOrdersByDate() {
    setState(() {
      final hasLegacy = startDate != null || endDate != null;
      final hasRange = dateRange != null;
      if (!hasLegacy && !hasRange) {
        filteredOrders = userOrders;
      } else {
        final DateTime? s = hasRange ? dateRange!.start : startDate;
        final DateTime? e = hasRange ? dateRange!.end : endDate;
        filteredOrders = userOrders.where((order) {
          final dateStr = order['date']?.toString() ?? '';
          final orderDate = _parseOrderDate(dateStr);
          if (orderDate == null) return false;
          bool within = true;
          if (s != null) {
            final startOfDay = DateTime(s.year, s.month, s.day);
            within = within && !orderDate.isBefore(startOfDay);
          }
          if (e != null) {
            final endOfDay = DateTime(e.year, e.month, e.day, 23, 59, 59, 999);
            within = within && !orderDate.isAfter(endOfDay);
          }
          return within;
        }).toList();
      }
    });
  }

  // Centralized view of orders respecting date, username (admin), and payment filters
  List<Map<String, dynamic>> get visibleOrders {
    final List<Map<String, dynamic>> base =
        List<Map<String, dynamic>>.from(filteredOrders);
    return base.where((order) {
      // Username filter (admin selects a specific user)
      if (isAdmin && selectedUsername != 'All') {
        final uname = (order['username']?.toString() ?? '').trim();
        if (uname != selectedUsername) return false;
      }
      // Payment method filter
      final sel = (selectedPaymentMethod ?? 'All');
      if (sel != 'All') {
        final pm = (order['paymentMethod']?.toString().toLowerCase() ?? 'cash');
        if (pm != sel.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  // Add this new method to load saved HSN
  Future<void> _loadSavedHSN() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHSN = prefs.getString('selectedHSN') ?? '';
    // Only set if it's not 'All' and exists in available HSNs
    if (savedHSN != 'All' && savedHSN.isNotEmpty) {
      setState(() {
        selectedHSN = savedHSN;
      });
    }
  }

  // Add this new method to save selected HSN
  Future<void> _saveSelectedHSN(String hsn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedHSN', hsn);
  }

  void _updateAvailableHSNs() {
    final hsns = products.map((p) => p.hsn).toSet().toList();
    hsns.sort();
    setState(() {
      availableHSNs = hsns;
      // Set first HSN as default if selectedHSN is empty or was 'All'
      if (selectedHSN.isEmpty || selectedHSN == 'All' || !hsns.contains(selectedHSN)) {
        selectedHSN = hsns.isNotEmpty ? hsns.first : '';
      }
    });
  }

  void _filterProducts(String query) {
    setState(() {
      filteredProducts = products.where((product) {
        final fullName = product.name.toLowerCase();
        final displayName = product.displayName.toLowerCase();
        final searchTerms = query.toLowerCase().split(' ');
        final matchesSearch = searchTerms.every((term) => 
          fullName.contains(term) || displayName.contains(term));
        final matchesHSN = selectedHSN.isEmpty || product.hsn == selectedHSN;
        return matchesSearch && matchesHSN;
      }).toList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchInventory() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Try to get data from local storage first
      final localProducts = await LocalDatabaseService.getLocalProducts();
      if (localProducts.isNotEmpty) {
        // Preserve cart quantities
        final currentCartItems = Map<String, int>.fromEntries(
          cart.items.map((item) => MapEntry(item.product.id, item.quantity))
        );
        
        setState(() {
          products = localProducts;
          cart.setProducts(products);
          // Restore cart quantities
          currentCartItems.forEach((productId, quantity) {
            if (quantity > 0) {
              cart.updateQuantity(productId, quantity);
            }
          });
          _updateAvailableHSNs();
          _filterProducts(searchController.text);
        });
      }

      // Try to fetch from server
      final bool shouldFetch = kIsWeb ? true : await LocalDatabaseService.isOnline();
      if (shouldFetch) {
        // Fetch inventory data
        final inventoryResponse = await http.get(
          Uri.parse('$scriptUrl?action=getInventory'),
        );

        print('Inventory Response Status: ${inventoryResponse.statusCode}');
        print('Inventory Response Body: ${inventoryResponse.body}');

        if (inventoryResponse.statusCode == 200) {
          final decoded = json.decode(inventoryResponse.body);
          List<dynamic> data;
          if (decoded is List) {
            data = decoded;
          } else if (decoded is Map<String, dynamic>) {
            // If server returned an object, try to extract list under 'data', else empty
            final possible = decoded['data'];
            data = (possible is List) ? possible : <dynamic>[];
          } else {
            data = <dynamic>[];
          }
          print('Parsed Inventory Data length: ${data.length}');
          
          final serverProducts = data.map((item) {
            print('Processing item: $item');
            final product = Product.fromMap(item);
            print('Created product: ${product.name} with quantity: ${product.quantity}');
            return product;
          }).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          
          print('Processed Products: ${serverProducts.length}');
          
          // Save to local storage
          await LocalDatabaseService.saveProducts(serverProducts);
          
          setState(() {
            products = serverProducts;
            cart.setProducts(products);
            _updateAvailableHSNs();
            _filterProducts(searchController.text);
          });
        } else {
          print('Error response from server: ${inventoryResponse.statusCode}');
          if (products.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading inventory. Server returned ${inventoryResponse.statusCode}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // Offline and no local cache: inform user
        if (products.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please check your internet connection'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching inventory: $e');
      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading inventory. Please check your internet connection.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchOrders() async {
    setState(() {
      isLoadingOrders = true;
    });

    try {
      // Build endpoint based on admin/username selection
      Future<http.Response> fetchOrdersUri(Uri uri) => http.get(uri);
      http.Response response;

      if (isAdmin) {
        if (selectedUsername == 'All') {
          // Try multiple patterns for maximum compatibility
          final candidates = <Uri>[
            Uri.parse(scriptUrl).replace(queryParameters: {'action': 'getOrders', 'username': 'all'}),
            Uri.parse(scriptUrl).replace(queryParameters: {'action': 'getOrders', 'username': 'admin'}),
            Uri.parse(scriptUrl).replace(queryParameters: {'action': 'getOrders'}),
          ];
          response = await fetchOrdersUri(candidates[0]);
          if (response.statusCode == 200 && response.body.trim() == '[]') {
            response = await fetchOrdersUri(candidates[1]);
            if (response.statusCode == 200 && response.body.trim() == '[]') {
              response = await fetchOrdersUri(candidates[2]);
            }
          }
        } else {
          final uri = Uri.parse(scriptUrl).replace(queryParameters: {
            'action': 'getOrders',
            'username': selectedUsername,
          });
          response = await fetchOrdersUri(uri);
        }
      } else {
        final uri = Uri.parse(scriptUrl).replace(queryParameters: {
          'action': 'getOrders',
          'username': widget.username,
        });
        response = await fetchOrdersUri(uri);
      }

      print('Orders Response: ${response.body}'); // Debug print

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() {
          userOrders = decodedData is List ? decodedData : [];
          // Populate usernames for admin dropdown
          if (isAdmin) {
            final names = userOrders
                .map((o) => (o['username']?.toString() ?? '').trim())
                .where((u) => u.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
            availableUsernames = ['All', ...names];
            if (!availableUsernames.contains(selectedUsername)) {
              selectedUsername = 'All';
            }
          }
          _filterOrdersByDate(); // Refresh filtered orders when new data is fetched
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load orders: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error fetching orders: $e'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isLoadingOrders = false;
      });
    }
  }

  Future<void> submitOrder() async {
    if (cart.items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cart is empty!')),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';
      
      // Show payment screen
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            totalAmount: cart.total,
            items: cart.items.map((e) => e.product.toMap()).toList(),
            invoiceNumber: invoiceNumber,
            onPaymentConfirmed: (confirmed, paymentMethod, cashHandler) async {
              if (confirmed) {
                try {
                  // On web, skip explicit isOnline() (may be unreliable due to CORS). Just attempt the request.
                  bool proceed = true;
                  if (!kIsWeb) {
                    final isOnline = await LocalDatabaseService.isOnline();
                    if (!isOnline) {
                      proceed = false;
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ No internet connection. Please check your connection and try again.'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  }
                  if (!proceed) return;

                  // Update stock quantities before creating order data
                  for (var item in cart.items) {
                    final product = products.firstWhere(
                      (p) => p.id == item.product.id,
                      orElse: () => item.product,
                    );
                    product.stock -= item.quantity;
                  }

                  final orderData = {
                    'action': 'submitOrder',
                    'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                    'username': widget.username,
                    'items': cart.items.map((item) => {
                      'id': item.product.id,
                      'name': item.product.name,
                      'quantity': item.quantity,
                      'price': item.product.price,
                      'total': item.total,
                    }).toList(),
                    'totalAmount': cart.total,
                    'paymentMethod': paymentMethod,
                    'cashHandler': cashHandler,
                    'invoiceNumber': invoiceNumber,
                    'status': 'completed',
                    'paymentConfirmed': true,
                  };

                  // Submit order online immediately
                  final uri = Uri.parse(scriptUrl);
                  http.Response response;
                  if (kIsWeb) {
                    response = await http.post(
                      uri,
                      headers: { 'Content-Type': 'text/plain;charset=utf-8' },
                      body: json.encode(orderData),
                    );
                  } else {
                    response = await http.post(
                      uri,
                      headers: { 'Content-Type': 'application/json' },
                      body: json.encode(orderData),
                    );
                  }

                  if (response.statusCode == 200 || response.statusCode == 302) {
                    // Update local database with new stock values
                    await LocalDatabaseService.saveProducts(products);

                    // Clear cart and update UI immediately
                    if (mounted) {
                      setState(() {
                        cart.clear();
                        searchController.clear();
                        _filterProducts(''); // Maintain current category filter instead of showing all products
                      });
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Order completed successfully!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } else {
                    throw Exception('Failed to submit order: ${response.statusCode}');
                  }
                } catch (e) {
                  print('Error in order process: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error processing order: $e'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }
            },
          ),
        ),
      );
    } catch (e) {
      print('Error in payment flow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error in payment flow: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 3 
          ? null  // No app bar for AG section
          : AppBar(
              title: _currentIndex == 1
                  ? Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: searchController,
                        textAlignVertical: TextAlignVertical.center,
                        style: TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: TextStyle(fontSize: 16),
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    searchController.clear();
                                    _filterProducts('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        ),
                        onChanged: _filterProducts,
                      ),
                    )
                  : _currentIndex == 2
                      ? Row(
                          children: [
                            if (isAdmin) ...[
                              Expanded(flex: 10,
                                child: DropdownButtonFormField<String>(
                                  value: availableUsernames.contains(selectedUsername) ? selectedUsername : 'All',
                                  items: availableUsernames.map((u) {
                                    return DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    );
                                  }).toList(),
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    setState(() {
                                      selectedUsername = value;
                                    });
                                    // Refetch orders for selection
                                    await fetchOrders();
                                  },
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    labelText: 'Username',
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(1.0),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  ),
                                  isExpanded: true,
                                ),
                              ),
                              const SizedBox(width: 7),
                            ],
                            Expanded(flex: 9,
                              child: DropdownButtonFormField<String>(
                                value: selectedPaymentMethod ?? 'All',
                                items: ['All', 'Online', 'Cash'].map((method) {
                                  return DropdownMenuItem(
                                    value: method,
                                    child: Text(method),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedPaymentMethod = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  labelText: 'Payment Method',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(1.0),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                ),
                                isExpanded: true,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              flex: 13,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total Amount',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      '₹${visibleOrders.fold<double>(0.0, (sum, order) => sum + ((order['totalAmount'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4A90E2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _getAppBarTitle(),
                          style: TextStyle(color: Colors.white),
                        ),
              backgroundColor: Color(0xFF4A90E2),
              elevation: 2,
              actions: [
                if (_currentIndex == 1)
                  IconButton(
                    icon: Icon(Icons.refresh),
                    tooltip: 'Refresh Items',
                    onPressed: () async {
                      await fetchInventory();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Items refreshed')),
                      );
                    },
                  ),
                if (_currentIndex == 2)
                  IconButton(
                    icon: Icon(Icons.refresh),
                    tooltip: 'Refresh Orders',
                    onPressed: () async {
                      if (kIsWeb) {
                        await fetchOrders();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Orders refreshed'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        if (await LocalDatabaseService.isOnline()) {
                          await fetchOrders();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Orders refreshed'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please check your internet connection'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    },
                  ),
                IconButton(
                  icon: Icon(Icons.logout),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                ),
              ],
            ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Color(0xFF4A90E2),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Items',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Orders',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Items';
      case 2:
        return 'Order Management';
      case 3:
        return 'Akhand Gyan';
      default:
        return 'RetailPro';
    }
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A90E2),
            Color(0xFF67B26F),
            Color(0xFFE6F3FF),
          ],
        ),
      ),
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildInventory();
      case 2:
        return _buildSales();
      case 3:
        return Container();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildInventory() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: availableHSNs.contains(selectedHSN) ? selectedHSN : (availableHSNs.isNotEmpty ? availableHSNs.first : null),
                    items: availableHSNs.map((hsn) {
                      return DropdownMenuItem(
                        value: hsn,
                        child: Text(
                          hsn,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        await _saveSelectedHSN(value);
                        setState(() {
                          selectedHSN = value;
                          _filterProducts(searchController.text);
                        });
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelText: 'Category',
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(top: 8),
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : filteredProducts.isEmpty
                      ? Center(
                          child: Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return _buildProductCard(product);
                          },
                        ),
            ),
          ),
          if (cart.items.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cart.items.length} items',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '₹${cart.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showCart(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4A90E2),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'View Cart',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Shopping Cart',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (cart.items.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_all, color: Colors.red),
                      tooltip: 'Clear Cart',
                      onPressed: () {
                        setState(() {
                          cart.clear();
                        });
                        // Update the parent widget's state
                        if (mounted) {
                          Navigator.pop(context); // Close the cart view
                          setState(() {}); // Trigger rebuild of the parent widget
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cart cleared successfully'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (cart.items.isEmpty)
                const Center(
                  child: Text('Your cart is empty'),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                (index + 1).toString(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A90E2),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            item.product.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '₹${item.product.price.toStringAsFixed(2)} × ${item.quantity} = ₹${item.total.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  setState(() {
                                    final newQuantity = item.quantity - 1;
                                    cart.updateQuantity(item.product.id, newQuantity);
                                    // Update product quantity in the inventory
                                    final product = products.firstWhere(
                                      (p) => p.id == item.product.id,
                                      orElse: () => item.product,
                                    );
                                    product.quantity = newQuantity;
                                  });
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF4A90E2), width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: Text(
                                  item.quantity.toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A90E2),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  setState(() {
                                    final newQuantity = item.quantity + 1;
                                    cart.updateQuantity(item.product.id, newQuantity);
                                    // Update product quantity in the inventory
                                    final product = products.firstWhere(
                                      (p) => p.id == item.product.id,
                                      orElse: () => item.product,
                                    );
                                    product.quantity = newQuantity;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (cart.items.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${cart.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    submitOrder();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Proceed to Payment',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          radius: 25,
                          child: Text(
                            widget.username.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Colors.indigo.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${widget.username}!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                            Text(
                              'Jai Maharaj ji ki 🙏',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Sales Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Today',
                    '₹${salesSummary.todaySales.toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.green,
                    '+12.5%',
                    salesSummary.todayPaymentMethods,
                    salesSummary.cashHandlers[DateTime.now().toString()] ?? [],
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    'This Week',
                    '₹${salesSummary.weekSales.toStringAsFixed(2)}',
                    Icons.trending_down,
                    Colors.red,
                    '-3.8%',
                    salesSummary.weekPaymentMethods,
                    salesSummary.cashHandlers[DateTime.now().subtract(const Duration(days: 7)).toString()] ?? [],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'This Month',
                    '₹${salesSummary.monthSales.toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.green,
                    '+8.2%',
                    salesSummary.monthPaymentMethods,
                    salesSummary.cashHandlers[DateTime.now().subtract(const Duration(days: 30)).toString()] ?? [],
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    'Pending Orders',
                    '${salesSummary.pendingOrders}',
                    null,
                    null,
                    null,
                    null,
                    null,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'New Sale', Icons.add_shopping_cart, Colors.blue),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard(
                    'Add Product', Icons.add_box, Colors.purple),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'View Reports', Icons.bar_chart, Colors.amber.shade700),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _buildActionCard('Manage Staff', Icons.people, Colors.teal),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAdmin && isStockCheckingMode ? 'Stock Checking' : 'Low Stock Alert',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                if (isAdmin)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        isStockCheckingMode = !isStockCheckingMode;
                        if (isStockCheckingMode) {
                          _initializeStockChecking();
                        } else {
                          _clearStockChecking();
                        }
                      });
                    },
                    icon: Icon(
                      isStockCheckingMode ? Icons.inventory_2 : Icons.fact_check,
                      size: 16,
                    ),
                    label: Text(
                      isStockCheckingMode ? 'Exit Check' : 'Stock Check',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isStockCheckingMode ? Colors.red.shade400 : Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size(0, 32),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10),
            isAdmin && isStockCheckingMode ? _buildStockCheckingInterface() : _buildLowStockList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData? trendIcon,
      Color? trendColor, String? trendValue, Map<String, double>? paymentMethods,
      List<String>? cashHandlers) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
            ),
            if (paymentMethods != null) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.payment, size: 16, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Online: ₹${(paymentMethods['online'] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.money, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    'Cash: ₹${(paymentMethods['cash'] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ],
            if (cashHandlers != null && cashHandlers.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'Cash Handlers:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 4),
              ...cashHandlers.map((handler) => Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  '• $handler',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              )),
            ],
            if (trendIcon != null && trendColor != null && trendValue != null)
              Row(
                children: [
                  Icon(trendIcon, color: trendColor, size: 16),
                  SizedBox(width: 4),
                  Text(
                    trendValue,
                    style: TextStyle(
                      color: trendColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title feature coming soon!')),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initializeStockChecking() {
    stockCheckCounts.clear();
    stockCheckControllers.clear();
    
    // Initialize controllers for all products
    for (var product in products) {
      stockCheckControllers[product.id] = TextEditingController();
      stockCheckCounts[product.id] = 0;
    }
  }
  
  void _clearStockChecking() {
    stockCheckCounts.clear();
    for (var controller in stockCheckControllers.values) {
      controller.dispose();
    }
    stockCheckControllers.clear();
  }
  
  Widget _buildStockCheckingInterface() {
    List<Product> filteredProducts = products;
    
    // Filter products based on category if needed
    if (stockCheckFilter == 'Z_Official Only (Stock checking)') {
      filteredProducts = products.where((p) => 
        p.name.toLowerCase().contains('Z_Official Only (Stock checking)') ||
        p.name.toLowerCase().contains('stock checking')
      ).toList();
    } else if (stockCheckFilter == 'pending') {
      filteredProducts = products.where((p) => 
        stockCheckCounts[p.id] != p.stock
      ).toList();
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter and summary row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: stockCheckFilter,
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('All Items (${products.length})')),
                      DropdownMenuItem(value: 'Z_Official Only (Stock checking)', child: Text('Z_Official Only (Stock checking)')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending Checks')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        stockCheckFilter = value ?? 'all';
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _generateStockReport,
                  icon: Icon(Icons.assessment, size: 16),
                  label: Text('Report', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size(0, 36),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Stock checking list
            Container(
              height: 400,
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        'No items to check',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return _buildStockCheckItem(product);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStockCheckItem(Product product) {
    final controller = stockCheckControllers[product.id]!;
    final currentCount = stockCheckCounts[product.id] ?? 0;
    final systemStock = product.stock;
    final difference = currentCount - systemStock;
    
    Color statusColor;
    IconData statusIcon;
    
    if (currentCount == 0) {
      statusColor = Colors.grey;
      statusIcon = Icons.pending;
    } else if (difference == 0) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (difference.abs() <= 2) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Status indicator
            Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
            SizedBox(width: 12),
            // Product name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ProductNameUtils.getDisplayName(product.name),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'System: $systemStock',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            // Count input
            Container(
              width: 80,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  hintText: '0',
                ),
                onChanged: (value) {
                  setState(() {
                    stockCheckCounts[product.id] = int.tryParse(value) ?? 0;
                  });
                },
              ),
            ),
            SizedBox(width: 8),
            // Quick add buttons
            Column(
              children: [
                GestureDetector(
                  onTap: () {
                    final newValue = currentCount + 1;
                    controller.text = newValue.toString();
                    setState(() {
                      stockCheckCounts[product.id] = newValue;
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Icon(Icons.add, size: 14, color: Colors.green.shade700),
                  ),
                ),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    final newValue = math.max(0, currentCount - 1);
                    controller.text = newValue == 0 ? '' : newValue.toString();
                    setState(() {
                      stockCheckCounts[product.id] = newValue;
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Icon(Icons.remove, size: 14, color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
            SizedBox(width: 8),
            // Difference indicator
            Container(
              width: 50,
              child: Text(
                difference == 0 ? '✓' : (difference > 0 ? '+$difference' : '$difference'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _generateStockReport() {
    int totalItems = products.length;
    int checkedItems = stockCheckCounts.values.where((count) => count > 0).length;
    int matchingItems = 0;
    int discrepancies = 0;
    
    for (var product in products) {
      final counted = stockCheckCounts[product.id] ?? 0;
      if (counted > 0) {
        if (counted == product.stock) {
          matchingItems++;
        } else {
          discrepancies++;
        }
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stock Check Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Items: $totalItems'),
            Text('Items Checked: $checkedItems'),
            Text('Matching: $matchingItems', style: TextStyle(color: Colors.green)),
            Text('Discrepancies: $discrepancies', style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            Text('Progress: ${((checkedItems / totalItems) * 100).toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (discrepancies > 0)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showDiscrepancyDetails();
              },
              child: Text('View Details'),
            ),
        ],
      ),
    );
  }
  
  void _showDiscrepancyDetails() {
    final discrepancies = <Product>[];
    
    for (var product in products) {
      final counted = stockCheckCounts[product.id] ?? 0;
      if (counted > 0 && counted != product.stock) {
        discrepancies.add(product);
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stock Discrepancies'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: discrepancies.length,
            itemBuilder: (context, index) {
              final product = discrepancies[index];
              final counted = stockCheckCounts[product.id] ?? 0;
              final difference = counted - product.stock;
              
              return ListTile(
                title: Text(
                  ProductNameUtils.getDisplayName(product.name),
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: Text('System: ${product.stock}, Counted: $counted'),
                trailing: Text(
                  difference > 0 ? '+$difference' : '$difference',
                  style: TextStyle(
                    color: difference > 0 ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockList() {
    final lowStockProducts = products.where((p) => p.stock < 20).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: lowStockProducts.isEmpty
            ? Center(
                child: Text(
                  'No products with low stock',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            : Column(
                children: lowStockProducts.map((product) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              product.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'Stock: ${product.stock} | Qty: ${cart.getQuantity(product.id)}',
                            style: TextStyle(
                              color: product.stock < 15
                                  ? Colors.red
                                  : Colors.amber.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                ).toList(),
              ),
      ),
    );
  }

  Widget _buildSales() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Date Range Selector (Left)
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final initial = dateRange ?? DateTimeRange(
                        start: DateTime.now().subtract(Duration(days: 6)),
                        end: DateTime.now(),
                      );
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: initial,
                        helpText: 'Select Date Range',
                      );
                      if (picked != null) {
                        setState(() {
                          dateRange = picked;
                          startDate = picked.start;
                          endDate = picked.end;
                          _filterOrdersByDate();
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range, size: 18, color: Colors.grey.shade700),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (dateRange != null)
                                ? '${DateFormat('dd MMM yyyy').format(dateRange!.start)}  -  ${DateFormat('dd MMM yyyy').format(dateRange!.end)}'
                                : 'Select Date Range',
                              style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dateRange != null)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  dateRange = null;
                                  startDate = null;
                                  endDate = null;
                                  _filterOrdersByDate();
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.0),
                                child: Icon(Icons.clear, size: 18, color: Colors.grey.shade600),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Export Icon Button (Right)
                IconButton(
                  onPressed: () => _showExportOptions(),
                  icon: Icon(Icons.download, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Color(0xFF4A90E2),
                    padding: EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  tooltip: 'Export',
                ),
              ],
            ),
          ),
          if (dateRange != null || startDate != null || endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Showing ${visibleOrders.length} of ${userOrders.length} orders',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Expanded(
            child: isLoadingOrders
                ? const Center(child: CircularProgressIndicator())
                : visibleOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              userOrders.isEmpty 
                                ? 'No orders found'
                                : 'No orders found for selected filters',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            if (userOrders.isNotEmpty && visibleOrders.isEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleOrders.length,
                        itemBuilder: (context, index) {
                          final order = visibleOrders[index];
                          
                          // Parse items from the status field
                          List<dynamic> items = [];
                          try {
                            if (order['status'] is String) {
                              items = json.decode(order['status']);
                            } else if (order['items'] is List) {
                              items = order['items'];
                            }
                          } catch (e) {
                            print('Error parsing items: $e');
                          }

                          String itemsPreview = items.take(2).map((item) => ProductNameUtils.getItemDisplayName(item)).join(', ');
                          if (items.length > 2) {
                            itemsPreview += ' +${items.length - 2} more';
                          }

                          // Get payment method
                          String paymentMethod = order['paymentMethod']?.toString() ?? 'N/A';
                          if (paymentMethod.toLowerCase() == 'cash') {
                            paymentMethod = 'Cash';
                          } else if (paymentMethod.toLowerCase() == 'online') {
                            paymentMethod = 'Online';
                          }

                          // Get cash handler
                          String cashHandler = order['cashHandler']?.toString() ?? 'N/A';

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ExpansionTile(
                              childrenPadding: EdgeInsets.zero,
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Order #${order['invoiceNumber'] ?? order['id'] ?? 'N/A'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '₹${((order['totalAmount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    itemsPreview,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                order['date'] ?? 'N/A',
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Order'),
                                      content: const Text('Are you sure you want to delete this order? This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteOrder(order);
                                          },
                                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(10),
                                      bottomRight: Radius.circular(10),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order Items:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.indigo.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ...items.map((item) =>
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ProductNameUtils.getItemDisplayName(item),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                    left: 12.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Qty: ${item['quantity'] ?? 0}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey.shade600,
                                                        ),
                                                      ),
                                                      Text(
                                                        '₹${item['price'] ??
                                                            0} × ${item['quantity'] ??
                                                            0} = ₹${item['total'] ??
                                                            0}',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Divider(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ],
                                            )),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Total Amount:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              '₹${((order['totalAmount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.indigo.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Payment Method:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              paymentMethod,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Cash Handler:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              cashHandler,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Status:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Completed',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export Sales Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Initial Cash in Box',
                hintText: 'Enter Initial cash amount in box',
                prefixText: '₹',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _cashInBox = double.tryParse(value) ?? 0;
              },
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
            ListTile(
              leading: Icon(Icons.table_chart, color: Colors.green),
              title: Text('Export as Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
          ],
        ),
      ),
    );
  }

  double _cashInBox = 0;

  Future<void> _exportToExcel() async {
    try {
      setState(() => isLoading = true);

      // Create Excel document
      var excelDoc = excel.Excel.createExcel();
      
      // Create three sheets
      var detailedSheet = excelDoc.sheets.values.first;
      var summarySheet = excelDoc.sheets[excelDoc.sheets.keys.elementAt(0)]!;
      var itemSummarySheet = excelDoc.sheets[excelDoc.sheets.keys.elementAt(0)]!;

      // Add headers to detailed sheet
      detailedSheet.appendRow([
        'Date',
        'Username',
        'Payment Method',
        'Items',
        'HSN',
        'Quantity',
        'Rate',
        'Amount',
        'Cash Handler',
        'Invoice Number'
      ]);

      // Use currently filtered orders and selected payment method
      List<dynamic> sourceOrders = List<dynamic>.from(filteredOrders);
      if ((selectedPaymentMethod ?? 'All') != 'All') {
        final sel = (selectedPaymentMethod ?? 'All').toLowerCase();
        sourceOrders = sourceOrders.where((order) =>
          (order['paymentMethod']?.toString().toLowerCase() ?? 'cash') == sel
        ).toList();
      }
      // Group by payment method
      final cashOrders = sourceOrders.where((order) => 
        (order['paymentMethod']?.toString().toLowerCase() ?? 'cash') == 'cash').toList();
      final onlineOrders = sourceOrders.where((order) => 
        (order['paymentMethod']?.toString().toLowerCase() ?? 'cash') == 'online').toList();

      double totalCash = 0;
      double totalOnline = 0;

      // Add cash orders section
      detailedSheet.appendRow(['Cash Sales']);
      detailedSheet.appendRow([]); // Empty row for spacing

      // Add cash orders
      for (var order in cashOrders) {
        List<dynamic> items = [];
        try {
          if (order['status'] is String) {
            items = json.decode(order['status']);
          } else if (order['items'] is List) {
            items = order['items'];
          }
        } catch (e) {
          print('Error parsing items: $e');
          continue;
        }

        for (var item in items) {
          final amount = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
          totalCash += amount;
          
          detailedSheet.appendRow([
            order['date']?.toString() ?? '',
            order['username']?.toString() ?? '',
            'Cash',
            item['name']?.toString() ?? '',
            item['hsn']?.toString() ?? '',
            item['quantity']?.toString() ?? '0',
            item['price']?.toString() ?? '0',
            amount.toString(),
            order['cashHandler']?.toString() ?? '',
            order['invoiceNumber']?.toString() ?? '',
          ]);
        }
      }

      // Add spacing after cash orders
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow(['Total Cash Sales', '', '', '', '', '', '', totalCash.toString()]);
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row

      // Add online orders section
      detailedSheet.appendRow(['Online Sales']);
      detailedSheet.appendRow([]); // Empty row for spacing

      // Add online orders
      for (var order in onlineOrders) {
        List<dynamic> items = [];
        try {
          if (order['status'] is String) {
            items = json.decode(order['status']);
          } else if (order['items'] is List) {
            items = order['items'];
          }
        } catch (e) {
          print('Error parsing items: $e');
          continue;
        }

        for (var item in items) {
          final amount = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
          totalOnline += amount;
          
          detailedSheet.appendRow([
            order['date']?.toString() ?? '',
            order['username']?.toString() ?? '',
            'Online',
            item['name']?.toString() ?? '',
            item['hsn']?.toString() ?? '',
            item['quantity']?.toString() ?? '0',
            item['price']?.toString() ?? '0',
            amount.toString(),
            '',
            order['invoiceNumber']?.toString() ?? '',
          ]);
        }
      }

      // Add spacing and totals after online orders
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow(['Total Online Sales', '', '', '', '', '', '', totalOnline.toString()]);
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow(['Grand Total', '', '', '', '', '', '', (totalCash + totalOnline).toString()]);
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow(['Cash in Box', '', '', '', '', '', '', _cashInBox.toString()]);
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow([]); // Empty row

      // Add item-wise summary section
      detailedSheet.appendRow(['Item-wise Summary']);
      detailedSheet.appendRow([]); // Empty row for spacing

      // Add headers for item summary
      detailedSheet.appendRow([
        'Item Name',
        'HSN',
        'Total Quantity',
        'Rate',
        'Total Amount'
      ]);

      // Create item-wise summary (respect current filters)
      Map<String, Map<String, dynamic>> itemSummary = {};
      for (var order in sourceOrders) {
        List<dynamic> items = [];
        try {
          if (order['status'] is String) {
            items = json.decode(order['status']);
          } else if (order['items'] is List) {
            items = order['items'];
          }
        } catch (e) {
          continue;
        }

        for (var item in items) {
          final name = item['name']?.toString() ?? '';
          if (!itemSummary.containsKey(name)) {
            itemSummary[name] = {
              'hsn': item['hsn']?.toString() ?? '',
              'quantity': 0,
              'rate': item['price']?.toString() ?? '0',
              'amount': 0.0,
            };
          }
          itemSummary[name]!['quantity'] += int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
          itemSummary[name]!['amount'] += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
        }
      }

      // Add item summary data
      double grandTotal = 0;
      for (var entry in itemSummary.entries) {
        detailedSheet.appendRow([
          entry.key,
          entry.value['hsn'],
          entry.value['quantity'].toString(),
          entry.value['rate'],
          entry.value['amount'].toString(),
        ]);
        grandTotal += entry.value['amount'];
      }

      // Add grand total to item summary
      detailedSheet.appendRow([]); // Empty row
      detailedSheet.appendRow(['Grand Total', '', '', '', grandTotal.toString()]);

      // Save Excel file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/sales_report.xlsx');
      await file.writeAsBytes(excelDoc.encode()!);

      // Share Excel file
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Report');

    } catch (e) {
      print('Error generating Excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating Excel: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _exportToPDF() async {
    try {
      setState(() => isLoading = true);

      // Use currently filtered orders and selected payment method
      List<dynamic> sourceOrders = List<dynamic>.from(filteredOrders);
      if ((selectedPaymentMethod ?? 'All') != 'All') {
        final sel = (selectedPaymentMethod ?? 'All').toLowerCase();
        sourceOrders = sourceOrders.where((order) =>
          (order['paymentMethod']?.toString().toLowerCase() ?? 'cash') == sel
        ).toList();
      }
      // Group by payment method
      final cashOrders = sourceOrders.where((order) => 
        (order['paymentMethod']?.toString().toLowerCase() ?? 'cash') == 'cash').toList();
      final onlineOrders = sourceOrders.where((order) => 
        (order['paymentMethod']?.toString().toLowerCase() ?? 'cash') == 'online').toList();

      // Create PDF document
      final pdf = pw.Document();

      // Add title page with sales details
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: 0.5 * PdfPageFormat.cm,
            marginRight: 0.5 * PdfPageFormat.cm,
            marginTop: 0.5 * PdfPageFormat.cm,
            marginBottom: 0.5 * PdfPageFormat.cm,
          ),
          build: (context) => [
            // Header with gradient-like effect
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [
                    PdfColor.fromHex('#1e3a8a'), // Deep blue
                    PdfColor.fromHex('#3b82f6'), // Bright blue
                  ],
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'SALES REPORT',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 25),

            // Info section with subtle background
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#f8fafc'), // Light gray
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#e2e8f0')),
              ),
              child: pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
                style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#475569')),
              ),
            ),
            pw.SizedBox(height: 25),

            // Cash Sales Section
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#059669'), // Emerald green
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'CASH SALES',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            _buildDetailedSalesTable(cashOrders, PdfColor.fromHex('#d1fae5')), // Light green
            pw.SizedBox(height: 25),

            // Online Sales Section
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#7c3aed'), // Purple
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'ONLINE SALES',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            _buildDetailedSalesTable(onlineOrders, PdfColor.fromHex('#ede9fe')), // Light purple
          ],
        ),
      );

      // Add summary and cash summary page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            // Summary Header
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [
                    PdfColor.fromHex('#dc2626'), // Red
                    PdfColor.fromHex('#f97316'), // Orange
                  ],
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'SUMMARY',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 25),
            _buildSummaryTable(cashOrders, onlineOrders),
            pw.SizedBox(height: 25),

            // Cash Summary Section
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#059669'), // Emerald green
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'CASH SUMMARY',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            _buildCashSummaryTable(cashOrders),
          ],
        ),
      );

      // Add item-wise summary page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            // Item Summary Header
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [
                    PdfColor.fromHex('#0f766e'), // Teal
                    PdfColor.fromHex('#14b8a6'), // Light teal
                  ],
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'ITEM-WISE SUMMARY',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 25),
            _buildItemSummaryTable(sourceOrders),
          ],
        ),
      );

      // Save PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/sales_report.pdf');
      await file.writeAsBytes(await pdf.save());

      // Share PDF
      await Share.shareXFiles([XFile(file.path)], text: 'Sales Report');

    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  pw.Table _buildDetailedSalesTable(List<dynamic> orders, PdfColor headerColor) {
    double total = 0;
    final rows = orders.expand((order) {
      List<dynamic> items = [];
      try {
        if (order['status'] is String) {
          items = json.decode(order['status']);
        } else if (order['items'] is List) {
          items = order['items'];
        }
      } catch (e) {
        print('Error parsing items: $e');
        return [];
      }

      return items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final amount = double.tryParse(item['total']?.toString() ?? '0') ?? 0;
        total += amount;

        // Alternate row colors
        final isEven = index % 2 == 0;
        final rowColor = isEven ? PdfColors.white : PdfColor.fromHex('#f8fafc');

        return pw.TableRow(
          decoration: pw.BoxDecoration(color: rowColor),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(6),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  order['date']?.toString() ?? '',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#374151')),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(6),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  order['invoiceNumber']?.toString() ?? '',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(color: PdfColor.fromHex('#374151')),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(6),
              child: pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  item['name']?.toString() ?? '',
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(color: PdfColor.fromHex('#374151')),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(6),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  item['hsn']?.toString() ?? '',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(color: PdfColor.fromHex('#374151')),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(6),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  item['quantity']?.toString() ?? '0',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(color: PdfColor.fromHex('#374151')),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(6),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  item['price']?.toString() ?? '0',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(color: PdfColor.fromHex('#374151')),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(6),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Rs. ${amount.toStringAsFixed(2)}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#059669'),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      });
    }).toList();

    // Add total row with strong styling
    rows.add(pw.TableRow(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [
            PdfColor.fromHex('#1f2937'),
            PdfColor.fromHex('#374151'),
          ],
        ),
      ),
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'TOTAL',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 12,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('')),
        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('')),
        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('')),
        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('')),
        pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text('')),
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Rs. ${total.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 12,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#d1d5db'), width: 0.5),
      columnWidths: {
        0: pw.FixedColumnWidth(134),
        1: pw.FixedColumnWidth(40),
        2: pw.FixedColumnWidth(214),
        3: pw.FixedColumnWidth(40),
        4: pw.FixedColumnWidth(60),
        5: pw.FixedColumnWidth(80),
        6: pw.FixedColumnWidth(100),
      },
      children: [
        // Header row with gradient
        pw.TableRow(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [headerColor, PdfColor.fromHex('#ffffff')],
            ),
          ),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Date',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1f2937'),
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Inv',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1f2937'),
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Item',
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1f2937'),
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'HSN',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1f2937'),
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Qty',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1f2937'),
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Rate',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1f2937'),
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Amount',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1f2937'),
                  ),
                ),
              ),
            ),
          ],
        ),
        ...rows,
      ],
    );
  }

  pw.Table _buildSummaryTable(List<dynamic> cashOrders, List<dynamic> onlineOrders) {
    double totalCash = 0;
    double totalOnline = 0;

    // Calculate totals
    for (var order in cashOrders) {
      List<dynamic> items = [];
      try {
        if (order['status'] is String) {
          items = json.decode(order['status']);
        } else if (order['items'] is List) {
          items = order['items'];
        }
      } catch (e) {
        continue;
      }

      for (var item in items) {
        totalCash += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
      }
    }

    for (var order in onlineOrders) {
      List<dynamic> items = [];
      try {
        if (order['status'] is String) {
          items = json.decode(order['status']);
        } else if (order['items'] is List) {
          items = order['items'];
        }
      } catch (e) {
        continue;
      }

      for (var item in items) {
        totalOnline += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#d1d5db'), width: 0.5),
      children: [
        // Cash Sales Row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#d1fae5'), // Light green
                PdfColors.white,
              ],
            ),
          ),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Total Cash Sales',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#059669'),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Rs. ${totalCash.toInt()}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#059669'),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Online Sales Row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#ede9fe'), // Light purple
                PdfColors.white,
              ],
            ),
          ),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Total Online Sales',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#7c3aed'),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Rs. ${totalOnline.toInt()}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#7c3aed'),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Grand Total Row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#1f2937'),
                PdfColor.fromHex('#374151'),
              ],
            ),
          ),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(15),
              child: pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'GRAND TOTAL',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(15),
              child: pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Rs. ${(totalCash + totalOnline).toInt()}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Spacer rows with subtle styling
        ...List.generate(5, (index) => pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#fafafa'),
            border: pw.Border.all(color: PdfColor.fromHex('#f3f4f6')),
          ),
          children: [
            pw.Container(height: 20, child: pw.Text('')),
            pw.Container(height: 20, child: pw.Text('')),
          ],
        )),
      ],
    );
  }

  pw.Table _buildItemSummaryTable(List<dynamic> orders) {
    // Create a map to store item-wise totals
    Map<String, Map<String, dynamic>> itemSummary = {};
    double grandTotal = 0;

    // Process all orders for item summary
    for (var order in orders) {
      List<dynamic> items = [];
      try {
        if (order['status'] is String) {
          items = json.decode(order['status']);
        } else if (order['items'] is List) {
          items = order['items'];
        }
      } catch (e) {
        continue;
      }

      for (var item in items) {
        final name = item['name']?.toString() ?? '';
        final hsn = item['hsn']?.toString() ?? '';
        final quantity = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        final rate = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
        final amount = double.tryParse(item['total']?.toString() ?? '0') ?? 0;

        if (!itemSummary.containsKey(name)) {
          itemSummary[name] = {
            'hsn': hsn,
            'quantity': 0,
            'rate': rate,
            'amount': 0,
          };
        }

        itemSummary[name]!['quantity'] += quantity;
        itemSummary[name]!['amount'] += amount;
        grandTotal += amount;
      }
    }

    final rows = itemSummary.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isEven = index % 2 == 0;
      final rowColor = isEven ? PdfColors.white : PdfColor.fromHex('#f8fafc');

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: rowColor),
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Container(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                item.key,
                style: pw.TextStyle(color: PdfColor.fromHex('#374151')),
              ),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Text(
                item.value['hsn'],
                style: pw.TextStyle(color: PdfColor.fromHex('#374151')),
              ),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Text(
                item.value['quantity'].toString(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#0f766e'),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Text(
                item.value['rate'].toInt().toString(),
                style: pw.TextStyle(color: PdfColor.fromHex('#374151')),
              ),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Rs. ${item.value['amount'].toInt()}',
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#059669'),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ].cast<pw.Widget>(),
      );
    }).toList();

    // Add grand total row
    rows.add(pw.TableRow(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [
            PdfColor.fromHex('#1f2937'),
            PdfColor.fromHex('#374151'),
          ],
        ),
      ),
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(12),
          child: pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Rs. ${grandTotal.toInt()}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#d1d5db'), width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#0f766e'), // Teal
                PdfColor.fromHex('#5eead4'), // Light teal
              ],
            ),
          ),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(10),
              child: pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Item Name',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(10),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'HSN',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(10),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Total Quantity',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(10),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Rate',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(10),
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Total Amount',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        ...rows,
      ],
    );
  }

  pw.Table _buildCashSummaryTable(List<dynamic> orders) {
    double totalCash = 0;
    for (var order in orders) {
      List<dynamic> items = [];
      try {
        if (order['status'] is String) {
          items = json.decode(order['status']);
        } else if (order['items'] is List) {
          items = order['items'];
        }
      } catch (e) {
        continue;
      }

      for (var item in items) {
        totalCash += double.tryParse(item['total']?.toString() ?? '0') ?? 0;
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#d1d5db'), width: 0.5),
      children: [
        // Initial Cash Row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#fef3c7'), // Light yellow
                PdfColors.white,
              ],
            ),
          ),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Initial Cash in Box',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#d97706'),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Rs. ${_cashInBox.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#d97706'),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Cash Sales Row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#d1fae5'), // Light green
                PdfColors.white,
              ],
            ),
          ),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Total Cash Sales',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#059669'),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(12),
              child: pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Rs. ${totalCash.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#059669'),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Total Cash Row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [
                PdfColor.fromHex('#1f2937'),
                PdfColor.fromHex('#374151'),
              ],
            ),
          ),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(15),
              child: pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'TOTAL CASH IN BOX',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(15),
              child: pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Rs. ${(_cashInBox + totalCash).toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomers() {
    final customers = [
      {
        'id': 'C001',
        'name': 'John Doe',
        'email': 'john.doe@example.com',
        'purchases': 12,
        'totalSpent': 845.75
      },
      {
        'id': 'C002',
        'name': 'Emily White',
        'email': 'emily.white@example.com',
        'purchases': 8,
        'totalSpent': 623.50
      },
      {
        'id': 'C003',
        'name': 'Michael Brown',
        'email': 'michael.brown@example.com',
        'purchases': 15,
        'totalSpent': 1250.25
      },
      {
        'id': 'C004',
        'name': 'Sarah Davis',
        'email': 'sarah.davis@example.com',
        'purchases': 5,
        'totalSpent': 345.90
      },
      {
        'id': 'C005',
        'name': 'David Wilson',
        'email': 'david.wilson@example.com',
        'purchases': 10,
        'totalSpent': 780.30
      },
    ];

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Total Customers: ${customers.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                return Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        (customer['name'] as String)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      customer['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(customer['email'] as String),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Purchases: ${customer['purchases']}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '₹${(customer['totalSpent'] as double)
                              .toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('View customer details coming soon!'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final currentQuantity = cart.getQuantity(product.id);
    print('Building product card for: ${product.name}, current quantity: $currentQuantity, product quantity: ${product.quantity}');
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildProductImage(product),
                ),
                SizedBox(height: 4),
                Container(
                  width: 140,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _showIncreaseStockDialog(product),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.add_box, size: 20, color: Colors.green.shade700),
                            ),
                          ),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showDecreaseStockDialog(product),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.remove_circle, size: 20, color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Stock: ${product.stock}',
                            style: TextStyle(
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            ' | ',
                            style: TextStyle(
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Qty: ${product.quantity}',
                            style: TextStyle(
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(width: 8), // Increased from 5
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo.shade900),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10),
                  Text(
                    '₹${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Color(0xFF4A90E2),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, color: Colors.indigo.shade700),
                        onPressed: () {
                          print('Decreasing quantity for: ${product.name}');
                          final newQuantity = currentQuantity - 1;
                          setState(() {
                            cart.addProduct(product, newQuantity);
                          });
                        },
                        iconSize: 25,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF4A90E2), width: 2),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Text(
                          currentQuantity.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                      SizedBox(width: 2),
                      IconButton(
                        icon: Icon(Icons.add, color: Colors.indigo.shade700),
                        onPressed: () {
                          print('Increasing quantity for: ${product.name}');
                          final newQuantity = currentQuantity + 1;
                          if (newQuantity <= product.stock) {
                            setState(() {
                              cart.addProduct(product, newQuantity);
                            });
                          }
                        },
                        iconSize: 25,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future _deleteOrder(Map order) async {
    final orderId = order['invoiceNumber'] ?? order['id'];
    
    // On web, skip explicit isOnline() (may be unreliable due to CORS). Just attempt the request.
    if (!kIsWeb) {
      if (!await LocalDatabaseService.isOnline()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ No internet connection. Please check your connection and try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // Remove from local list instantly
    final oldOrders = List<Map>.from(userOrders);
    setState(() {
      userOrders.removeWhere((o) => (o['invoiceNumber'] ?? o['id']) == orderId);
    });
    
    try {
      final uri = Uri.parse(scriptUrl);
      http.Response response;
      final payload = json.encode({
        'action': 'deleteOrder',
        'invoiceNumber': orderId,
      });
      if (kIsWeb) {
        response = await http.post(
          uri,
          headers: { 'Content-Type': 'text/plain;charset=utf-8' },
          body: payload,
        );
      } else {
        response = await http.post(
          uri,
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
          body: payload,
        );
      }
      
      if (!(response.statusCode == 200 || response.statusCode == 302)) {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Revert UI change on error
      setState(() {
        userOrders = oldOrders;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add this function to show the dialog and handle stock increase
  void _showIncreaseStockDialog(Product product) {
    final TextEditingController qtyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Increase Stock for ${product.displayName}'),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity to add',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyController.text.trim() ?? '');
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Enter a valid quantity.')),
                );
                return;
              }
              Navigator.pop(context);
              await _increaseStock(product, qty);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  // Add this function to handle the API call and local update
  Future<void> _increaseStock(Product product, int qty) async {
    final oldStock = product.stock;
    final oldQty = product.quantity;
    setState(() {
      product.stock += qty;
      product.quantity += qty;
    });
    try {
      await LocalDatabaseService.saveProducts(products);
      final response = await http.post(
        Uri.parse(scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'action': 'increaseStock',
          'productId': product.id,
          'quantity': qty,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 302) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock increased successfully!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        product.stock = oldStock;
        product.quantity = oldQty;
      });
      await LocalDatabaseService.saveProducts(products);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error increasing stock: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Add this function to show the decrease stock dialog
  void _showDecreaseStockDialog(Product product) {
    final TextEditingController qtyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Decrease Stock for ${product.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity to remove',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Current stock: ${product.stock}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(qtyController.text.trim() ?? '');
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Enter a valid quantity.')),
                );
                return;
              }
              if (qty > product.stock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cannot remove more than current stock.')),
                );
                return;
              }
              Navigator.pop(context);
              await _decreaseStock(product, qty);
            },
            child: Text('Remove'),
          ),
        ],
      ),
    );
  }

  // Add this function to handle the decrease stock API call
  Future<void> _decreaseStock(Product product, int qty) async {
    final oldStock = product.stock;
    final oldQty = product.quantity;
    setState(() {
      product.stock -= qty;
      product.quantity -= qty;
    });
    try {
      await LocalDatabaseService.saveProducts(products);
      final response = await http.post(
        Uri.parse(scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'action': 'decreaseStock',
          'productId': product.id,
          'quantity': qty,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 302) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock decreased successfully!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        product.stock = oldStock;
        product.quantity = oldQty;
      });
      await LocalDatabaseService.saveProducts(products);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error decreasing stock: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Helper method to build product image with fallback options
  Widget _buildProductImage(Product product) {
    return Image.asset(
      'assets/images/${product.imageName}.jpg',
      width: 140,
      height: 140,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        print('Error loading product image for ${product.name}: assets/images/${product.imageName}.jpg');
        
        // If the product has 3-letter brackets, try the original name as fallback
        if (product.hasBrackets) {
          print('Trying original name as fallback: assets/images/${product.name}.jpg');
          return Image.asset(
            'assets/images/${product.name}.jpg',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
            errorBuilder: (context, error2, stackTrace2) {
              print('Error loading fallback image for ${product.name}: assets/images/${product.name}.jpg');
              return Image.asset(
                'assets/images/djf_logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              );
            },
          );
        }
        
        // If no brackets, just show the default logo
        return Image.asset(
          'assets/images/djf_logo.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        );
      },
    );
  }
}

class LocalDatabaseService {
  static Database? _database;
  static SharedPreferences? _prefs;
  
  static Future<Database> get database async {
    if (_database != null) return _database!;
    
    if (kIsWeb) {
      // For web, we'll use IndexedDB through sqflite's web implementation
      // No need to initialize FFI or set databaseFactory
      _database = await _initDatabase();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // For desktop, use the FFI implementation we already set up in main()
      _database = await _initDatabase();
    } else {
      // For mobile, use the default implementation
      _database = await _initDatabase();
    }
    
    return _database!;
  }

  static Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Check if we're online
  static Future<bool> isOnline() async {
    try {
      // For web, we can use a simple HTTP request to check connectivity
      final response = await http.get(
        Uri.parse('https://www.google.com/generate_204'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      // If the above fails, try a different approach for non-web platforms
      if (!kIsWeb) {
        try {
          final result = await InternetAddress.lookup('google.com');
          return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } catch (_) {
          return false;
        }
      }
      return false;
    }
  }

  static Future<Database> _initDatabase() async {
    String path;
    int version = 2;
    
    if (kIsWeb) {
      // For web, use IndexedDB with a simple name
      path = 'retail_app_web.db';
    } else {
      // For mobile/desktop, use the standard path
      final dbPath = await getDatabasesPath();
      path = path_lib.join(dbPath, 'retail_app.db');
    }
    
    return await openDatabase(
      path,
      version: version,
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
      final productsJson = products.map((p) => json.encode(p.toMap())).toList();
      await prefs.setStringList('products', productsJson);
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
        return Product.fromMap(map);
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
        quantity: int.tryParse(map['Qty']?.toString() ?? '0') ?? 0,
        imageUrl: map['imageUrl']?.toString(),
        subNames: map['subNames'] != null 
            ? List<String>.from(json.decode(map['subNames']))
            : [],
      );
    });
  }
}
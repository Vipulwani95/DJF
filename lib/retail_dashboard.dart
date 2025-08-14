class RetailDashboard extends StatefulWidget {
  final String username;

  const RetailDashboard({
    super.key,
    required this.username,
  });

  @override
  State<RetailDashboard> createState() => _RetailDashboardState();
}

class _RetailDashboardState extends State<RetailDashboard> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const InventorySection(),
    const OrdersSection(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedIndex == 0) {
                // Refresh Inventory section
                (_pages[0] as InventorySection).key?.currentState?.fetchInventory();
              } else if (_selectedIndex == 1) {
                // Refresh Orders section
                (_pages[1] as OrdersSection).key?.currentState?.fetchOrders();
              }
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Orders',
          ),
        ],
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:stockwatcher/widgets/stock_list_item.dart';
import 'package:stockwatcher/models/stock.dart';
import 'package:stockwatcher/services/api.dart';
import 'package:stockwatcher/screens/watchlist_detail_screen.dart';
import 'package:stockwatcher/services/firebase_service.dart';
import 'package:stockwatcher/screens/stock_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lists'),
        elevation: 0,
      ),
      body: const WatchlistView(),
    );
  }
}

class WatchlistView extends StatefulWidget {
  const WatchlistView({super.key});

  @override
  State<WatchlistView> createState() => _WatchlistViewState();
}

class _WatchlistViewState extends State<WatchlistView> {
  final ApiService _apiService = ApiService();
  final FirebaseService _firebaseService = FirebaseService();
  List<Stock> _stocks = [];
  bool _isLoading = true;
  bool _isExpanded = true;
  Timer? _refreshTimer;

  final double _folderIconSize = 32.0;
  final Color _folderIconColor = Colors.blue[700]!;
  String _folderTitle = 'My Watchlist';
  IconData _folderIcon = Icons.folder;
  static const String defaultFolderId = 'default';

  final TextEditingController _newListTitleController = TextEditingController();
  IconData _selectedIcon = Icons.folder;
  final List<IconData> _availableIcons = [
    Icons.folder,
    Icons.work,
    Icons.star,
    Icons.favorite,
    Icons.bookmark,
    Icons.label,
  ];

  List<QueryDocumentSnapshot> _folders = [];
  final Map<String, List<Stock>> _folderStocks = {};
  final Map<String, bool> _expandedFolders = {};

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _loadFolderPreferences();
    _loadStocksWithPrices();
    // Start auto-refresh timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isExpanded && !_isLoading) {
        _fetchStockPrices();
      }
    });
  }

  @override
  void dispose() {
    _newListTitleController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadFolders() {
    _firebaseService.getAllWatchlistFolders().listen((snapshot) {
      setState(() => _folders = snapshot.docs);
      // Load stocks for each folder
      for (var folder in snapshot.docs) {
        _loadFolderStocks(folder.id);
      }
    });
  }

  void _loadFolderPreferences() {
    _firebaseService.getWatchlistFolder(defaultFolderId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _folderTitle = data['title'] ?? 'My Watchlist';
          // Parse icon code point more reliably
          final iconCode =
              int.tryParse(data['iconName'] ?? '') ?? Icons.folder.codePoint;
          _folderIcon = IconData(iconCode, fontFamily: 'MaterialIcons');
        });
      }
    });
  }

  void _loadStocksWithPrices() {
    _firebaseService.getWatchlistStocks(defaultFolderId).listen((snapshot) {
      final stocks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Stock(
          symbol: data['symbol'],
          name: data['name'],
        );
      }).toList();

      setState(() => _stocks = stocks);
      if (stocks.isNotEmpty) {
        _fetchStockPrices();
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  void _loadFolderStocks(String folderId) {
    _firebaseService.getWatchlistStocksByFolderId(folderId).listen((snapshot) {
      final stocks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Stock(
          symbol: data['symbol'],
          name: data['name'],
        );
      }).toList();

      setState(() {
        _folderStocks[folderId] = stocks;
      });

      // Update stock prices
      if (stocks.isNotEmpty) {
        _updateStockPrices(stocks);
      }
    });
  }

  Future<void> _fetchStockPrices() async {
    if (_stocks.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      for (var stock in _stocks) {
        final quote = await _apiService.getStockQuote(stock.symbol);
        if (!mounted) return;
        setState(() {
          stock.price = quote.currentPrice;
          stock.priceChange = quote.percentChange;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching stock prices: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStockPrices(List<Stock> stocks) async {
    try {
      for (var stock in stocks) {
        final quote = await _apiService.getStockQuote(stock.symbol);
        if (!mounted) return;
        setState(() {
          stock.price = quote.currentPrice;
          stock.priceChange = quote.percentChange;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _handleFolderUpdate(String newTitle, IconData newIcon) {
    setState(() {
      _folderTitle = newTitle;
      _folderIcon = newIcon;
    });
  }

  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchlistDetailScreen(
          title: _folderTitle,
          stocks: _stocks,
          folderId: defaultFolderId,
          folderIcon: _folderIcon, // Pass the current icon
          onFolderUpdated: _handleFolderUpdate,
        ),
      ),
    );
  }

  void _showCreateListBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create new list',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: _showIconPicker,
              child: Column(
                children: [
                  Container(
                    width: 80, // Fixed square size
                    height: 80, // Fixed square size
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Icon(
                      _selectedIcon,
                      color: Colors.blue[700],
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose icon',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _newListTitleController,
              decoration: InputDecoration(
                hintText: 'List name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4), // More square corners
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.blue[400]!),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_newListTitleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a list name')),
                    );
                    return;
                  }
                  await _createNewWatchlist();
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Create'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Icon',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _availableIcons
                    .map((icon) => InkWell(
                          onTap: () {
                            setState(() => _selectedIcon = icon);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: icon == _selectedIcon
                                  ? Colors.blue[50]
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: icon == _selectedIcon
                                    ? Colors.blue
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: icon == _selectedIcon
                                  ? Colors.blue
                                  : Colors.grey[600],
                              size: 32,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewWatchlist() async {
    try {
      final newWatchlist = {
        'title': _newListTitleController.text.trim(),
        'iconName': _selectedIcon.codePoint.toString(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firebaseService.createWatchlistFolder(newWatchlist);

      _newListTitleController.clear();
      _selectedIcon = Icons.folder;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watchlist created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating watchlist: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lists',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _showCreateListBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.green, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Create a new watchlist',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _folders.length,
          itemBuilder: (context, index) {
            final folder = _folders[index];
            final data = folder.data() as Map<String, dynamic>;
            final iconCode =
                int.tryParse(data['iconName'] ?? '') ?? Icons.folder.codePoint;
            final folderIcon = IconData(iconCode, fontFamily: 'MaterialIcons');
            final stocks = _folderStocks[folder.id] ?? [];
            final isExpanded = _expandedFolders[folder.id] ?? false;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WatchlistDetailScreen(
                                title: data['title'] ?? 'Untitled',
                                stocks: stocks,
                                folderId: folder.id,
                                folderIcon: folderIcon,
                                onFolderUpdated: (_, __) {},
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Icon(folderIcon,
                                      color: Colors.blue[700], size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['title'] ?? 'Untitled',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${stocks.length} items',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedFolders[folder.id] = !isExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ClipRRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        height: isExpanded ? null : 0,
                        child: Column(
                          children: [
                            if (isExpanded && stocks.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: stocks.length,
                                itemBuilder: (context, stockIndex) {
                                  final stock = stocks[stockIndex];
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 12,
                                      bottom: 4,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: StockListItem(
                                        symbol: stock.symbol,
                                        companyName: stock.name,
                                        price: stock.price ?? 0.0,
                                        priceChange: stock.priceChange ?? 0.0,
                                        isLoading: false,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                StockDetailScreen(stock: stock),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

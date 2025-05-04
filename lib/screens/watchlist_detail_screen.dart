import 'package:flutter/material.dart';
import 'package:stockwatcher/models/stock.dart';
import 'package:stockwatcher/widgets/stock_list_item.dart';
import 'package:stockwatcher/services/firebase_service.dart';
import 'package:stockwatcher/screens/stock_search_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stockwatcher/services/api.dart';
import 'package:stockwatcher/screens/stock_detail_screen.dart';

class WatchlistDetailScreen extends StatefulWidget {
  final String title;
  final List<Stock> stocks;
  final String folderId;
  final Function(String, IconData) onFolderUpdated;
  final IconData folderIcon;

  const WatchlistDetailScreen({
    super.key,
    required this.title,
    required this.stocks,
    required this.folderId,
    required this.onFolderUpdated,
    this.folderIcon = Icons.folder,
  });

  @override
  State<WatchlistDetailScreen> createState() => _WatchlistDetailScreenState();
}

class _WatchlistDetailScreenState extends State<WatchlistDetailScreen> {
  bool _isEditMode = false;
  late TextEditingController _titleController;
  late IconData _selectedIcon;
  final List<IconData> _availableIcons = [
    Icons.folder,
    Icons.work,
    Icons.star,
    Icons.favorite,
    Icons.bookmark,
    Icons.label,
  ];
  final FirebaseService _firebaseService = FirebaseService();
  final ApiService _apiService = ApiService();
  List<Stock> _stocks = [];
  bool _isLoadingPrices = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _selectedIcon = widget.folderIcon;
    _loadFolderDetails();
    _loadStocksWithPrices();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  IconData _getIconDataFromName(String? iconName) {
    if (iconName == null) return Icons.folder;

    final iconCode = int.tryParse(iconName);
    if (iconCode == null) return Icons.folder;

    return IconData(iconCode, fontFamily: 'MaterialIcons');
  }

  Future<void> _loadFolderDetails() async {
    try {
      final folderDoc =
          await _firebaseService.getFolderDetails(widget.folderId);
      if (folderDoc != null && folderDoc.exists) {
        final data = folderDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _titleController.text = data['title'] ?? widget.title;
            _selectedIcon = _getIconDataFromName(data['iconName']);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading folder details: $e')),
        );
      }
    }
  }

  Future<void> _deleteFolder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
            'Are you sure you want to delete "${_titleController.text}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firebaseService.deleteWatchlistFolder(widget.folderId);
        if (mounted) {
          Navigator.pop(context); // Return to previous screen
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting folder: $e')),
          );
        }
      }
    }
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Watchlist'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _isEditMode = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Folder',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteFolder();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    try {
      await _firebaseService.updateWatchlistFolder(
        widget.folderId,
        title: _titleController.text,
        iconName: _selectedIcon.codePoint.toString(),
      );

      widget.onFolderUpdated(_titleController.text, _selectedIcon);

      if (mounted) {
        setState(() => _isEditMode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    }
  }

  Future<void> _addStockToWatchlist(Stock stock) async {
    try {
      await _firebaseService.addStockToWatchlist(widget.folderId, stock);
      setState(() {
        widget.stocks.add(stock);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${stock.symbol} to watchlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding stock: $e')),
        );
      }
    }
  }

  Future<void> _removeStock(Stock stock) async {
    try {
      // First remove from database
      await _firebaseService.removeStockFromWatchlist(
        widget.folderId,
        stock.symbol,
      );

      // Then update local state
      setState(() {
        _stocks.removeWhere((s) => s.symbol == stock.symbol);
        widget.stocks.removeWhere((s) => s.symbol == stock.symbol);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${stock.symbol}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _addStockToWatchlist(stock),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing stock: $e')),
        );
      }
    }
  }

  Future<void> _updateStocksOrder() async {
    try {
      await _firebaseService.updateStocksOrder(
        widget.folderId,
        _stocks.map((s) => s.symbol).toList(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e')),
        );
      }
    }
  }

  Future<void> _updateStockPrices(List<Stock> stocks) async {
    setState(() => _isLoadingPrices = true);
    try {
      for (var stock in stocks) {
        final quote = await _apiService.getStockQuote(stock.symbol);
        stock.price = quote.currentPrice;
        stock.priceChange = quote.percentChange;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating prices: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPrices = false);
      }
    }
  }

  void _loadStocksWithPrices() {
    _firebaseService.getWatchlistStocks(widget.folderId).listen((snapshot) {
      final stocks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Stock(
          symbol: data['symbol'],
          name: data['name'],
        );
      }).toList();

      setState(() => _stocks = stocks);
      _updateStockPrices(stocks);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        leading: _isEditMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _titleController.text = widget.title;
                  setState(() => _isEditMode = false);
                },
              )
            : null,
        actions: [
          if (_isEditMode)
            TextButton(
              onPressed: () {
                _saveChanges();
                setState(() => _isEditMode = false);
              },
              child: const Text('Done'),
            )
          else
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push<Stock>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StockSearchScreen(),
                  ),
                );

                if (result != null) {
                  await _addStockToWatchlist(result);
                }
              },
            ),
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showOptionsSheet,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _isEditMode ? _showIconPicker : null,
                  child: Container(
                    margin: const EdgeInsets.only(left: 2),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isEditMode ? Colors.blue : Colors.grey[200]!,
                        width: _isEditMode ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      _selectedIcon,
                      color: Colors.blue[700],
                      size: 48,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (_isEditMode)
                        TextField(
                          controller: _titleController,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        )
                      else
                        Text(
                          _titleController.text,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '${_stocks.length} items',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _stocks.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _stocks.removeAt(oldIndex);
                  _stocks.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final stock = _stocks[index];
                return Dismissible(
                  key: Key(stock.symbol),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Remove ${stock.symbol}?'),
                        content: Text(
                          'Are you sure you want to remove ${stock.symbol} from this watchlist?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) => _removeStock(stock),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (_isEditMode)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.drag_handle),
                          ),
                        Expanded(
                          child: StockListItem(
                            symbol: stock.symbol,
                            companyName: stock.name,
                            price: stock.price ?? 0.0,
                            priceChange: stock.priceChange ?? 0.0,
                            isLoading: false,
                            onTap: _isEditMode
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            StockDetailScreen(stock: stock),
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Icon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: _availableIcons
                  .map((icon) => IconButton(
                        icon: Icon(
                          icon,
                          size: 32,
                          color: icon == _selectedIcon ? Colors.blue : null,
                        ),
                        onPressed: () {
                          setState(() => _selectedIcon = icon);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

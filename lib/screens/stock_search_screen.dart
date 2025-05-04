import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api.dart';
import '../models/stock.dart';

class StockSearchScreen extends StatefulWidget {
  const StockSearchScreen({super.key});

  @override
  State<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends State<StockSearchScreen> {
  final _searchController = TextEditingController();
  final _apiService = ApiService();
  List<StockSearchResult> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  Future<void> _searchStocks(String query) async {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoading = true);

      try {
        final results = await _apiService.searchStocks(query);
        if (mounted) {
          setState(() => _searchResults = results);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Stocks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search stocks...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _searchStocks,
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    title: Text(result.symbol),
                    subtitle: Text(result.name),
                    trailing: IconButton(
                      icon: const CircleAvatar(
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                      onPressed: () {
                        final stock = Stock(
                          symbol: result.symbol,
                          name: result.name,
                          price: 0.0,
                          priceChange: 0.0,
                        );
                        Navigator.pop(context, stock);
                      },
                    ),
                    onTap: null, // Disable tile tap
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:stockwatcher/models/news.dart';
import 'package:stockwatcher/services/api.dart';
import 'package:stockwatcher/services/firebase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final ApiService _apiService = ApiService();
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, List<NewsArticle>> _newsMap = {};
  bool _isLoading = false;
  StreamSubscription? _stocksSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to changes in all watchlist folders
    _startListeningToStocks();
  }

  void _startListeningToStocks() {
    // Get a stream of all watchlist folders
    _stocksSubscription = _firebaseService.watchAllStocks().listen((stocks) {
      // When the stocks change, reload the news
      _loadNews();
    });
  }

  @override
  void dispose() {
    _stocksSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNews() async {
    setState(() => _isLoading = true);
    try {
      // Get all unique stocks that currently exist in watchlists
      final stocks = await _firebaseService.getAllWatchlistStocks();
      // Create a set of unique symbols for efficient lookup
      final uniqueSymbols = stocks.map((s) => s.symbol).toSet();

      final Map<String, List<NewsArticle>> newsMap = {};

      // Only fetch and store news for stocks that exist in watchlists
      for (final symbol in uniqueSymbols) {
        final symbolNews = await _apiService.getCompanyNews(symbol);
        if (symbolNews.isNotEmpty) {
          newsMap[symbol] = symbolNews;
        }
      }

      if (mounted) {
        setState(() => _newsMap = newsMap);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading news: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openNewsUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the article')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market News'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNews,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNews,
              child: _newsMap.isEmpty
                  ? const Center(
                      child: Text('No news available'),
                    )
                  : ListView.builder(
                      itemCount: _newsMap.length,
                      itemBuilder: (context, index) {
                        final symbol = _newsMap.keys.elementAt(index);
                        final articles = _newsMap[symbol]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Text(
                                    symbol,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${articles.length}',
                                      style: TextStyle(
                                        color: Colors.blue[900],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: articles.length,
                              itemBuilder: (context, articleIndex) {
                                final article = articles[articleIndex];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 4.0,
                                  ),
                                  child: InkWell(
                                    onTap: () => _openNewsUrl(article.url),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  article.source,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.blue,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  article.headline,
                                                  style: const TextStyle(
                                                    fontSize:
                                                        14, // Changed from 16
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  DateFormat('h:mm a').format(
                                                    DateTime
                                                        .fromMillisecondsSinceEpoch(
                                                      article.datetime * 1000,
                                                    ),
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (article.image.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                article.image,
                                                width: 80, // Changed from 100
                                                height: 80, // Changed from 100
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    const SizedBox.shrink(),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Divider(),
                          ],
                        );
                      },
                    ),
            ),
    );
  }
}

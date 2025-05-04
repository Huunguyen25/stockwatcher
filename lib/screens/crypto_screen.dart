import 'package:flutter/material.dart';
import 'package:stockwatcher/services/api.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';
import 'dart:async';

class CryptoScreen extends StatefulWidget {
  const CryptoScreen({super.key});

  @override
  State<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends State<CryptoScreen> {
  final ApiService _apiService = ApiService();
  final Map<String, Quote> _cryptoQuotes = {};
  final Map<String, List<double>> _cryptoChartData = {};
  bool _isLoading = true;
  bool _isLoadingCharts = true;
  Timer? _priceRefreshTimer;
  Timer? _chartRefreshTimer;
  int _errorCount = 0;
  static const int _maxErrorCount = 3;

  static const List<String> popularCryptos = [
    "BINANCE:BTCUSDT", // Bitcoin
    "BINANCE:ETHUSDT", // Ethereum
    "BINANCE:SOLUSDT", // Solana
    "BINANCE:BNBUSDT", // BNB
    "BINANCE:XRPUSDT", // XRP
    "BINANCE:ADAUSDT", // Cardano
    "BINANCE:DOGEUSDT", // Dogecoin
    "BINANCE:AVAXUSDT", // Avalanche
    "BINANCE:DOTUSDT", // Polkadot
  ];

  static const Map<String, String> cryptoNames = {
    "BINANCE:BTCUSDT": "Bitcoin",
    "BINANCE:ETHUSDT": "Ethereum",
    "BINANCE:SOLUSDT": "Solana",
    "BINANCE:BNBUSDT": "BNB",
    "BINANCE:XRPUSDT": "XRP",
    "BINANCE:ADAUSDT": "Cardano",
    "BINANCE:DOGEUSDT": "Dogecoin",
    "BINANCE:AVAXUSDT": "Avalanche",
    "BINANCE:DOTUSDT": "Polkadot",
  };

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadCryptoPrices();
    await _loadAllCryptoCharts();
    _setupRefreshTimers();
  }

  void _setupRefreshTimers() {
    _priceRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadCryptoPrices(),
    );

    _chartRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _loadAllCryptoCharts(),
    );
  }

  @override
  void dispose() {
    _priceRefreshTimer?.cancel();
    _chartRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCryptoPrices() async {
    if (_errorCount >= _maxErrorCount) {
      _handleTooManyErrors();
      return;
    }

    try {
      for (final symbol in popularCryptos) {
        if (!mounted) return;

        try {
          final quote = await _apiService.getStockQuote(symbol);
          if (mounted) {
            setState(() => _cryptoQuotes[symbol] = quote);
          }
          await Future.delayed(const Duration(milliseconds: 250));
        } catch (e) {
          continue;
        }
      }
      _errorCount = 0;
    } catch (e) {
      _errorCount++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading crypto prices: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAllCryptoCharts() async {
    if (_errorCount >= _maxErrorCount) {
      _handleTooManyErrors();
      return;
    }

    try {
      setState(() => _isLoadingCharts = true);

      for (final symbol in popularCryptos) {
        if (!mounted) return;

        try {
          final yahooSymbol =
              symbol.replaceAll('BINANCE:', '').replaceAll('USDT', '-USD');
          final chartData = await _apiService.fetchStockIntraday(
            yahooSymbol,
            '1d',
          );

          if (mounted) {
            setState(() {
              _cryptoChartData[symbol] =
                  chartData.pricePoints.map((point) => point.price).toList();
            });
          }
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          continue;
        }
      }
      _errorCount = 0;
    } catch (e) {
      _errorCount++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading charts: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCharts = false);
      }
    }
  }

  void _handleTooManyErrors() {
    _priceRefreshTimer?.cancel();
    _chartRefreshTimer?.cancel();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too many errors occurred. Please try again later.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handleManualRefresh() async {
    _errorCount = 0;
    await _loadCryptoPrices();
    await _loadAllCryptoCharts();
    _setupRefreshTimers();
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      return '\$${price.toStringAsFixed(2)}';
    } else if (price >= 1) {
      return '\$${price.toStringAsFixed(4)}';
    } else {
      return '\$${price.toStringAsFixed(6)}';
    }
  }

  Widget _buildSparkline(String symbol, bool isPositive) {
    final data = _cryptoChartData[symbol];
    if (data == null || data.isEmpty) {
      return const SizedBox(width: 100, height: 40);
    }

    return SizedBox(
      width: 100,
      height: 40,
      child: SfSparkLineChart(
        data: data,
        color: isPositive ? Colors.green : Colors.red,
        width: 1,
        axisLineWidth: 0,
        marker: const SparkChartMarker(
            displayMode: SparkChartMarkerDisplayMode.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _handleManualRefresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: popularCryptos.length,
                itemBuilder: (context, index) {
                  final symbol = popularCryptos[index];
                  final quote = _cryptoQuotes[symbol];
                  final name = cryptoNames[symbol] ?? symbol;

                  if (quote == null) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  symbol.replaceAll('BINANCE:', ''),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: _buildSparkline(
                                symbol,
                                quote.percentChange >= 0,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatPrice(quote.currentPrice),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: quote.percentChange >= 0
                                        ? Colors.green[50]
                                        : Colors.red[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${quote.percentChange >= 0 ? '+' : ''}${quote.percentChange.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color: quote.percentChange >= 0
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

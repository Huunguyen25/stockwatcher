import 'package:dio/dio.dart';
import '../models/price_point.dart';
import '../models/news.dart';
import 'config_service.dart';

class Quote {
  final double currentPrice; // c
  final double change; // d
  final double percentChange; // dp
  final double highPrice; // h
  final double lowPrice; // l
  final double openPrice; // o
  final double previousClose; // pc
  final int timestamp; // t

  Quote({
    required this.currentPrice,
    required this.change,
    required this.percentChange,
    required this.highPrice,
    required this.lowPrice,
    required this.openPrice,
    required this.previousClose,
    required this.timestamp,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      currentPrice: json['c']?.toDouble() ?? 0.0,
      change: json['d']?.toDouble() ?? 0.0,
      percentChange: json['dp']?.toDouble() ?? 0.0,
      highPrice: json['h']?.toDouble() ?? 0.0,
      lowPrice: json['l']?.toDouble() ?? 0.0,
      openPrice: json['o']?.toDouble() ?? 0.0,
      previousClose: json['pc']?.toDouble() ?? 0.0,
      timestamp: json['t'] ?? 0,
    );
  }
}

class StockSearchResult {
  final String symbol;
  final String name;
  final String type;

  StockSearchResult({
    required this.symbol,
    required this.name,
    required this.type,
  });

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      symbol: json['symbol'] ?? '',
      name: json['description'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

class ApiService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://finnhub.io/api/v1';
  late final String _apiKey;
  final ConfigService _configService = ConfigService();

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _apiKey = _configService.finnhubApiKey;
  }

  // Fetch stock quote data
  Future<Quote> getStockQuote(String symbol) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/quote',
        queryParameters: {
          'symbol': symbol,
          'token': _apiKey,
        },
      );
      return Quote.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Search stocks
  Future<List<StockSearchResult>> searchStocks(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'q': query,
          'exchange': 'US',
          'token': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final results = response.data['result'] as List;
        return results
            .map((item) => StockSearchResult.fromJson(item))
            .where((stock) => stock.type == 'Common Stock')
            .toList();
      }
      throw Exception('Failed to search stocks');
    } catch (e) {
      throw Exception('Error searching stocks: $e');
    }
  }

  // Fetch stock intraday data from Yahoo Finance
  Future<YahooChartData> fetchStockIntraday(String symbol, String range) async {
    try {
      final response = await _dio.get(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol',
        queryParameters: {
          'interval': _getInterval(range),
          'range': range,
        },
      );

      if (response.statusCode == 200) {
        return YahooChartData.fromJson(response.data);
      }
      throw Exception('Failed to load chart data');
    } catch (e) {
      throw Exception('Error fetching chart data: $e');
    }
  }

  // Fetch company news
  Future<List<NewsArticle>> getCompanyNews(String symbol) async {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final response = await _dio.get(
        '$_baseUrl/company-news',
        queryParameters: {
          'symbol': symbol,
          'from': today,
          'to': today,
          'token': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> newsData = response.data;
        return newsData.map((item) => NewsArticle.fromJson(item)).toList();
      }
      throw Exception('Failed to load news');
    } catch (e) {
      throw _handleError(e as DioException);
    }
  }

  // Helper method to determine interval based on range
  String _getInterval(String range) {
    switch (range) {
      case '1d':
        return '5m'; // 2-minute intervals for 1-day
      case '1w': // Changed from '5d' to '1w'
        return '15m'; // 30-minute intervals for 1-week
      case '1mo':
        return '1h'; // Daily intervals for 1-month
      case '1y':
        return '1d'; // Daily intervals for 1-year
      case '5y':
        return '1wk'; // Weekly intervals for 5-years
      case 'max':
        return '1mo'; // Monthly intervals for max range
      default:
        return '2m';
    }
  }

  // Helper method to handle errors
  Exception _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return Exception(
          'Connection timeout. Please check your internet connection.');
    } else if (e.type == DioExceptionType.badResponse) {
      return Exception(
          'Server returned error ${e.response?.statusCode}: ${e.response?.statusMessage}');
    } else {
      return Exception('An error occurred: ${e.message}');
    }
  }
}

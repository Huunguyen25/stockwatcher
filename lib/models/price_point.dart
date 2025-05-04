class PricePoint {
  final DateTime timestamp;
  final double price;

  PricePoint(this.timestamp, this.price);
}

class YahooChartData {
  final List<PricePoint> pricePoints;
  final double previousClose;
  final double dayHigh;
  final double dayLow;
  final double currentPrice;

  YahooChartData({
    required this.pricePoints,
    required this.previousClose,
    required this.dayHigh,
    required this.dayLow,
    required this.currentPrice,
  });

  factory YahooChartData.fromJson(Map<String, dynamic> json) {
    final result = json['chart']['result'][0];
    final timestamps = result['timestamp'] as List;
    final quotes = result['indicators']['quote'][0];
    final closes = quotes['close'] as List;
    final meta = result['meta'];

    List<PricePoint> points = [];
    for (var i = 0; i < timestamps.length; i++) {
      if (closes[i] != null) {
        points.add(PricePoint(
          DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
          closes[i],
        ));
      }
    }

    return YahooChartData(
      pricePoints: points,
      previousClose: meta['chartPreviousClose']?.toDouble() ?? 0.0,
      dayHigh: meta['regularMarketDayHigh']?.toDouble() ?? 0.0,
      dayLow: meta['regularMarketDayLow']?.toDouble() ?? 0.0,
      currentPrice: meta['regularMarketPrice']?.toDouble() ?? 0.0,
    );
  }
}

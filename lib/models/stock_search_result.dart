class StockSearchResult {
  final String symbol;
  final String displaySymbol;
  final String description;
  final String type;

  StockSearchResult({
    required this.symbol,
    required this.displaySymbol,
    required this.description,
    required this.type,
  });

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      symbol: json['symbol'] ?? '',
      displaySymbol: json['displaySymbol'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

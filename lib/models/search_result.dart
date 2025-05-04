class SearchResult {
  final String description;
  final String displaySymbol;
  final String symbol;
  final String type;

  SearchResult({
    required this.description,
    required this.displaySymbol,
    required this.symbol,
    required this.type,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      description: json['description'] ?? '',
      displaySymbol: json['displaySymbol'] ?? '',
      symbol: json['symbol'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

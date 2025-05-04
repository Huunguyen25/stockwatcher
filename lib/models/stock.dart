import 'package:cloud_firestore/cloud_firestore.dart';

class Stock {
  final String symbol;
  final String name;
  double? price;
  double? priceChange;

  Stock({
    required this.symbol,
    required this.name,
    this.price,
    this.priceChange,
  });

  factory Stock.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Stock(
      symbol: data['symbol'] ?? '',
      name: data['name'] ?? '',
      price: data['price']?.toDouble() ?? 0.0,
      priceChange: data['priceChange']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'name': name,
      'price': price,
      'priceChange': priceChange,
    };
  }
}

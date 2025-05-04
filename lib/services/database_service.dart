import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stock.dart';
import '../models/watchlist_folder.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  DatabaseService({required this.userId});

  // References
  CollectionReference get _watchlistCollection => _db.collection('watchlist');

  DocumentReference get _myWatchlistDoc =>
      _watchlistCollection.doc('my_watchlist');

  CollectionReference get _stocksCollection =>
      _myWatchlistDoc.collection('stocks');

  // Create or update watchlist folder
  Future<void> updateWatchlistFolder({
    required String title,
    required String iconName,
  }) async {
    await _myWatchlistDoc.set({
      'title': title,
      'iconName': iconName,
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Add stock to watchlist
  Future<void> addStockToWatchlist(Stock stock) async {
    await _stocksCollection.doc(stock.symbol).set({
      'symbol': stock.symbol,
      'name': stock.name,
      'price': stock.price,
      'priceChange': stock.priceChange,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  // Remove stock from watchlist
  Future<void> removeStockFromWatchlist(String symbol) async {
    await _stocksCollection.doc(symbol).delete();
  }

  // Stream watchlist folder with stocks
  Stream<WatchlistFolder> watchlistStream() {
    return _myWatchlistDoc.snapshots().asyncMap((folderDoc) async {
      // Get all stocks in the folder
      final stocksSnapshot = await _stocksCollection.get();
      final stocks =
          stocksSnapshot.docs.map((doc) => Stock.fromDocument(doc)).toList();

      return WatchlistFolder.fromDocument(folderDoc);
    });
  }

  // Stream stocks only
  Stream<List<Stock>> stocksStream() {
    return _stocksCollection.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Stock.fromDocument(doc)).toList());
  }
}

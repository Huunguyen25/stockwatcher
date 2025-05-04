import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/stock.dart';
import '../models/watchlist_folder.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Authentication methods
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');

    try {
      // Get all user's watchlists
      final watchlists = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('watchlists')
          .get();

      // Delete all watchlists and their contents
      final batch = _firestore.batch();
      for (var watchlist in watchlists.docs) {
        // Delete all stocks in the watchlist
        final stocks = await watchlist.reference.collection('stocks').get();
        for (var stock in stocks.docs) {
          batch.delete(stock.reference);
        }
        // Delete the watchlist itself
        batch.delete(watchlist.reference);
      }
      await batch.commit();

      // Finally delete the user account
      await user.delete();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  // Watchlist methods
  CollectionReference get watchlistCollection => _firestore
      .collection('users')
      .doc(currentUser?.uid ?? 'default')
      .collection('watchlists');

  DocumentReference get myWatchlistDoc =>
      watchlistCollection.doc('my_watchlist');

  CollectionReference get stocksCollection =>
      myWatchlistDoc.collection('stocks');

  // Initialize default watchlist
  Future<void> initializeDefaultWatchlist() async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    await myWatchlistDoc.set({
      'title': 'My Watchlist',
      'iconName': 'folder',
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Update watchlist folder
  Future<void> updateWatchlistFolder(
    String folderId, {
    required String title,
    required String iconName,
  }) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return await _firestore
        .collection('users')
        .doc(userId)
        .collection('watchlists')
        .doc(folderId)
        .set({
      'title': title,
      'iconName': iconName,
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get watchlist folder
  Stream<DocumentSnapshot> getWatchlistFolder(String folderId) {
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('watchlists')
        .doc(folderId)
        .snapshots();
  }

  // Add stock to watchlist
  Future<void> addStockToWatchlist(String folderId, Stock stock) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return await _firestore
        .collection('users')
        .doc(userId)
        .collection('watchlists')
        .doc(folderId)
        .collection('stocks')
        .doc(stock.symbol)
        .set({
      'symbol': stock.symbol,
      'name': stock.name,
      'addedAt': FieldValue.serverTimestamp(),
      'userId': userId,
    });
  }

  Future<void> addStockToFolderWatchlist(String folderId, Stock stock) async {
    final userId = currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return await _firestore
        .collection('users')
        .doc(userId)
        .collection('watchlists')
        .doc(folderId)
        .collection('stocks')
        .doc(stock.symbol)
        .set({
      'symbol': stock.symbol,
      'name': stock.name,
      'addedAt': FieldValue.serverTimestamp(),
      'userId': userId,
    });
  }

  // Remove stock from watchlist
  Future<void> removeStockFromWatchlist(String folderId, String symbol) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('watchlists')
          .doc(folderId)
          .collection('stocks')
          .doc(symbol)
          .delete();
    } catch (e) {
      throw Exception('Failed to remove stock: $e');
    }
  }

  Future<void> updateStocksOrder(
      String folderId, List<String> orderedSymbols) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final stocksRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('watchlists')
        .doc(folderId)
        .collection('stocks');

    // Get all current stocks
    final currentStocks = await stocksRef.get();

    // Create a map of symbol to document data
    final stockDataMap = {
      for (var doc in currentStocks.docs)
        (doc.data()['symbol'] as String): doc.data()
    };

    // Delete all current documents
    for (var doc in currentStocks.docs) {
      batch.delete(doc.reference);
    }

    // Create new documents with order
    for (var i = 0; i < orderedSymbols.length; i++) {
      final symbol = orderedSymbols[i];
      if (stockDataMap.containsKey(symbol)) {
        final data = Map<String, dynamic>.from(stockDataMap[symbol]!);
        data['order'] = i;
        batch.set(stocksRef.doc(), data);
      }
    }

    await batch.commit();
  }

  // Get watchlist stream
  Stream<WatchlistFolder> watchlistStream() {
    return myWatchlistDoc
        .snapshots()
        .map((doc) => WatchlistFolder.fromDocument(doc));
  }

  // Get stocks stream
  Stream<QuerySnapshot> stocksStream() {
    return stocksCollection.orderBy('addedAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot> getWatchlistStocks(String folderId) {
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('watchlists')
        .doc(folderId)
        .collection('stocks')
        .snapshots();
  }

  // Get folder details
  Future<DocumentSnapshot> getFolderDetails(String folderId) {
    if (currentUser == null) throw Exception('User not authenticated');

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('watchlists')
        .doc(folderId)
        .get();
  }

  Future<List<Stock>> getAllWatchlistStocks() async {
    if (currentUser == null) return [];

    final folders = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('watchlists')
        .get();

    List<Stock> allStocks = [];

    try {
      for (var folder in folders.docs) {
        final stocksSnap = await folder.reference.collection('stocks').get();
        final stocks = stocksSnap.docs.map((doc) {
          final data = doc.data();
          return Stock(
            symbol: data['symbol'],
            name: data['name'],
          );
        }).toList();
        allStocks.addAll(stocks);
      }

      // Remove duplicates based on symbol and return only unique stocks
      final Map<String, Stock> uniqueStocks = {};
      for (var stock in allStocks) {
        uniqueStocks[stock.symbol] = stock;
      }

      return uniqueStocks.values.toList();
    } catch (e) {
      throw Exception('Error getting all watchlist stocks: $e');
    }
  }

  Future<DocumentReference> createWatchlistFolder(
      Map<String, dynamic> folderData) async {
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      return await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('watchlists')
          .add({
        ...folderData,
        'userId': currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error creating watchlist: $e');
    }
  }

  Stream<QuerySnapshot> getAllWatchlistFolders() {
    if (currentUser == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('watchlists')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Method to get all stocks for a specific folder
  Stream<QuerySnapshot> getWatchlistStocksByFolderId(String folderId) {
    return _firestore
        .collection('users')
        .doc(currentUser?.uid ?? 'default')
        .collection('watchlists')
        .doc(folderId)
        .collection('stocks')
        .snapshots();
  }

  Future<void> deleteWatchlistFolder(String folderId) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get a reference to the folder
    final folderRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('watchlists')
        .doc(folderId);

    // Get all stocks in the folder
    final stocksSnapshot = await folderRef.collection('stocks').get();

    // Create a batch operation
    final batch = _firestore.batch();

    // Delete all stocks in the folder
    for (var doc in stocksSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the folder document itself
    batch.delete(folderRef);

    // Commit the batch operation
    await batch.commit();
  }

  Stream<List<Stock>> watchAllStocks() {
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('watchlists')
        .snapshots()
        .asyncMap((folders) async {
      List<Stock> allStocks = [];

      for (var folder in folders.docs) {
        final stocksSnap = await folder.reference.collection('stocks').get();
        final stocks = stocksSnap.docs.map((doc) {
          final data = doc.data();
          return Stock(
            symbol: data['symbol'],
            name: data['name'],
          );
        }).toList();
        allStocks.addAll(stocks);
      }

      // Remove duplicates
      final Map<String, Stock> uniqueStocks = {};
      for (var stock in allStocks) {
        uniqueStocks[stock.symbol] = stock;
      }

      return uniqueStocks.values.toList();
    });
  }
}

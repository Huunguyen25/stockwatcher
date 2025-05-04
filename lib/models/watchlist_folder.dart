import 'package:cloud_firestore/cloud_firestore.dart';

class WatchlistFolder {
  final String title;
  final String iconName;
  final String id;
  final DateTime? updatedAt;

  WatchlistFolder({
    required this.title,
    required this.iconName,
    required this.id,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'iconName': iconName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory WatchlistFolder.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WatchlistFolder(
      id: doc.id,
      title: data['title'] ?? '',
      iconName: data['iconName'] ?? 'folder',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

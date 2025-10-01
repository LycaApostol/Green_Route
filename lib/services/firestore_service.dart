import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // reference to user subcollections
  CollectionReference<Map<String, dynamic>> _userCollection(String uid, String sub) =>
      _db.collection('users').doc(uid).collection(sub);

  // Stream favorites for user
  Stream<List<Map<String, dynamic>>> streamFavorites(String uid) {
    return _userCollection(uid, 'favorites')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              m['id'] = d.id;
              return m;
            }).toList());
  }

  // Stream recent routes for user
  Stream<List<Map<String, dynamic>>> streamRecentRoutes(String uid) {
    return _userCollection(uid, 'recent_routes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              m['id'] = d.id;
              return m;
            }).toList());
  }

  // Add favorite
  Future<void> addFavorite(String uid, Map<String, dynamic> route) async {
    final doc = _userCollection(uid, 'favorites').doc();
    route['createdAt'] = FieldValue.serverTimestamp();
    await doc.set(route);
  }

  // Remove favorite
  Future<void> removeFavorite(String uid, String favId) async {
    await _userCollection(uid, 'favorites').doc(favId).delete();
  }

  // Add recent route (when user navigates)
  Future<void> addRecentRoute(String uid, Map<String, dynamic> route) async {
    final doc = _userCollection(uid, 'recent_routes').doc();
    route['createdAt'] = FieldValue.serverTimestamp();
    await doc.set(route);
  }
}

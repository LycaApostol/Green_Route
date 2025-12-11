import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if current user is admin
  Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Force token refresh to get latest claims
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims;
      
      return claims?['admin'] == true;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Stream all feedback
  Stream<List<Map<String, dynamic>>> streamAllFeedback() {
    return _firestore
        .collection('feedback')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Update feedback status
  Future<bool> updateFeedbackStatus({
    required String feedbackId,
    required String status,
    String? adminNotes,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateFeedbackStatus');
      await callable.call({
        'feedbackId': feedbackId,
        'status': status,
        'adminNotes': adminNotes,
      });
      return true;
    } catch (e) {
      print('Error updating feedback: $e');
      return false;
    }
  }

  // Delete feedback
  Future<bool> deleteFeedback(String feedbackId) async {
    try {
      await _firestore.collection('feedback').doc(feedbackId).delete();
      return true;
    } catch (e) {
      print('Error deleting feedback: $e');
      return false;
    }
  }

  // Stream all alerts
  Stream<List<Map<String, dynamic>>> streamAllAlerts() {
    return _firestore
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Create alert
  Future<Map<String, dynamic>> createAlert({
    required String title,
    required String message,
    required String type,
    required String priority,
  }) async {
    try {
      final callable = _functions.httpsCallable('createAlert');
      final result = await callable.call({
        'title': title,
        'message': message,
        'type': type,
        'priority': priority,
      });
      
      return {
        'success': true,
        'alertId': result.data['alertId'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Delete alert
  Future<bool> deleteAlert(String alertId) async {
    try {
      final callable = _functions.httpsCallable('deleteAlert');
      await callable.call({'alertId': alertId});
      return true;
    } catch (e) {
      print('Error deleting alert: $e');
      return false;
    }
  }

  // Stream all users
  Stream<List<Map<String, dynamic>>> streamAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return data;
            }).toList());
  }

  // Get app statistics
  Future<Map<String, dynamic>> getAppStatistics() async {
    try {
      final callable = _functions.httpsCallable('getAppStatistics');
      final result = await callable.call();
      return result.data as Map<String, dynamic>;
    } catch (e) {
      print('Error getting statistics: $e');
      return {
        'totalUsers': 0,
        'totalFeedback': 0,
        'totalRoutes': 0,
        'activeAlerts': 0,
      };
    }
  }
}
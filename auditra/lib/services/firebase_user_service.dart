import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import 'api_service.dart';

/// Service for managing user data in Firestore
class FirebaseUserService {
  static final FirebaseFirestore _firestore = FirebaseService.firestore;

  /// Sync Django user to Firestore
  static Future<void> syncUserToFirestore(int userId, Map<String, dynamic> userData) async {
    try {
      final firebaseUid = await _getFirebaseUid(userId);
      if (firebaseUid == null) return;

      final userDoc = {
        'firebaseUid': firebaseUid,
        'djangoUserId': userId,
        'email': userData['email'] ?? '',
        'displayName': userData['displayName'] ?? userData['username'] ?? '',
        'username': userData['username'] ?? '',
        'role': userData['role'] ?? 'unassigned',
        'roleDisplay': userData['roleDisplay'] ?? 'Unassigned',
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(firebaseUid).set(
        userDoc,
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error syncing user to Firestore: $e');
    }
  }

  /// Update FCM token for user
  static Future<void> updateFCMToken(int userId, String fcmToken) async {
    try {
      final firebaseUid = await _getFirebaseUid(userId);
      if (firebaseUid == null) return;

      await _firestore.collection('users').doc(firebaseUid).update({
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  /// Get user data from Firestore
  static Future<Map<String, dynamic>?> getUserById(String firebaseUid) async {
    try {
      final doc = await _firestore.collection('users').doc(firebaseUid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user from Firestore: $e');
      return null;
    }
  }

  /// Update user's last seen timestamp
  static Future<void> updateLastSeen(int userId) async {
    try {
      final firebaseUid = await _getFirebaseUid(userId);
      if (firebaseUid == null) return;

      await _firestore.collection('users').doc(firebaseUid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last seen: $e');
    }
  }

  /// Get Firebase UID for Django user ID
  static Future<String?> _getFirebaseUid(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? firebaseUid = prefs.getString('firebase_uid');
      
      if (firebaseUid == null) {
        // Generate Firebase UID from Django user ID
        firebaseUid = 'django_$userId';
        await prefs.setString('firebase_uid', firebaseUid);
      }
      
      return firebaseUid;
    } catch (e) {
      print('Error getting Firebase UID: $e');
      return null;
    }
  }

  /// Get current user's Firebase UID
  static Future<String?> getCurrentUserFirebaseUid() async {
    final userId = await ApiService.getUserId();
    if (userId == null) return null;
    return await _getFirebaseUid(userId);
  }
}




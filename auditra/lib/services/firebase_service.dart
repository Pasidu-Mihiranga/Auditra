import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// Firebase service for initialization and authentication
class FirebaseService {
  static FirebaseAuth? _auth;
  static FirebaseFirestore? _firestore;
  static FirebaseMessaging? _messaging;
  
  static FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  static FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  static FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;

  /// Initialize Firebase
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _messaging = FirebaseMessaging.instance;
      
      // Enable offline persistence
      _firestore?.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      print('Error initializing Firebase: $e');
      rethrow;
    }
  }

  /// Authenticate user with custom token from Django backend
  static Future<void> authenticateWithCustomToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        throw Exception('No access token found');
      }

      // Get Firebase custom token from Django backend
      final response = await ApiService.getFirebaseCustomToken();
      
      if (response['success'] && response['custom_token'] != null) {
        final customToken = response['custom_token'] as String;
        
        // Sign in with custom token
        await auth.signInWithCustomToken(customToken);
        
        // Store Firebase UID
        final firebaseUser = auth.currentUser;
        if (firebaseUser != null) {
          await prefs.setString('firebase_uid', firebaseUser.uid);
        }
      } else {
        throw Exception('Failed to get custom token: ${response['message']}');
      }
    } catch (e) {
      print('Error authenticating with Firebase: $e');
      rethrow;
    }
  }

  /// Get current Firebase user
  static User? getCurrentUser() {
    return auth.currentUser;
  }

  /// Sign out from Firebase
  static Future<void> signOut() async {
    await auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('firebase_uid');
  }

  /// Check if user is authenticated with Firebase
  static bool isAuthenticated() {
    return auth.currentUser != null;
  }
}


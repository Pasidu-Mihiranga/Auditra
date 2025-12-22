import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'firebase_user_service.dart';
import 'api_service.dart';

/// Service for managing Firebase chat operations
class FirebaseChatService {
  static final FirebaseFirestore _firestore = FirebaseService.firestore;
  static final FirebaseAuth _auth = FirebaseService.auth;

  /// Create a group chat for a project
  /// Note: This is typically done on the backend when project is created
  static Future<String?> createGroupChat({
    required String projectId,
    required String projectTitle,
    required List<int> memberUserIds,
    required Map<int, String> memberRoles,
  }) async {
    try {
      final chatId = 'project_$projectId';
      
      // Convert Django user IDs to Firebase UIDs
      final members = memberUserIds.map((id) => 'django_$id').toList();
      final memberRolesMap = <String, String>{};
      memberRoles.forEach((userId, role) {
        memberRolesMap['django_$userId'] = role;
      });

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated with Firebase');
      }

      final chatData = {
        'type': 'group',
        'projectId': projectId,
        'projectTitle': projectTitle,
        'members': members,
        'memberRoles': memberRolesMap,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': null,
        'unreadCount': {for (var member in members) member: 0},
      };

      await _firestore.collection('chats').doc(chatId).set(chatData);
      return chatId;
    } catch (e) {
      print('Error creating group chat: $e');
      return null;
    }
  }

  /// Create or get private chat between two users
  static Future<String> createPrivateChatIfNeeded({
    required int userId1,
    required int userId2,
    String? projectId,
    String? projectTitle,
  }) async {
    try {
      // Generate deterministic chat ID from sorted user IDs
      final sortedIds = [userId1, userId2]..sort();
      final chatId = 'private_${sortedIds[0]}_${sortedIds[1]}${projectId != null ? '_$projectId' : ''}';

      final firebaseUid1 = 'django_$userId1';
      final firebaseUid2 = 'django_$userId2';

      // Check if chat already exists
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      
      if (!chatDoc.exists) {
        // Create new private chat
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          throw Exception('User not authenticated with Firebase');
        }

        final chatData = {
          'type': 'private',
          'members': [firebaseUid1, firebaseUid2],
          'createdBy': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': null,
          'unreadCount': {
            firebaseUid1: 0,
            firebaseUid2: 0,
          },
        };

        if (projectId != null) {
          chatData['projectId'] = projectId;
          chatData['projectTitle'] = projectTitle ?? '';
        }

        await _firestore.collection('chats').doc(chatId).set(chatData);
      }

      return chatId;
    } catch (e) {
      print('Error creating private chat: $e');
      rethrow;
    }
  }

  /// Send a message to a chat
  static Future<void> sendMessage({
    required String chatId,
    required String message,
    String type = 'text',
    String? projectId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated with Firebase');
      }

      // Get user info
      final userId = await ApiService.getUserId();
      final username = await ApiService.getUsername();
      final roleResult = await ApiService.getMyRole();
      
      String? displayName = username;
      String? role = 'unassigned';
      
      if (roleResult['success'] && roleResult['data'] != null) {
        final roleData = roleResult['data'];
        role = roleData['role'] ?? 'unassigned';
        // Try to get full name
        final profileResult = await ApiService.getProfile();
        if (profileResult['success'] && profileResult['data'] != null) {
          final profile = profileResult['data'];
          if (profile['first_name'] != null || profile['last_name'] != null) {
            displayName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
            if (displayName.isEmpty) displayName = username;
          }
        }
      }

      final messageData = {
        'chatId': chatId,
        'senderId': currentUser.uid,
        'senderName': displayName ?? 'Unknown',
        'senderRole': role,
        'message': message,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [currentUser.uid], // Sender has read their own message
        if (projectId != null) 'projectId': projectId,
      };

      // Add message to Firestore
      await _firestore.collection('messages').add(messageData);

      // Update chat's last message and increment unread counts
      final chatRef = _firestore.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();
      
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final members = List<String>.from(chatData['members'] ?? []);
        final unreadCount = Map<String, dynamic>.from(chatData['unreadCount'] ?? {});
        
        // Increment unread count for all members except sender
        for (var member in members) {
          if (member != currentUser.uid) {
            unreadCount[member] = (unreadCount[member] ?? 0) + 1;
          }
        }

        await chatRef.update({
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': unreadCount,
        });
      }
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  /// Get real-time stream of messages for a chat
  static Stream<QuerySnapshot> getChatMessagesStream(String chatId) {
    return _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Get real-time stream of user's chats
  static Stream<QuerySnapshot> getUserChatsStream(String firebaseUid) {
    return _firestore
        .collection('chats')
        .where('members', arrayContains: firebaseUid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// Mark messages as read
  static Future<void> markAsRead(String chatId, List<String> messageIds) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      
      for (var messageId in messageIds) {
        final messageRef = _firestore.collection('messages').doc(messageId);
        batch.update(messageRef, {
          'readBy': FieldValue.arrayUnion([currentUser.uid]),
        });
      }

      await batch.commit();

      // Update chat unread count
      final chatRef = _firestore.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();
      
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final unreadCount = Map<String, dynamic>.from(chatData['unreadCount'] ?? {});
        unreadCount[currentUser.uid] = 0;
        
        await chatRef.update({
          'unreadCount': unreadCount,
        });
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Get unread count for a specific chat
  static Future<int> getUnreadCount(String chatId, String firebaseUid) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        final data = chatDoc.data()!;
        final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
        return (unreadCount?[firebaseUid] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get total unread count for user
  static Future<int> getTotalUnreadCount(String firebaseUid) async {
    try {
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('members', arrayContains: firebaseUid)
          .get();

      int total = 0;
      for (var doc in chatsSnapshot.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
        total += (unreadCount?[firebaseUid] as int?) ?? 0;
      }
      return total;
    } catch (e) {
      print('Error getting total unread count: $e');
      return 0;
    }
  }

  /// Add member to group chat (when user is assigned to project)
  static Future<void> addMemberToGroupChat(String projectId, int userId, String role) async {
    try {
      final chatId = 'project_$projectId';
      final firebaseUid = 'django_$userId';

      await _firestore.collection('chats').doc(chatId).update({
        'members': FieldValue.arrayUnion([firebaseUid]),
        'memberRoles.$firebaseUid': role,
        'unreadCount.$firebaseUid': 0,
      });
    } catch (e) {
      print('Error adding member to group chat: $e');
    }
  }

  /// Get chat document
  static Future<DocumentSnapshot?> getChat(String chatId) async {
    try {
      return await _firestore.collection('chats').doc(chatId).get();
    } catch (e) {
      print('Error getting chat: $e');
      return null;
    }
  }

  /// Get Firestore instance (for use in screens)
  static FirebaseFirestore get firestore => _firestore;
}


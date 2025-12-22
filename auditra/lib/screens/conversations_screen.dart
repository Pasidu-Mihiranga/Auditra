import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firebase_chat_service.dart';
import '../services/firebase_user_service.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  Stream<QuerySnapshot>? _chatsStream;
  String? _currentFirebaseUid;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Ensure Firebase authentication
      if (!FirebaseService.isAuthenticated()) {
        await FirebaseService.authenticateWithCustomToken();
      }

      // Get current user's Firebase UID
      _currentFirebaseUid = await FirebaseUserService.getCurrentUserFirebaseUid();
      if (_currentFirebaseUid == null) {
        throw Exception('Failed to get Firebase UID');
      }

      // Set up real-time chats stream
      setState(() {
        _chatsStream = FirebaseChatService.getUserChatsStream(_currentFirebaseUid!);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing conversations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      Timestamp? ts;
      if (timestamp is Timestamp) {
        ts = timestamp;
      } else if (timestamp is Map) {
        ts = Timestamp.fromMillisecondsSinceEpoch(timestamp['_seconds'] * 1000);
      } else {
        return '';
      }

      final dateTime = ts.toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return DateFormat('HH:mm').format(dateTime);
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEE').format(dateTime);
      } else {
        return DateFormat('MMM d').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  String _getChatName(Map<String, dynamic> chatData, String currentUid) {
    final chatType = chatData['type'] ?? 'private';
    
    if (chatType == 'group') {
      return chatData['projectTitle'] ?? 'Group Chat';
    } else {
      // Private chat - get the other user's name
      final members = List<String>.from(chatData['members'] ?? []);
      final otherMember = members.firstWhere(
        (member) => member != currentUid,
        orElse: () => '',
      );
      
      // Try to get user info from Firestore
      // For now, return a placeholder
      return 'Private Chat';
    }
  }

  int _getUnreadCount(Map<String, dynamic> chatData, String currentUid) {
    final unreadCount = chatData['unreadCount'] as Map<String, dynamic>?;
    return (unreadCount?[currentUid] as int?) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[500]!,
                  Colors.blue[600]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Messages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Conversations List
          Expanded(
            child: _chatsStream == null || _currentFirebaseUid == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: _chatsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No conversations yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start a conversation to see it here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final chats = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chatDoc = chats[index];
                          final chatData = chatDoc.data() as Map<String, dynamic>;
                          final chatId = chatDoc.id;
                          final chatType = chatData['type'] ?? 'private';
                          final unreadCount = _getUnreadCount(chatData, _currentFirebaseUid!);
                          final chatName = _getChatName(chatData, _currentFirebaseUid!);
                          final lastMessage = chatData['lastMessage'] ?? 'No messages';
                          final lastMessageTime = chatData['lastMessageTime'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () async {
                                if (chatType == 'group') {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GroupChatScreen(
                                        chatId: chatId,
                                        projectId: chatData['projectId'] ?? '',
                                        projectTitle: chatData['projectTitle'] ?? 'Group Chat',
                                      ),
                                    ),
                                  );
                                } else {
                                  // Private chat - navigate to regular chat screen
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        chatId: chatId,
                                        chatName: chatName,
                                        chatType: 'private',
                                        projectId: chatData['projectId'],
                                        projectTitle: chatData['projectTitle'],
                                      ),
                                    ),
                                  );
                                }
                                // Refresh after returning
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: chatType == 'group'
                                            ? Colors.green[100]
                                            : Colors.blue[100],
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          chatType == 'group'
                                              ? Icons.group
                                              : Icons.person,
                                          color: chatType == 'group'
                                              ? Colors.green[700]
                                              : Colors.blue[700],
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  chatName,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (lastMessageTime != null)
                                                Text(
                                                  _formatTimestamp(lastMessageTime),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              if (unreadCount > 0) ...[
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  margin: const EdgeInsets.only(right: 8),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  lastMessage,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                    fontWeight: unreadCount > 0
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (unreadCount > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[600],
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    unreadCount > 99
                                                        ? '99+'
                                                        : unreadCount.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (chatData['projectTitle'] != null &&
                                              chatType == 'private') ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.folder_outlined,
                                                  size: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    chatData['projectTitle'],
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../screens/chat_screen.dart';
import '../services/firebase_chat_service.dart';
import '../services/firebase_user_service.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';

/// Reusable widget for "Chat with Coordinator" button
/// Used across multiple dashboards to avoid code duplication
class ChatWithCoordinatorButton extends StatefulWidget {
  final Project project;

  const ChatWithCoordinatorButton({
    super.key,
    required this.project,
  });

  @override
  State<ChatWithCoordinatorButton> createState() => _ChatWithCoordinatorButtonState();
}

class _ChatWithCoordinatorButtonState extends State<ChatWithCoordinatorButton> {
  int _unreadCount = 0;
  bool _isLoadingUnread = false;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (widget.project.coordinatorId == null) return;

    setState(() => _isLoadingUnread = true);

    try {
      // Ensure Firebase authentication
      if (!FirebaseService.isAuthenticated()) {
        await FirebaseService.authenticateWithCustomToken();
      }

      final currentUid = await FirebaseUserService.getCurrentUserFirebaseUid();
      if (currentUid == null) {
        setState(() => _isLoadingUnread = false);
        return;
      }

      // Create or get private chat
      final currentUserId = await ApiService.getUserId();
      if (currentUserId == null) {
        setState(() => _isLoadingUnread = false);
        return;
      }

      final chatId = await FirebaseChatService.createPrivateChatIfNeeded(
        userId1: currentUserId,
        userId2: widget.project.coordinatorId!,
        projectId: widget.project.id?.toString(),
        projectTitle: widget.project.title,
      );

      // Get unread count
      final unread = await FirebaseChatService.getUnreadCount(chatId, currentUid);

      if (mounted) {
        setState(() {
          _unreadCount = unread;
          _isLoadingUnread = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUnread = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.project.coordinatorId == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          try {
            // Ensure Firebase authentication
            if (!FirebaseService.isAuthenticated()) {
              await FirebaseService.authenticateWithCustomToken();
            }

            final currentUserId = await ApiService.getUserId();
            if (currentUserId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to get user ID')),
              );
              return;
            }

            // Create or get private chat
            final chatId = await FirebaseChatService.createPrivateChatIfNeeded(
              userId1: currentUserId,
              userId2: widget.project.coordinatorId!,
              projectId: widget.project.id?.toString(),
              projectTitle: widget.project.title,
            );

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  chatName: widget.project.coordinatorName ??
                      widget.project.coordinatorUsername ??
                      'Coordinator',
                  chatType: 'private',
                  projectId: widget.project.id?.toString(),
                  projectTitle: widget.project.title,
                  recipientId: widget.project.coordinatorId,
                  recipientName: widget.project.coordinatorName ??
                      widget.project.coordinatorUsername,
                  recipientRole: 'Coordinator',
                ),
              ),
            );

            // Reload unread count after returning from chat
            _loadUnreadCount();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error opening chat: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat, size: 18),
            const SizedBox(width: 8),
            const Text('Chat with Coordinator'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue[300]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

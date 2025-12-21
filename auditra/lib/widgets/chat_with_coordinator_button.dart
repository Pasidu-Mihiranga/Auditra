import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../screens/chat_screen.dart';
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
      final result = await ApiService.getConversations();
      if (result['success'] && mounted) {
        final conversations = List<Map<String, dynamic>>.from(result['conversations'] ?? []);
        
        // Find conversation matching coordinator and project
        final matchingConversation = conversations.firstWhere(
          (conv) => 
            conv['user_id'] == widget.project.coordinatorId &&
            (widget.project.id == null || conv['project_id'] == widget.project.id),
          orElse: () => <String, dynamic>{},
        );
        
        if (mounted) {
          setState(() {
            _unreadCount = matchingConversation['unread_count'] ?? 0;
            _isLoadingUnread = false;
          });
        }
      } else if (mounted) {
        setState(() => _isLoadingUnread = false);
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
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                recipientId: widget.project.coordinatorId,
                recipientName: widget.project.coordinatorName ?? widget.project.coordinatorUsername,
                recipientUsername: widget.project.coordinatorUsername,
                recipientRole: 'Coordinator',
                projectId: widget.project.id,
                projectTitle: widget.project.title,
              ),
            ),
          );
          // Reload unread count after returning from chat
          _loadUnreadCount();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
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


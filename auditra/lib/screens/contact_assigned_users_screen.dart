import 'package:flutter/material.dart';
import '../models/project_model.dart';
import 'chat_screen.dart';
import '../services/firebase_chat_service.dart';
import '../services/firebase_user_service.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';

class ContactAssignedUsersScreen extends StatelessWidget {
  final Project project;

  const ContactAssignedUsersScreen({
    super.key,
    required this.project,
  });

  void _openChat(BuildContext context, Map<String, dynamic> contact) async {
    final recipientUserId = contact['userId'];
    if (recipientUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Ensure Firebase authentication
      if (!FirebaseService.isAuthenticated()) {
        await FirebaseService.authenticateWithCustomToken();
      }

      // Get current user ID
      final currentUserId = await ApiService.getUserId();
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get current user ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create or get private chat
      final chatId = await FirebaseChatService.createPrivateChatIfNeeded(
        userId1: currentUserId,
        userId2: recipientUserId,
        projectId: project.id?.toString(),
        projectTitle: project.title,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            chatName: contact['name']!,
            chatType: 'private',
            projectId: project.id?.toString(),
            projectTitle: project.title,
            recipientId: recipientUserId,
            recipientName: contact['name']!,
            recipientRole: contact['role'],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> contacts = [];
    
    if (project.assignedFieldOfficerId != null && project.assignedFieldOfficerName != null) {
      contacts.add({
        'role': 'Field Officer',
        'name': project.assignedFieldOfficerName!,
        'username': project.assignedFieldOfficerUsername ?? 'N/A',
        'userId': project.assignedFieldOfficerId!,
      });
    }
    
    if (project.assignedClientId != null && project.assignedClientName != null) {
      contacts.add({
        'role': 'Client',
        'name': project.assignedClientName!,
        'username': project.assignedClientUsername ?? 'N/A',
        'userId': project.assignedClientId!,
      });
    }
    
    if (project.assignedAgentId != null && project.assignedAgentName != null) {
      contacts.add({
        'role': 'Agent',
        'name': project.assignedAgentName!,
        'username': project.assignedAgentUsername ?? 'N/A',
        'userId': project.assignedAgentId!,
      });
    }
    
    if (project.assignedAccessorId != null && project.assignedAccessorName != null) {
      contacts.add({
        'role': 'Accessor',
        'name': project.assignedAccessorName!,
        'username': project.assignedAccessorUsername ?? 'N/A',
        'userId': project.assignedAccessorId!,
      });
    }
    
    if (project.assignedSeniorValuerId != null && project.assignedSeniorValuerName != null) {
      contacts.add({
        'role': 'Senior Valuer',
        'name': project.assignedSeniorValuerName!,
        'username': project.assignedSeniorValuerUsername ?? 'N/A',
        'userId': project.assignedSeniorValuerId!,
      });
    }

    return Scaffold(
      body: Column(
        children: [
          // Modern Header
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
                  Colors.lightBlue[500]!,
                  Colors.lightBlue[600]!,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chat with Users',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.title,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Scrollable Content
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No assigned users to chat with',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: contacts.map((contact) {
                          final roleColor = contact['role'] == 'Field Officer'
                              ? Colors.lightBlue[700]
                              : contact['role'] == 'Client'
                                  ? Colors.cyan[700]
                                  : contact['role'] == 'Agent'
                                      ? Colors.orange[700]
                                      : contact['role'] == 'Accessor'
                                          ? Colors.purple[700]
                                          : Colors.teal[700]; // Senior Valuer
                          final roleIcon = contact['role'] == 'Field Officer'
                              ? Icons.person
                              : contact['role'] == 'Client'
                                  ? Icons.business
                                  : contact['role'] == 'Agent'
                                      ? Icons.badge
                                      : contact['role'] == 'Accessor'
                                          ? Icons.assessment
                                          : Icons.verified_user; // Senior Valuer

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100]!,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(roleIcon, color: roleColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contact['role']!,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: roleColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              contact['name']!,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '@${contact['username']!}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _openChat(context, contact),
                                      icon: const Icon(Icons.chat, size: 18),
                                      label: const Text('Start Chat'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.lightBlue[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}


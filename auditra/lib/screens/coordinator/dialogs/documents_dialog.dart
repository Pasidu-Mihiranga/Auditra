import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../models/project_model.dart';
import '../../../services/api_service.dart';
import '../utils/responsive_utils.dart';

// Helper class to hold upload dialog state
class _UploadDialogState {
  int? selectedUserId;
  String? selectedUserName;
  String? selectedFile;
  String? selectedFileName;
  bool isUploading = false;
}

class DocumentsDialog extends StatefulWidget {
  final Project project;
  final VoidCallback onUpdate;

  const DocumentsDialog({
    super.key,
    required this.project,
    required this.onUpdate,
  });

  static Future<void> show(BuildContext context, Project project, VoidCallback onUpdate) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DocumentsDialog(project: project, onUpdate: onUpdate),
    );
  }

  @override
  State<DocumentsDialog> createState() => _DocumentsDialogState();
}

class _DocumentsDialogState extends State<DocumentsDialog> {
  late Project _currentProject;
  final _uploadState = _UploadDialogState();

  @override
  void initState() {
    super.initState();
    _currentProject = widget.project;
  }

  Future<void> _refreshProject() async {
    widget.onUpdate(); // Tell parent to refresh its list
    
    // Fetch latest project details for this dialog
    final result = await ApiService.getProjects();
    if (result['success']) {
       final data = result['data'] as List<dynamic>;
       final projects = data.map((p) => Project.fromJson(p)).toList();
       final updated = projects.firstWhere((p) => p.id == _currentProject.id, orElse: () => _currentProject);
       if (mounted) {
         setState(() {
           _currentProject = updated;
         });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get assigned users for this project
    final assignedUsers = <Map<String, dynamic>>[];
    
    if (_currentProject.assignedFieldOfficerId != null) {
      assignedUsers.add({
        'id': _currentProject.assignedFieldOfficerId!,
        'name': _currentProject.assignedFieldOfficerName ?? _currentProject.assignedFieldOfficerUsername ?? 'Field Officer',
        'role': 'Field Officer',
        'username': _currentProject.assignedFieldOfficerUsername ?? '',
      });
    }
    
    if (_currentProject.assignedClientId != null) {
      assignedUsers.add({
        'id': _currentProject.assignedClientId!,
        'name': _currentProject.assignedClientName ?? _currentProject.assignedClientUsername ?? 'Client',
        'role': 'Client',
        'username': _currentProject.assignedClientUsername ?? '',
      });
    }
    
    if (_currentProject.assignedAgentId != null) {
      assignedUsers.add({
        'id': _currentProject.assignedAgentId!,
        'name': _currentProject.assignedAgentName ?? _currentProject.assignedAgentUsername ?? 'Agent',
        'role': 'Agent',
        'username': _currentProject.assignedAgentUsername ?? '',
      });
    }
    
    if (_currentProject.assignedAccessorId != null) {
      assignedUsers.add({
        'id': _currentProject.assignedAccessorId!,
        'name': _currentProject.assignedAccessorName ?? _currentProject.assignedAccessorUsername ?? 'Accessor',
        'role': 'Accessor',
        'username': _currentProject.assignedAccessorUsername ?? '',
      });
    }
    
    if (_currentProject.assignedSeniorValuerId != null) {
      assignedUsers.add({
        'id': _currentProject.assignedSeniorValuerId!,
        'name': _currentProject.assignedSeniorValuerName ?? _currentProject.assignedSeniorValuerUsername ?? 'Senior Valuer',
        'role': 'Senior Valuer',
        'username': _currentProject.assignedSeniorValuerUsername ?? '',
      });
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20)),
      child: Container(
        width: screenWidth * (isSmallScreen ? 0.95 : 0.9),
        constraints: BoxConstraints(
          maxHeight: screenHeight * (isSmallScreen ? 0.9 : 0.85),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.getResponsivePadding(context)),
              decoration: BoxDecoration(
                color: const Color(0xFF0570B0),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BCDA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.attach_file, color: Colors.white, size: ResponsiveUtils.getResponsiveIconSize(context)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Documents',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentProject.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(ResponsiveUtils.getResponsivePadding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Upload Form Section
                    if (assignedUsers.isNotEmpty) ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(ResponsiveUtils.getResponsivePadding(context) * 0.8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.upload_file, color: const Color(0xFF0570B0), size: ResponsiveUtils.getResponsiveIconSize(context)),
                                  SizedBox(width: ResponsiveUtils.getResponsivePadding(context) * 0.4),
                                  Text(
                                    'Upload New Document',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: ResponsiveUtils.getResponsivePadding(context) * 0.8),
                              // Assigned Users List
                              Text(
                                'Select Assigned User:',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: ResponsiveUtils.getResponsivePadding(context) * 0.4),
                              ...assignedUsers.map((user) {
                                final nameStr = user['name'].toString();
                                final usernameStr = user['username'].toString();
                                final initials = nameStr.isNotEmpty
                                    ? nameStr.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').where((c) => c.isNotEmpty).take(2).join().toUpperCase()
                                    : usernameStr.isNotEmpty ? usernameStr.substring(0, 1).toUpperCase() : '?';
                                final isSelected = _uploadState.selectedUserId == user['id'];
                                
                                return Card(
                                  margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsivePadding(context) * 0.4),
                                  elevation: isSelected ? 4 : 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF0570B0) : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _uploadState.selectedUserId = user['id'] as int;
                                        _uploadState.selectedUserName = nameStr;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: EdgeInsets.all(ResponsiveUtils.getResponsivePadding(context) * 0.6),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: ResponsiveUtils.getResponsiveIconSize(context) * 0.8,
                                            backgroundColor: isSelected ? const Color(0xFF84BCDA) : Colors.grey[300],
                                            child: Text(
                                              initials,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.grey[700],
                                                fontWeight: FontWeight.w600,
                                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 10),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: ResponsiveUtils.getResponsivePadding(context) * 0.6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nameStr,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
                                                    color: isSelected ? const Color(0xFF0570B0) : Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  user['role'],
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, 10),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(Icons.check_circle, color: const Color(0xFF0570B0), size: ResponsiveUtils.getResponsiveIconSize(context)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              SizedBox(height: ResponsiveUtils.getResponsivePadding(context)),
                              // Show "Select File" button if user is selected but no file selected yet
                              if (_uploadState.selectedUserId != null && _uploadState.selectedFile == null) ...[
                                Container(
                                  padding: EdgeInsets.all(ResponsiveUtils.getResponsivePadding(context) * 0.8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8E7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF84BCDA), width: 2),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.check_circle, color: const Color(0xFF0570B0), size: ResponsiveUtils.getResponsiveIconSize(context)),
                                          SizedBox(width: ResponsiveUtils.getResponsivePadding(context) * 0.4),
                                          Flexible(
                                            child: Text(
                                              'Selected: ${_uploadState.selectedUserName ?? 'Unknown'}',
                                              style: TextStyle(
                                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF0A1628),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: ResponsiveUtils.getResponsivePadding(context) * 0.8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            try {
                                              final result = await FilePicker.platform.pickFiles(
                                                type: FileType.any,
                                                allowMultiple: false,
                                              );
                                              
                                              if (result != null && result.files.isNotEmpty) {
                                                final file = result.files.first;
                                                String? filePath = file.path;
                                                String? fileName = file.name;
                                                
                                                if (filePath != null && filePath.isNotEmpty) {
                                                  setState(() {
                                                    _uploadState.selectedFile = filePath;
                                                    _uploadState.selectedFileName = (fileName != null && fileName.isNotEmpty) ? fileName : 'document';
                                                  });
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Failed to get file path. Please try selecting the file again.'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Error selecting file: $e'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          icon: Icon(Icons.upload_file, size: ResponsiveUtils.getResponsiveIconSize(context) * 0.9),
                                          label: Text(
                                            'Select File',
                                            style: TextStyle(fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14), fontWeight: FontWeight.w600),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0570B0),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsivePadding(context) * 0.8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Show selected file info and upload button - ONLY inside if(assignedUsers.isNotEmpty)
                      if (_uploadState.selectedFile != null) ...[
                        const SizedBox(height: 16),
                        Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: const Color(0xFFFFF8E7),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF0570B0), size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Selected File:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _uploadState.selectedFileName ?? 'Unknown file',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0A1628),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: Colors.grey[600]),
                                    onPressed: () {
                                      setState(() {
                                        _uploadState.selectedFile = null;
                                        _uploadState.selectedFileName = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Upload Button - Prominently displayed after file selection
                          Row(
                            children: [
                              const Icon(Icons.upload, color: Color(0xFF0570B0), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Ready to Upload',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0A1628),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF0570B0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey[300]!,
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: (_uploadState.isUploading || _uploadState.selectedFile == null || _uploadState.selectedFileName == null) 
                                  ? null 
                                  : () async {
                                  setState(() => _uploadState.isUploading = true);
                                  
                                  try {
                                    final selectedFilePath = _uploadState.selectedFile;
                                    final selectedFileName = _uploadState.selectedFileName;
                                    
                                    if (selectedFilePath == null || selectedFilePath.isEmpty) {
                                      setState(() => _uploadState.isUploading = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please select a file to upload'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    
                                    final uploadResult = await ApiService.uploadProjectDocument(
                                      projectId: _currentProject.id,
                                      filePath: selectedFilePath,
                                      fileName: selectedFileName ?? 'document',
                                      assignedToId: _uploadState.selectedUserId,
                                    );
                                    
                                    if (mounted) {
                                      if (uploadResult['success']) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Document uploaded successfully${_uploadState.selectedUserName != null ? ' for ${_uploadState.selectedUserName}' : ''}!'),
                                            backgroundColor: const Color(0xFF84BCDA),
                                          ),
                                        );
                                        await _refreshProject();
                                        setState(() {
                                          _uploadState.selectedUserId = null;
                                          _uploadState.selectedUserName = null;
                                          _uploadState.selectedFile = null;
                                          _uploadState.selectedFileName = null;
                                          _uploadState.isUploading = false;
                                        });
                                      } else {
                                        setState(() => _uploadState.isUploading = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(uploadResult['message'] ?? 'Failed to upload document'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    setState(() => _uploadState.isUploading = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Upload error: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                              icon: _uploadState.isUploading 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload, size: 20),
                              label: Text(
                                _uploadState.isUploading ? 'Uploading...' : 'Upload',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ], 
                      const SizedBox(height: 20),
                    ], // End if(assignedUsers.isNotEmpty) ...[
                    
                    if (assignedUsers.isEmpty) ...[
                      // No assigned users message
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No assigned users found. Please assign users to the project first.',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Documents List
                    if (_currentProject.documents.isNotEmpty) ...[
                      const Text(
                        'Uploaded Documents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._currentProject.documents.map((doc) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.insert_drive_file,
                                color: Color(0xFF0570B0),
                                size: 24,
                              ),
                            ),
                            title: Text(
                              doc.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (doc.assignedToName != null) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Receiver: ${doc.assignedToName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Sent: ${DateFormat('MMM dd, yyyy • hh:mm a').format(doc.uploadedAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (dialogContext) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text('Delete Document'),
                                    content: Text(
                                      'Are you sure you want to delete "${doc.name}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[600],
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  final deleteResult = await ApiService.deleteProjectDocument(doc.id);
                                  if (mounted) {
                                    if (deleteResult['success']) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Document deleted successfully'),
                                          backgroundColor: Color(0xFF84BCDA),
                                        ),
                                      );
                                      await _refreshProject();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            deleteResult['message'] ?? 'Failed to delete document',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                            onTap: doc.fileUrl != null
                                ? () {} // Implementation dependent
                                : null,
                          ),
                        );
                      }),
                    ],
                    if (_currentProject.documents.isEmpty && assignedUsers.isNotEmpty) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No documents',
                                style: TextStyle(color: Colors.grey[600], fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload documents to attach them to this project',
                                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Action Buttons
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.getResponsivePadding(context)),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(isSmallScreen ? 16 : 20),
                  bottomRight: Radius.circular(isSmallScreen ? 16 : 20),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsivePadding(context) * 0.8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Close', style: TextStyle(fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

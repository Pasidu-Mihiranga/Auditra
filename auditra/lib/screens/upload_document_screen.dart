import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/project_model.dart';

class UploadDocumentScreen extends StatefulWidget {
  final Project project;
  final Function()? onDocumentUploaded;
  
  const UploadDocumentScreen({
    super.key,
    required this.project,
    this.onDocumentUploaded,
  });

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  int? selectedUserId;
  String? selectedUserName;
  String? selectedFile;
  String? selectedFileName;
  bool isUploading = false;
  Project? currentProject;

  @override
  void initState() {
    super.initState();
    currentProject = widget.project;
    _refreshProject();
  }

  Future<void> _refreshProject() async {
    final projectResult = await ApiService.getProject(widget.project.id);
    if (projectResult['success'] && projectResult['data'] != null) {
      setState(() {
        currentProject = Project.fromJson(projectResult['data']);
      });
    }
  }

  List<Map<String, dynamic>> _getAssignedUsers() {
    final assignedUsers = <Map<String, dynamic>>[];
    
    if (currentProject == null) return assignedUsers;
    
    if (currentProject!.assignedFieldOfficerId != null) {
      assignedUsers.add({
        'id': currentProject!.assignedFieldOfficerId!,
        'name': currentProject!.assignedFieldOfficerName ?? currentProject!.assignedFieldOfficerUsername ?? 'Field Officer',
        'role': 'Field Officer',
        'username': currentProject!.assignedFieldOfficerUsername ?? '',
      });
    }
    
    if (currentProject!.assignedClientId != null) {
      assignedUsers.add({
        'id': currentProject!.assignedClientId!,
        'name': currentProject!.assignedClientName ?? currentProject!.assignedClientUsername ?? 'Client',
        'role': 'Client',
        'username': currentProject!.assignedClientUsername ?? '',
      });
    }
    
    if (currentProject!.assignedAgentId != null) {
      assignedUsers.add({
        'id': currentProject!.assignedAgentId!,
        'name': currentProject!.assignedAgentName ?? currentProject!.assignedAgentUsername ?? 'Agent',
        'role': 'Agent',
        'username': currentProject!.assignedAgentUsername ?? '',
      });
    }
    
    if (currentProject!.assignedAccessorId != null) {
      assignedUsers.add({
        'id': currentProject!.assignedAccessorId!,
        'name': currentProject!.assignedAccessorName ?? currentProject!.assignedAccessorUsername ?? 'Accessor',
        'role': 'Accessor',
        'username': currentProject!.assignedAccessorUsername ?? '',
      });
    }
    
    if (currentProject!.assignedSeniorValuerId != null) {
      assignedUsers.add({
        'id': currentProject!.assignedSeniorValuerId!,
        'name': currentProject!.assignedSeniorValuerName ?? currentProject!.assignedSeniorValuerUsername ?? 'Senior Valuer',
        'role': 'Senior Valuer',
        'username': currentProject!.assignedSeniorValuerUsername ?? '',
      });
    }
    
    return assignedUsers;
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String? filePath;
        String? fileName;
        
        try {
          filePath = file.path;
        } catch (e) {
          filePath = null;
        }
        
        try {
          fileName = file.name;
        } catch (e) {
          fileName = null;
        }
        
        if (filePath != null && filePath.isNotEmpty) {
          setState(() {
            selectedFile = filePath;
            selectedFileName = (fileName != null && fileName.isNotEmpty) ? fileName : 'document';
          });
        } else {
          if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadDocument() async {
    if (selectedFile == null || selectedFileName == null || selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a user and file to upload'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      final uploadResult = await ApiService.uploadProjectDocument(
        projectId: currentProject!.id,
        filePath: selectedFile!,
        fileName: selectedFileName!,
        assignedToId: selectedUserId,
      );

      if (mounted) {
        if (uploadResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document uploaded successfully${selectedUserName != null ? ' for $selectedUserName' : ''}!'),
              backgroundColor: Colors.green,
            ),
          );
          await _refreshProject();
          setState(() {
            selectedUserId = null;
            selectedUserName = null;
            selectedFile = null;
            selectedFileName = null;
            isUploading = false;
          });
          if (widget.onDocumentUploaded != null) {
            widget.onDocumentUploaded!();
          }
        } else {
          setState(() => isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uploadResult['message'] ?? 'Failed to upload document',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upload error: ${e.toString()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(int documentId, String documentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "$documentName"?'),
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
      final deleteResult = await ApiService.deleteProjectDocument(documentId);
      if (mounted) {
        if (deleteResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await _refreshProject();
          if (widget.onDocumentUploaded != null) {
            widget.onDocumentUploaded!();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(deleteResult['message'] ?? 'Failed to delete document'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignedUsers = _getAssignedUsers();
    
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
                colors: [Colors.teal[500]!, Colors.teal[500]!.withOpacity(0.7)],
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
                    color: Colors.teal[400]!,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.attach_file, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Documents',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentProject?.title ?? widget.project.title,
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
          // Content
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(10),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload Form Section
                    if (assignedUsers.isNotEmpty) ...[
                      Card(
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
                                  Icon(Icons.upload_file, color: Colors.teal[700], size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Upload New Document',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Select Assigned User:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...assignedUsers.map((user) {
                                final nameStr = user['name'].toString();
                                final usernameStr = user['username'].toString();
                                final initials = nameStr.isNotEmpty
                                    ? nameStr.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').where((c) => c.isNotEmpty).take(2).join().toUpperCase()
                                    : usernameStr.isNotEmpty ? usernameStr.substring(0, 1).toUpperCase() : '?';
                                final isSelected = selectedUserId == user['id'];
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: isSelected ? 4 : 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected ? Colors.teal[600]! : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        selectedUserId = user['id'] as int;
                                        selectedUserName = nameStr;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: isSelected ? Colors.teal[400] : Colors.grey[300],
                                            child: Text(
                                              initials,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.grey[700],
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nameStr,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                    color: isSelected ? Colors.teal[700] : Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  user['role'],
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(Icons.check_circle, color: Colors.teal[600], size: 24),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                              // Show "Select File" button if user is selected but no file selected yet
                              if (selectedUserId != null && selectedFile == null) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.teal[200]!, width: 2),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.teal[700], size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Selected: ${selectedUserName ?? 'Unknown'}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.teal[800],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _selectFile,
                                          icon: const Icon(Icons.upload_file, size: 20),
                                          label: const Text(
                                            'Select File',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal[600],
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            elevation: 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // Show selected file info and upload button
                              if (selectedFile != null) ...[
                                Card(
                                  margin: const EdgeInsets.only(top: 16, bottom: 16),
                                  color: Colors.green[50],
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green[700], size: 28),
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
                                                selectedFileName ?? 'Unknown file',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green[900],
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
                                              selectedFile = null;
                                              selectedFileName = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Upload Button
                                Row(
                                  children: [
                                    Icon(Icons.upload, color: Colors.green[700], size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Ready to Upload',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.green[600]!,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey[300]!,
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: (isUploading || selectedFile == null || selectedFileName == null) 
                                        ? null 
                                        : _uploadDocument,
                                    icon: isUploading 
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
                                      isUploading ? 'Uploading...' : 'Upload',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (assignedUsers.isEmpty) ...[
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
                    if (currentProject != null && currentProject!.documents.isNotEmpty) ...[
                      const Text(
                        'Uploaded Documents',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...currentProject!.documents.map((doc) {
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
                                color: Colors.teal[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.insert_drive_file,
                                color: Colors.teal[700],
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
                              onPressed: () => _deleteDocument(doc.id, doc.name),
                            ),
                          ),
                        );
                      }),
                    ],
                    if (currentProject != null && currentProject!.documents.isEmpty && assignedUsers.isNotEmpty) ...[
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
          ),
        ],
      ),
    );
  }
}


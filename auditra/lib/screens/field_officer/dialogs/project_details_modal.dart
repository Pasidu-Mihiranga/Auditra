import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../../theme/app_colors.dart'; 
import '../../../widgets/shared_dashboard_widgets.dart'; 
import '../utils/field_officer_document_manager.dart';

class ProjectDetailsModal extends StatefulWidget {
  final Project project;

  const ProjectDetailsModal({
    super.key,
    required this.project,
  });

  @override
  State<ProjectDetailsModal> createState() => _ProjectDetailsModalState();
}

class _ProjectDetailsModalState extends State<ProjectDetailsModal> {
  late FieldOfficerDocumentManager _documentManager;

  @override
  void initState() {
    super.initState();
    _documentManager = FieldOfficerDocumentManager(
      context: context,
      setState: setState,
    );
  }

  String _formatPriorityLabel(String priority) {
    if (priority.isEmpty) return 'Medium';
    return priority[0].toUpperCase() + priority.substring(1).toLowerCase();
  }

  Widget _buildModernInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20)),
      child: Container(
        width: screenWidth * (isSmallScreen ? 0.95 : 0.9),
        constraints: BoxConstraints(
          maxHeight: screenHeight * (isSmallScreen ? 0.9 : 0.85),
          maxWidth: 800,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with green/blue gradient
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0570B0)!, const Color(0xFF84BCDA)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_open, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          project.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            project.statusDisplay,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (project.description != null) ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.description, color: Colors.blue[700], size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                project.description!,
                                style: TextStyle(color: Colors.grey[800], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Priority and Coordinator
                    Row(children: [
                      Expanded(child: _buildModernInfoCard(
                        icon: Icons.flag,
                        label: 'Priority',
                        value: _formatPriorityLabel(project.priority ?? 'medium'),
                        color: DashboardColors.getPriorityColor(project.priority ?? 'medium'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildModernInfoCard(
                        icon: Icons.person,
                        label: 'Coordinator',
                        value: project.coordinatorName ?? project.coordinatorUsername,
                        color: Colors.blue,
                      )),
                    ]),
                    
                    // Documents Section
                    if (project.documents.isNotEmpty) ...[
                       const SizedBox(height: 24),
                       Card(
                         elevation: 2,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         child: Padding(
                           padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 children: [
                                   Icon(Icons.insert_drive_file, color: Colors.blue[700], size: 20),
                                   const SizedBox(width: 8),
                                   Text(
                                     'Documents (${project.documents.length})',
                                     style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                     ),
                                   ),
                                 ],
                               ),
                               const SizedBox(height: 12),
                               ...project.documents.map((doc) => Padding(
                                     padding: const EdgeInsets.only(bottom: 8),
                                     child: ListTile(
                                       contentPadding: EdgeInsets.zero,
                                       leading: Container(
                                         padding: const EdgeInsets.all(8),
                                         decoration: BoxDecoration(
                                           color: Colors.grey[100],
                                           borderRadius: BorderRadius.circular(8),
                                         ),
                                         child: const Icon(Icons.insert_drive_file, color: Colors.grey, size: 20),
                                       ),
                                       title: Text(
                                         doc.name,
                                         style: const TextStyle(fontWeight: FontWeight.w500),
                                       ),
                                       subtitle: Text(
                                         doc.fileSizeFormatted,
                                         style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                       ),
                                       trailing: doc.fileUrl != null
                                           ? FutureBuilder<bool>(
                                               key: ValueKey('doc_${doc.id}_${_documentManager.downloadedDocuments.contains(doc.id)}'),
                                               future: _documentManager.isDocumentDownloaded(doc.id),
                                               builder: (context, snapshot) {
                                                 final isDownloaded = snapshot.data ?? false;
                                                 return IconButton(
                                                   icon: Icon(
                                                     isDownloaded ? Icons.visibility : Icons.download,
                                                     size: 20,
                                                   ),
                                                   color: Colors.blue[700],
                                                   tooltip: isDownloaded ? 'View Document' : 'Download Document',
                                                   onPressed: () async {
                                                     if (isDownloaded) {
                                                       final filePath = await _documentManager.getLocalFilePath(doc.id);
                                                       if (filePath != null) {
                                                         await _documentManager.viewDownloadedDocument(filePath);
                                                       }
                                                     } else {
                                                       await _documentManager.downloadDocument(doc);
                                                     }
                                                   },
                                                 );
                                               },
                                             )
                                           : null,
                                     ),
                                   )),
                              ],
                           ),
                         ),
                       ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

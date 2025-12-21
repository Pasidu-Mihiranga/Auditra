import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../models/project_model.dart';
import '../models/valuation_model.dart';

class ViewProjectDetailsScreen extends StatefulWidget {
  final Project project;
  final bool isCoordinator;
  final VoidCallback? onProjectUpdated;
  
  const ViewProjectDetailsScreen({
    super.key,
    required this.project,
    this.isCoordinator = false,
    this.onProjectUpdated,
  });

  @override
  State<ViewProjectDetailsScreen> createState() => _ViewProjectDetailsScreenState();
}

class _ViewProjectDetailsScreenState extends State<ViewProjectDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Project? _currentProject;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentProject = widget.project;
    _loadProjectDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectDetails() async {
    setState(() => _isLoading = true);
    
    final projectResult = await ApiService.getProject(widget.project.id);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (projectResult['success'] && projectResult['data'] != null) {
          try {
            _currentProject = Project.fromJson(projectResult['data']);
          } catch (e) {
            print('Error parsing updated project: $e');
            _currentProject = widget.project;
          }
        } else {
          _currentProject = widget.project;
        }
      });
    }
  }

  String _buildDatesText(Project project) {
    final parts = <String>[];
    if (project.startDate != null) {
      parts.add('Start: ${DateFormat('MMM dd, yyyy').format(project.startDate!)}');
    }
    if (project.endDate != null) {
      parts.add('End: ${DateFormat('MMM dd, yyyy').format(project.endDate!)}');
    }
    return parts.join('\n');
  }
  
  String _buildAssignedUsersText(Project project) {
    final parts = <String>[];
    if (project.assignedFieldOfficerName != null) {
      parts.add('Field Officer: ${project.assignedFieldOfficerName}');
    } else {
      parts.add('Field Officer: Not assigned');
    }
    if (project.assignedClientName != null) {
      parts.add('Client: ${project.assignedClientName}');
    } else {
      parts.add('Client: Not assigned');
    }
    if (project.hasAgent && project.assignedAgentName != null) {
      parts.add('Agent: ${project.assignedAgentName}');
    }
    if (project.assignedAccessorName != null) {
      parts.add('Accessor: ${project.assignedAccessorName}');
    }
    if (project.assignedSeniorValuerName != null) {
      parts.add('Senior Valuer: ${project.assignedSeniorValuerName}');
    }
    return parts.join('\n');
  }

  Color _getProjectStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[600]!;
      case 'in_progress':
        return Colors.blue[600]!;
      case 'completed':
        return Colors.green[600]!;
      case 'cancelled':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red[600]!;
      case 'low':
        return Colors.green[600]!;
      case 'medium':
      default:
        return Colors.orange[600]!;
    }
  }

  String _formatPriorityLabel(String priority) {
    if (priority.isEmpty) return 'Medium';
    final lower = priority.toLowerCase();
    if (lower == 'high') return 'High';
    if (lower == 'low') return 'Low';
    return 'Medium';
  }

  Color _getValuationStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey[600]!;
      case 'submitted':
        return Colors.blue[600]!;
      case 'reviewed':
        return Colors.purple[600]!;
      case 'approved':
        return Colors.green[600]!;
      case 'rejected':
        return Colors.red[600]!;
      default:
        return Colors.grey[400]!;
    }
  }

  Future<void> _generatePdfReport(Valuation valuation, Project project) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating PDF report...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Ensure dialog is rendered before starting PDF generation
    await Future.delayed(Duration.zero);

    try {
      // Generate PDF
      final pdfFile = await PdfService.generateValuationReport(
        valuation: valuation,
        project: project,
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Share/Print the PDF
      if (context.mounted) {
        try {
          await PdfService.sharePdf(
            pdfFile,
            subject: 'Valuation Report - ${valuation.categoryDisplay}',
          );
        } catch (shareError) {
          print('Error sharing PDF: $shareError');
          // Try alternative method
          if (context.mounted) {
            await PdfService.saveAndOpenPdf(pdfFile);
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error generating PDF: $e');
    }
  }

  Widget _buildModernInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isMultiLine = false,
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
              maxLines: isMultiLine ? null : 1,
              overflow: isMultiLine ? null : TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _currentProject ?? widget.project;
    final primaryColor = widget.isCoordinator ? Colors.blue : Colors.purple;
    final primaryColorShade = widget.isCoordinator ? Colors.blue[600]! : Colors.purple[600]!;
    final primaryColorLight = widget.isCoordinator ? Colors.blue[50]! : Colors.purple[50]!;
    final primaryColorLighter = widget.isCoordinator ? Colors.blue[100]! : Colors.purple[100]!;
    final primaryColorDark = widget.isCoordinator ? Colors.blue[700]! : Colors.purple[700]!;

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
                  primaryColor[500]!,
                  primaryColorShade,
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
                  child: const Icon(Icons.folder_open, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Details',
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
          // Tab Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: primaryColorLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: primaryColorDark,
              unselectedLabelColor: Colors.grey[600],
              tabAlignment: TabAlignment.fill,
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Reports'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Details Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description Card
                            if (project.description != null) ...[
                              _buildModernInfoCard(
                                icon: Icons.description,
                                label: 'Description',
                                value: project.description!,
                                color: primaryColorDark,
                                isMultiLine: true,
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Priority Card
                            _buildModernInfoCard(
                              icon: Icons.flag,
                              label: 'Priority',
                              value: _formatPriorityLabel(project.priority ?? 'medium'),
                              color: _getPriorityColor(project.priority ?? 'medium'),
                            ),
                            const SizedBox(height: 12),
                            // Coordinator Card
                            _buildModernInfoCard(
                              icon: Icons.person,
                              label: 'Coordinator',
                              value: project.coordinatorName ?? project.coordinatorUsername ?? 'Not assigned',
                              color: primaryColorDark,
                            ),
                            // Dates
                            if (project.startDate != null || project.endDate != null) ...[
                              const SizedBox(height: 12),
                              _buildModernInfoCard(
                                icon: Icons.calendar_today,
                                label: 'Project Dates',
                                value: _buildDatesText(project),
                                color: primaryColorDark,
                                isMultiLine: true,
                              ),
                            ],
                            // Assigned Users
                            const SizedBox(height: 12),
                            _buildModernInfoCard(
                              icon: Icons.people_outline,
                              label: 'Assigned Users',
                              value: _buildAssignedUsersText(project),
                              color: primaryColorDark,
                              isMultiLine: true,
                            ),
                            // Documents (only for coordinator)
                            if (widget.isCoordinator && project.documents.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.folder_outlined, color: primaryColorDark, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Documents (${project.documents.length})',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
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
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20),
                                            color: Colors.red[700],
                                            onPressed: () async {
                                              final deleteResult = await ApiService.deleteProjectDocument(doc.id);
                                              if (deleteResult['success']) {
                                                if (widget.onProjectUpdated != null) {
                                                  widget.onProjectUpdated!();
                                                }
                                                await _loadProjectDetails();
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Document deleted'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
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
                      // Reports Tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: primaryColorLight,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: primaryColorLighter,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.assessment, color: primaryColorDark, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Valuation Reports',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: primaryColorDark,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            '${project.valuations.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  if (project.valuations.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.description_outlined, size: 48, color: Colors.grey[400]),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No reports available',
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
                                  else
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: project.valuations
                                            .where((v) => v.status != 'draft') // Only show submitted/reviewed reports
                                            .map((valuation) => Padding(
                                                  padding: const EdgeInsets.only(bottom: 12),
                                                  child: Card(
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
                                                                width: 48,
                                                                height: 48,
                                                                decoration: BoxDecoration(
                                                                  color: _getValuationStatusColor(valuation.status).withOpacity(0.15),
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Center(
                                                                  child: Icon(
                                                                    Icons.description,
                                                                    color: _getValuationStatusColor(valuation.status),
                                                                    size: 24,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 12),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      valuation.categoryDisplay,
                                                                      style: const TextStyle(
                                                                        fontWeight: FontWeight.w600,
                                                                        fontSize: 16,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 6),
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal: 10,
                                                                        vertical: 4,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: _getValuationStatusColor(valuation.status).withOpacity(0.2),
                                                                        borderRadius: BorderRadius.circular(6),
                                                                      ),
                                                                      child: Text(
                                                                        valuation.status == 'draft' ? 'Saved' : valuation.statusDisplay,
                                                                        style: TextStyle(
                                                                          fontSize: 12,
                                                                          fontWeight: FontWeight.w500,
                                                                          color: _getValuationStatusColor(valuation.status),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 12),
                                                          Row(
                                                            children: [
                                                              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                                              const SizedBox(width: 6),
                                                              Text(
                                                                'Created: ${DateFormat('MMM dd, yyyy').format(valuation.createdAt)}',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.grey[600],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 12),
                                                          // PDF Download Button
                                                          SizedBox(
                                                            width: double.infinity,
                                                            child: ElevatedButton.icon(
                                                              onPressed: () async {
                                                                await _generatePdfReport(valuation, project);
                                                              },
                                                              icon: const Icon(Icons.article, size: 20),
                                                              label: const Text('View PDF Report'),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.orange[700],
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
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}


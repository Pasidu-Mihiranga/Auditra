import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/project_model.dart';
import '../../../models/valuation_model.dart';
import '../../../services/api_service.dart';
import '../../valuation_form_screen.dart';
import '../../coordinator/utils/project_report_handler.dart';
import '../utils/field_officer_document_manager.dart';
import '../utils/field_officer_ui_helpers.dart';

class ValuationReportsModal extends StatefulWidget {
  final Project project;
  final VoidCallback? onProjectUpdated;

  const ValuationReportsModal({
    super.key,
    required this.project,
    this.onProjectUpdated,
  });

  @override
  State<ValuationReportsModal> createState() => _ValuationReportsModalState();
}

class _ValuationReportsModalState extends State<ValuationReportsModal> {
  late FieldOfficerDocumentManager _documentManager;
  Project? _currentProject;

  @override
  void initState() {
    super.initState();
    _currentProject = widget.project;
    _documentManager = FieldOfficerDocumentManager(
      context: context,
      setState: setState,
    );
  }

  Future<void> _deleteValuation(Valuation valuation) async {
    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to delete this ${valuation.categoryDisplay} report? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading indicator
    if (mounted) {
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
                  Text('Deleting report...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      // Delete from server
      final result = await ApiService.deleteValuation(valuation.id);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: Color(0xFF84BCDA),
            ),
          );
          
          // Refresh callback to parent
          widget.onProjectUpdated?.call();
          
          // Either close modal or refresh local data ??
          // Since parent refreshes, maybe we should close modal?
          // Existing behavior seemed to close modal in some paths, but let's close it to be safe and simple.
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete report'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
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
    if (_currentProject == null) return const SizedBox();
    final project = _currentProject!;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[800]!, Colors.blue[600]!],
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assessment, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valuation Reports',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.title,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
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
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Generated Reports Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
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
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.assessment, color: Colors.blue[700], size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Generated Reports',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[700],
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
                                      'No reports generated yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Create a valuation report to get started',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                              child: Column(
                                children: project.valuations.map((valuation) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 48,
                                                height: 48,
                                                decoration: BoxDecoration(
                                                  color: FieldOfficerUiHelpers.getValuationStatusColor(valuation.status).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.description,
                                                    color: FieldOfficerUiHelpers.getValuationStatusColor(valuation.status),
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
                                                        color: FieldOfficerUiHelpers.getValuationStatusColor(valuation.status).withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        valuation.status == 'draft' ? 'Saved' : valuation.statusDisplay,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: FieldOfficerUiHelpers.getValuationStatusColor(valuation.status),
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
                                          // Action buttons row
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.orange[50],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(Icons.article, size: 20),
                                                  color: Colors.orange[700],
                                                  tooltip: 'Generate PDF Report',
                                                  padding: const EdgeInsets.all(8),
                                                  constraints: const BoxConstraints(
                                                    minWidth: 40,
                                                    minHeight: 40,
                                                  ),
                                                  onPressed: () async {
                                                    await ProjectReportHandler.generatePdfReport(context, valuation, project);
                                                  },
                                                ),
                                              ),
                                              // Show edit button if valuation can be edited
                                              if (FieldOfficerUiHelpers.canEditValuation(valuation)) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                                    color: Colors.blue[700],
                                                    tooltip: 'Edit Report',
                                                    padding: const EdgeInsets.all(8),
                                                    constraints: const BoxConstraints(
                                                      minWidth: 40,
                                                      minHeight: 40,
                                                    ),
                                                    onPressed: () async {
                                                      Navigator.of(context).pop();
                                                      final result = await Navigator.of(context).push(
                                                        MaterialPageRoute(
                                                          builder: (_) => ValuationFormScreen(
                                                            project: project,
                                                            existingValuation: valuation,
                                                          ),
                                                        ),
                                                      );
                                                      // Refresh projects callback
                                                      if (result == true) {
                                                        widget.onProjectUpdated?.call();
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ],
                                              // Show delete button
                                              if (FieldOfficerUiHelpers.canDeleteValuation(valuation)) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.red[50],
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 20),
                                                    color: Colors.red[700],
                                                    tooltip: 'Delete Report',
                                                    padding: const EdgeInsets.all(8),
                                                    constraints: const BoxConstraints(
                                                      minWidth: 40,
                                                      minHeight: 40,
                                                    ),
                                                    onPressed: () async {
                                                      await _deleteValuation(valuation);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),
                          

                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer Actions
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ValuationFormScreen(project: project),
                      ),
                    );
                    // Refresh projects callback
                    if (result == true) {
                      widget.onProjectUpdated?.call();
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add_rounded, size: 20),
                  ),
                  label: const Text(
                    'Create New Report',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

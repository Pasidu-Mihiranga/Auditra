
import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../coordinator/styles/coordinator_styles.dart';
import '../../../services/api_service.dart';

class StatusUpdateDialog extends StatefulWidget {
  final Project project;
  final VoidCallback onStatusUpdated;

  const StatusUpdateDialog({
    Key? key,
    required this.project,
    required this.onStatusUpdated,
  }) : super(key: key);

  static Future<void> show(BuildContext context, Project project, VoidCallback onStatusUpdated) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatusUpdateDialog(
        project: project,
        onStatusUpdated: onStatusUpdated,
      ),
    );
  }

  @override
  _StatusUpdateDialogState createState() => _StatusUpdateDialogState();
}

class _StatusUpdateDialogState extends State<StatusUpdateDialog> {
  String? _selectedWorkflowStage;
  
  // Define workflow stages locally since we couldn't find them globally
  final List<Map<String, dynamic>> _workflowStages = [
    {'id': 'created', 'label': 'Project Created', 'icon': Icons.add_circle_outline},
    {'id': 'field_officer_assigned', 'label': 'Field Officer Assigned', 'icon': Icons.person_outline},
    {'id': 'site_visit_scheduled', 'label': 'Site Visit Scheduled', 'icon': Icons.calendar_today},
    {'id': 'site_visit_completed', 'label': 'Site Visit Completed', 'icon': Icons.check_circle_outline},
    {'id': 'report_drafted', 'label': 'Report Drafted', 'icon': Icons.article_outlined},
    {'id': 'report_reviewed', 'label': 'Report Reviewed', 'icon': Icons.rate_review_outlined},
    {'id': 'final_report_generated', 'label': 'Final Report Generated', 'icon': Icons.file_present},
    {'id': 'completed', 'label': 'Project Completed', 'icon': Icons.done_all},
  ];

  @override
  void initState() {
    super.initState();
    _initStage();
  }

  void _initStage() {
    // Check if all stages are completed
    final projectCurrentStageIndex = widget.project.workflowStage != null 
        ? _workflowStages.indexWhere((s) => s['id'] == widget.project.workflowStage)
        : -1;
    final allStagesCompleted = projectCurrentStageIndex == _workflowStages.length - 1;
    
    // If all stages are completed, don't select anything initially
    _selectedWorkflowStage = allStagesCompleted ? null : widget.project.workflowStage;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[500]!,
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
                      color: Colors.blue[400]!,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_tree, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Project Workflow',
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
            // Content
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project title
                      Text(
                        widget.project.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Current status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Project Status: ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Chip(
                              label: Text(widget.project.statusDisplay),
                              backgroundColor: CoordinatorStyles.getProjectStatusColor(widget.project.status),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Workflow tree title
                      const Text(
                        'Workflow Stages:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Workflow tree
                      _buildWorkflowTree(),
                    ],
                  ),
                ),
              ),
            ),
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowTree() {
    // Calculate if all stages are completed
    final projectCurrentStageIndex = widget.project.workflowStage != null 
        ? _workflowStages.indexWhere((s) => s['id'] == widget.project.workflowStage)
        : -1;
    final allStagesCompleted = projectCurrentStageIndex == _workflowStages.length - 1;
    
    // Calculate if selected stage is a completed (past) stage
    final selectedStageIndex = _selectedWorkflowStage != null
        ? _workflowStages.indexWhere((s) => s['id'] == _selectedWorkflowStage)
        : -1;
    
    return Column(
      children: [
        ..._workflowStages.asMap().entries.map((entry) {
          final index = entry.key;
          final stage = entry.value;
          final isSelected = _selectedWorkflowStage == stage['id'];
          // A stage is completed if:
          // 1. The project has moved past it (projectCurrentStageIndex > index), OR
          // 2. It's the final stage and the project is currently at it (all stages completed)
          final isCompleted = projectCurrentStageIndex > index || 
              (projectCurrentStageIndex == index && projectCurrentStageIndex == _workflowStages.length - 1);
          final isCurrent = widget.project.workflowStage == stage['id'];
          // Check if this is the final stage and all stages are completed
          final isFinalStageCompleted = index == _workflowStages.length - 1 && allStagesCompleted;
          
          return Column(
            children: [
              _buildWorkflowStageItem(
                context,
                stage: stage,
                index: index + 1,
                isSelected: isSelected,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isFinalStageCompleted: isFinalStageCompleted,
                allStagesCompleted: allStagesCompleted,
                onTap: () {
                  setState(() {
                    // If all stages are completed and final stage is selected, deselect it
                    if (allStagesCompleted && isFinalStageCompleted && isSelected) {
                      _selectedWorkflowStage = null;
                    } else {
                      _selectedWorkflowStage = stage['id'];
                    }
                  });
                },
              ),
              if (index < _workflowStages.length - 1)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  width: 2,
                  height: 30,
                  color: isCompleted ? Colors.blue[400] : Colors.grey[300],
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildWorkflowStageItem(
    BuildContext context, {
    required Map<String, dynamic> stage,
    required int index,
    required bool isSelected,
    required bool isCompleted,
    required bool isCurrent,
    required bool isFinalStageCompleted,
    required bool allStagesCompleted,
    required VoidCallback onTap,
  }) {
    Color stageColor;
    IconData stageIcon;
    
    // When all stages are completed OR this is the final completed stage, show original icons (no checkmarks)
    if (allStagesCompleted || isFinalStageCompleted) {
      stageColor = Colors.blue[600]!;
      stageIcon = stage['icon'] as IconData;
    } else if (isCompleted) {
      // Show checkmark for completed stages when not all stages are completed
      stageColor = Colors.blue[600]!;
      stageIcon = Icons.check_circle;
    } else if (isCurrent) {
      stageColor = Colors.blue[600]!;
      stageIcon = Icons.radio_button_checked;
    } else {
      stageColor = Colors.grey[400]!;
      stageIcon = stage['icon'] as IconData;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? stageColor.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? stageColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Stage number and icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent ? stageColor : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                stageIcon,
                color: isCompleted || isCurrent ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Stage label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Stage $index',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCompleted || isCurrent ? stageColor : Colors.grey[600],
                        ),
                      ),
                      // Show "Current" tag only if not completed
                      if (isCurrent && !isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: stageColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      // Show "Completed" tag if completed (this takes priority over "Current")
                      if (isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage['label'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isCompleted || isCurrent ? Colors.black87 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator - hide when all stages are completed
            if (isSelected && !allStagesCompleted)
              Icon(
                Icons.check_circle,
                color: stageColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Builder(
        builder: (context) {
          final projectCurrentStageIndex = widget.project.workflowStage != null 
              ? _workflowStages.indexWhere((s) => s['id'] == widget.project.workflowStage)
              : -1;
          final allStagesCompleted = projectCurrentStageIndex == _workflowStages.length - 1;
          
          final selectedStageIndex = _selectedWorkflowStage != null
              ? _workflowStages.indexWhere((s) => s['id'] == _selectedWorkflowStage)
              : -1;
          final isSelectedStageCompleted = projectCurrentStageIndex > selectedStageIndex && selectedStageIndex != -1;
          final isButtonEnabled = _selectedWorkflowStage != null && !isSelectedStageCompleted;
          
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
              ),
              // Only show spacing and button if not all stages are completed
              if (!allStagesCompleted) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isButtonEnabled
                        ? () async {
                            Navigator.of(context).pop();
                            await _updateWorkflowStage(widget.project, _selectedWorkflowStage);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save, size: 18),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Update Workflow',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateWorkflowStage(Project project, String? workflowStage) async {
    final result = await ApiService.updateProjectWorkflowStage(
      projectId: project.id,
      workflowStage: workflowStage,
    );

    if (mounted) {
      if (result['success']) {
        // Check if the updated stage is the last stage (all stages completed)
        final lastStageId = _workflowStages.last['id'];
        final allStagesCompleted = workflowStage == lastStageId;
        
        if (allStagesCompleted) {
          // Show completion message dialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.blue[600],
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      'All Workflow Stages Completed!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Message
                    Text(
                      'All workflow stages have been completed successfully.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // OK button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          // Show regular success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workflow stage updated successfully!'),
              backgroundColor: Color(0xFF84BCDA),
            ),
          );
        }
        widget.onStatusUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update workflow stage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

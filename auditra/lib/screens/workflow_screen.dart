import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../services/api_service.dart';

class WorkflowScreen extends StatefulWidget {
  final Project project;
  final Function()? onWorkflowUpdated;

  const WorkflowScreen({
    super.key,
    required this.project,
    this.onWorkflowUpdated,
  });

  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen> {
  // Workflow stages
  static const List<Map<String, dynamic>> workflowStages = [
    {
      'id': 'field_officer_receives',
      'label': 'Field Officer Receives Assignment',
      'icon': Icons.person_outline,
      'order': 1,
    },
    {
      'id': 'performs_field_work',
      'label': 'Performs Field Work',
      'icon': Icons.work_outline,
      'order': 2,
    },
    {
      'id': 'submit_draft_report',
      'label': 'Submit Draft Report',
      'icon': Icons.description_outlined,
      'order': 3,
    },
    {
      'id': 'accessor_reviews',
      'label': 'Accessor Reviews Report',
      'icon': Icons.rate_review_outlined,
      'order': 4,
    },
    {
      'id': 'senior_valuer_reviews',
      'label': 'Senior Valuer Reviews Report',
      'icon': Icons.verified_user_outlined,
      'order': 5,
    },
    {
      'id': 'mg_gm_approves',
      'label': 'MG/GM Approves Report',
      'icon': Icons.approval_outlined,
      'order': 6,
    },
  ];

  Project? currentProject;
  String? selectedWorkflowStage;

  @override
  void initState() {
    super.initState();
    currentProject = widget.project;
    // Check if all stages are completed
    final projectCurrentStageIndex = currentProject!.workflowStage != null
        ? workflowStages.indexWhere((s) => s['id'] == currentProject!.workflowStage)
        : -1;
    final allStagesCompleted = projectCurrentStageIndex == workflowStages.length - 1;
    // If all stages are completed, don't select anything initially
    selectedWorkflowStage = allStagesCompleted ? null : currentProject!.workflowStage;
  }

  Color _getProjectStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange[300]!;
      case 'in_progress':
        return Colors.blue[300]!;
      case 'completed':
        return Colors.green[300]!;
      case 'cancelled':
        return Colors.red[300]!;
      default:
        return Colors.grey[300]!;
    }
  }

  Future<void> _updateWorkflowStage() async {
    final result = await ApiService.updateProjectWorkflowStage(
      projectId: currentProject!.id,
      workflowStage: selectedWorkflowStage,
    );

    if (mounted) {
      if (result['success']) {
        // Check if the updated stage is the last stage (all stages completed)
        final lastStageId = workflowStages.last['id'];
        final allStagesCompleted = selectedWorkflowStage == lastStageId;

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
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Close workflow screen
                          if (widget.onWorkflowUpdated != null) {
                            widget.onWorkflowUpdated!();
                          }
                        },
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
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
          if (widget.onWorkflowUpdated != null) {
            widget.onWorkflowUpdated!();
          }
        }
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

  Widget _buildWorkflowStage({
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

  @override
  Widget build(BuildContext context) {
    // Calculate if all stages are completed
    final projectCurrentStageIndex = currentProject!.workflowStage != null
        ? workflowStages.indexWhere((s) => s['id'] == currentProject!.workflowStage)
        : -1;
    final allStagesCompleted = projectCurrentStageIndex == workflowStages.length - 1;

    // Calculate if selected stage is a completed (past) stage
    final selectedStageIndex = selectedWorkflowStage != null
        ? workflowStages.indexWhere((s) => s['id'] == selectedWorkflowStage)
        : -1;
    final isSelectedStageCompleted = projectCurrentStageIndex > selectedStageIndex && selectedStageIndex != -1;
    final isButtonEnabled = selectedWorkflowStage != null && !isSelectedStageCompleted;

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
                  child: const Icon(Icons.account_tree, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Workflow',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentProject!.title,
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
                            label: Text(currentProject!.statusDisplay),
                            backgroundColor: _getProjectStatusColor(currentProject!.status),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Workflow tree
                    Column(
                      children: [
                        ...workflowStages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final stage = entry.value;
                          final isSelected = selectedWorkflowStage == stage['id'];
                          // A stage is completed if:
                          // 1. The project has moved past it (projectCurrentStageIndex > index), OR
                          // 2. It's the final stage and the project is currently at it (all stages completed)
                          final isCompleted = projectCurrentStageIndex > index ||
                              (projectCurrentStageIndex == index && projectCurrentStageIndex == workflowStages.length - 1);
                          final isCurrent = currentProject!.workflowStage == stage['id'];
                          // Check if this is the final stage and all stages are completed
                          final isFinalStageCompleted = index == workflowStages.length - 1 && allStagesCompleted;

                          return Column(
                            children: [
                              _buildWorkflowStage(
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
                                      selectedWorkflowStage = null;
                                    } else {
                                      selectedWorkflowStage = stage['id'];
                                    }
                                  });
                                },
                              ),
                              if (index < workflowStages.length - 1)
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
                    ),
                    // Action Button
                    if (!allStagesCompleted) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isButtonEnabled ? _updateWorkflowStage : null,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



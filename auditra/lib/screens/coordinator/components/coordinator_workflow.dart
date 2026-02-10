import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../../services/api_service.dart';

/// Workflow management for Coordinator Dashboard
/// Handles workflow stage updates and UI builders
class CoordinatorWorkflow {
  
  /// Workflow stages constant
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

  /// Update workflow stage for a project
  static Future<void> updateWorkflowStage(
    BuildContext context,
    Project project,
    String? workflowStage,
    VoidCallback onUpdate,
  ) async {
    final result = await ApiService.updateProjectWorkflowStage(
      projectId: project.id,
      workflowStage: workflowStage,
    );

    if (!context.mounted) return;

    if (result['success']) {
      // Check if the updated stage is the last stage (all stages completed)
      final lastStageId = workflowStages.last['id'];
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
      onUpdate();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to update workflow stage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Build a workflow stage widget
  static Widget buildWorkflowStage(
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
                Icons.chevron_right,
                color: stageColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  /// Build a status option widget
  static Widget buildStatusOption(
    BuildContext context, {
    required String label,
    required String value,
    required String selectedValue,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey[50],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

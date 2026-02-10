import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/project_model.dart';
import '../../../../theme/app_colors.dart';

class FieldOfficerProjectCard extends StatelessWidget {
  final Project project;
  final Function(Project) onViewDetails;
  final Function(Project) onViewReports;
  final Function(Project) onSubmit;

  const FieldOfficerProjectCard({
    super.key,
    required this.project,
    required this.onViewDetails,
    required this.onViewReports,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final priority = project.priority ?? 'medium';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20), // Space for priority label
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        project.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(project.statusDisplay),
                      backgroundColor: _getProjectStatusColor(project.status),
                    ),
                  ],
                ),
                if (project.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    project.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Coordinator: ${project.coordinatorName ?? project.coordinatorUsername}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const Spacer(),
                    Icon(Icons.attach_file, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${project.documentsCount} docs',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (project.startDate != null || project.endDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (project.startDate != null) ...[
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(project.startDate!),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                      if (project.endDate != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.event, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(project.endDate!),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onViewDetails(project),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Project Details'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: const Color(0xFF0570B0)!),
                          foregroundColor: const Color(0xFF0570B0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onViewReports(project),
                        icon: const Icon(Icons.assessment, size: 18),
                        label: const Text('Valuation Reports'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Submit to Accessor button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => onSubmit(project),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Submit to Accessor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0570B0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Priority ribbon at top-left corner
        Positioned(
          top: 4,
          left: 8,
          child: _buildPriorityRibbon(priority),
        ),
      ],
    );
  }

  Widget _buildPriorityRibbon(String priority) {
    final color = _getPriorityColor(priority);
    final label = _formatPriorityLabel(priority);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            priority.toLowerCase() == 'high'
                ? Icons.priority_high
                : priority.toLowerCase() == 'low'
                    ? Icons.arrow_downward
                    : Icons.remove_circle_outline,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red[600]!;
      case 'low':
        return const Color(0xFF0570B0)!;
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

  Color _getProjectStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[100]!;
      case 'in_progress':
        return Colors.blue[100]!;
      case 'completed':
        return const Color(0xFFFFF8E7)!;
      case 'cancelled':
        return Colors.red[100]!;
      default:
        return Colors.grey[200]!;
    }
  }
}

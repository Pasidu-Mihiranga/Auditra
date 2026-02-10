import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/project_model.dart';
import '../../../../theme/app_colors.dart';

class CoordinatorRecentActivity extends StatelessWidget {
  final List<Project> projects;
  final Function(Project) onViewProjectDetails;

  const CoordinatorRecentActivity({
    super.key,
    required this.projects,
    required this.onViewProjectDetails,
  });

  @override
  Widget build(BuildContext context) {
    // Sort projects by creation date (newest first) and take latest 5
    // Create a copy to avoid sorting the original list
    final recentProjects = projects.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latestProjects = recentProjects.take(5).toList();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: const Text(
              'Latest Projects',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF374151)),
            ),
          ),
          if (latestProjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'No recent projects',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            )
          else
            ...latestProjects.map((project) => _buildTransactionItem(project)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Project project) {
    final dateText = DateFormat('MMM dd').format(project.createdAt);
    final statusColor = _getProjectStatusColor(project.status);
    
    return InkWell(
      onTap: () => onViewProjectDetails(project),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF9CA3AF),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            Text(
              project.statusDisplay,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: statusColor,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProjectStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber[600]!;
      case 'in_progress':
        return Colors.blue[400]!;
      case 'completed':
        return AppColors.strongBlue;
      case 'cancelled':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}

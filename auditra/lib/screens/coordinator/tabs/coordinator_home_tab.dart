import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/project_model.dart';
import '../components/coordinator_stats.dart';
import '../components/coordinator_project_categories.dart';
import '../components/coordinator_recent_activity.dart';

class CoordinatorHomeTab extends StatelessWidget {
  final List<Project> projects;
  final Function(Project) onViewDetails;

  const CoordinatorHomeTab({
    super.key,
    required this.projects,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           _buildMainStatsCard(),
           const SizedBox(height: 24),
           CoordinatorProjectCategories(projects: projects),
           const SizedBox(height: 24),
           CoordinatorRecentActivity(
             projects: projects,
             onViewProjectDetails: onViewDetails,
           ),
        ],
      ),
    );
  }

  Widget _buildMainStatsCard() {
    // Calculate monthly project counts (projects created this month)
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final monthlyProjects = projects.where((p) => p.createdAt.isAfter(firstDayOfMonth.subtract(const Duration(days: 1)))).toList();
    
    // Count completed projects for current month
    final completedProjects = monthlyProjects.where((p) => p.status.toLowerCase() == 'completed').length;
    
    // Count all projects by status (not just monthly ones)
    final activeProjects = projects.where((p) => p.status.toLowerCase() == 'in_progress').length;
    final pendingProjects = projects.where((p) => p.status.toLowerCase() == 'pending').length;
    final cancelledProjects = projects.where((p) => p.status.toLowerCase() == 'cancelled').length;
    
    // Get current month name
    final currentMonth = DateFormat('MMMM').format(now);
    
    return CoordinatorStats(
      activeProjects: activeProjects,
      completedProjects: completedProjects,
      pendingProjects: pendingProjects,
      cancelledProjects: cancelledProjects,
      currentMonth: currentMonth,
    );
  }
}

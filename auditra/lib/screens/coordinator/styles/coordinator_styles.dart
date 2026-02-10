import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../coordinator_dashboard.dart'; // Implied dependency, but we should make this pure if possible

class CoordinatorStyles {
  static Color getPriorityColor(String priority) {
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

  static String formatPriorityLabel(String priority) {
    if (priority.isEmpty) return 'Medium';
    final lower = priority.toLowerCase();
    if (lower == 'high') return 'High';
    if (lower == 'low') return 'Low';
    return 'Medium';
  }

  static Widget buildPriorityRibbon(String priority) {
    final color = getPriorityColor(priority);
    final label = formatPriorityLabel(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Calibri',
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static Color getProjectStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber[600]!;
      case 'in_progress':
        return Colors.blue[400]!;
      case 'completed':
        return const Color(0xFF0570B0)!;
      case 'cancelled':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  static Color getAttendanceStatusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFF84BCDA);
      case 'half_day':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  static Widget buildStatusRibbon(Project project) {
    final isPending = project.status == 'pending';
    final color = isPending
        ? const Color(0xFFFFA726)
        : project.status == 'in_progress'
            ? const Color(0xFF42A5F5)
            : project.status == 'completed'
                ? const Color(0xFF66BB6A)
                : project.status == 'cancelled'
                    ? const Color(0xFFEF5350)
                    : getProjectStatusColor(project.status);
    final label = project.status == 'cancelled' ? 'Cancel' : project.statusDisplay;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Calibri',
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

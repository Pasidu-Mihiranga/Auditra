import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../../models/project_model.dart';
import 'package:intl/intl.dart';

/// Reusable UI builder widgets for Coordinator Dashboard
class CoordinatorUIBuilders {
  
  /// Build a dot indicator for carousel/pagination
  static Widget buildDotIndicator({
    required int selectedIndex,
    required int itemCount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        final isActive = index == selectedIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 12 : 4,
          height: 5,
          decoration: BoxDecoration(
            color: isActive 
                ? const Color.fromARGB(255, 0, 0, 0) 
                : const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
            boxShadow: isActive ? [
              BoxShadow(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ] : [],
          ),
        );
      }),
    );
  }

  /// Build a navigation arrow button with glassmorphism
  static Widget buildNavigationArrow({
    required IconData icon,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    final size = isSmallScreen ? 32.0 : 36.0;
    final iconSize = isSmallScreen ? 14.0 : 16.0;

    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: const Color(0xFF10B981),
            ),
          ),
        ),
      ),
    );
  }

  /// Build a modern info card with icon, label, and value
  static Widget buildModernInfoCard({
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
            ),
          ],
        ),
      ),
    );
  }

  /// Build dates text for a project (start and end dates)
  static String buildDatesText(Project project) {
    final startDate = project.startDate != null
        ? DateFormat('MMM d, y').format(project.startDate!)
        : 'Not set';
    final endDate = project.endDate != null
        ? DateFormat('MMM d, y').format(project.endDate!)
        : 'Not set';
    return '$startDate - $endDate';
  }

  /// Build assigned users text for a project
  static String buildAssignedUsersText(Project project) {
    final List<String> assigned = [];
    if (project.assignedFieldOfficerName != null) {
      assigned.add('FO: ${project.assignedFieldOfficerName}');
    }
    if (project.assignedClientName != null) {
      assigned.add('Client: ${project.assignedClientName}');
    }
    if (project.hasAgent && project.assignedAgentName != null) {
      assigned.add('Agent: ${project.assignedAgentName}');
    }
    return assigned.isEmpty ? 'No users assigned' : assigned.join(' • ');
  }

  /// Build an action button with icon and label
  static Widget buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

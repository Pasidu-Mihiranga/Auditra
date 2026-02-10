import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../../../../models/project_model.dart';
// import '../../../../theme/app_colors.dart'; // Use logic from original file for now to match exactly

class GenericProjectCard extends StatelessWidget {
  final Project project;
  final Function(Project) onTap;

  const GenericProjectCard({
    super.key,
    required this.project,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final priority = project.priority ?? 'medium';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(project),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8), // Space for priority label
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  project.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Calibri',
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getProjectStatusColor(project.status).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getProjectStatusColor(project.status).withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  project.statusDisplay,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Calibri',
                                    color: _getProjectStatusColor(project.status).withRed(100).withGreen(100).withBlue(100), // Darker shade
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (project.description != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              project.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                                fontFamily: 'Calibri',
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Coordinator: ${project.coordinatorName ?? project.coordinatorUsername}',
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Calibri',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(width: 1, height: 16, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 8)),
                                Icon(Icons.attach_file, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${project.documentsCount}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Calibri',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (project.startDate != null || project.endDate != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (project.startDate != null)
                                  _buildDateBadge(Icons.calendar_today, project.startDate),
                                if (project.endDate != null) ...[
                                  const SizedBox(width: 12),
                                  _buildDateBadge(Icons.event_available, project.endDate, isEnd: true),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Priority ribbon at top-left corner
        Positioned(
          top: 4,
          left: 28, // Adjusted for padding (20) + small offset
          child: _buildPriorityRibbon(priority),
        ),
      ],
    );
  }

  Widget _buildDateBadge(IconData icon, DateTime? date, {bool isEnd = false}) {
    if (date == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEnd ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isEnd ? Colors.red[700] : Colors.blue[700]),
          const SizedBox(width: 4),
          Text(
            DateFormat('MMM dd').format(date),
            style: TextStyle(
              fontSize: 11,
              color: isEnd ? Colors.red[800] : Colors.blue[800],
              fontWeight: FontWeight.w600,
              fontFamily: 'Calibri',
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

import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';

class CoordinatorStats extends StatelessWidget {
  final int activeProjects;
  final int completedProjects;
  final int pendingProjects;
  final int cancelledProjects;
  final String currentMonth;

  const CoordinatorStats({
    super.key,
    required this.activeProjects,
    required this.completedProjects,
    required this.pendingProjects,
    required this.cancelledProjects,
    required this.currentMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white, // White card background
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 1, offset: const Offset(0, 1)),
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 224,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.strongBlue, AppColors.lightBlue, AppColors.lightBlue],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
                bottomLeft: Radius.circular(70),
                bottomRight: Radius.circular(70),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'COORDINATOR',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      currentMonth.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '$completedProjects',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.normal, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 2),
                Center(
                  child: Text(
                    'Projects Completed',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildProjectStatItem(
                    label: 'Active',
                    value: '$activeProjects',
                    color: AppColors.strongBlue,
                  ),
                ),
                Container(width: 1, height: 48, color: AppColors.lightBlue.withOpacity(0.3)),
                Expanded(
                  child: _buildProjectStatItem(
                    label: 'Received',
                    value: '$pendingProjects',
                    color: AppColors.orange,
                  ),
                ),
                Container(width: 1, height: 48, color: AppColors.lightBlue.withOpacity(0.3)),
                Expanded(
                  child: _buildProjectStatItem(
                    label: 'Cancelled',
                    value: '$cancelledProjects',
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectStatItem({required String label, required String value, required Color color}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

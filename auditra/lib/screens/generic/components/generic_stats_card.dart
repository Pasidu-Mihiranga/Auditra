import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/attendance_model.dart';

class GenericStatsCard extends StatelessWidget {
  final AttendanceSummary? monthlySummary;

  const GenericStatsCard({
    super.key,
    required this.monthlySummary,
  });

  @override
  Widget build(BuildContext context) {
    // Always show current month data
    final daysPresent = monthlySummary?.presentDays ?? 0;
    final daysAbsent = monthlySummary?.absentDays ?? 0;
    final overtimeHours = monthlySummary?.totalOvertimeHours ?? 0.0;
    
    // Calculate leaves remaining (assuming 21 working days per month, adjust as needed)
    final totalWorkingDays = monthlySummary?.workingDays ?? 21;
    final leavesRemaining = totalWorkingDays - daysPresent - daysAbsent;
    
    // Get current month name
    final currentMonth = DateFormat('MMMM').format(DateTime.now());
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 1, offset: const Offset(0, 1)),
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFBBDEFB),
              Color(0xFF81D4FA),
              Color(0xFFBBDEFB),
            ],
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ATTENDANCE',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  currentMonth.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Main number - Present Days Count
            Text(
              '$daysPresent',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Days Present This Month',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            
            // Status breakdown - Absent, Leaves, Overtime
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Absent', '$daysAbsent', Colors.red[700]!),
                  Container(width: 1, height: 30, color: Colors.grey[400]),
                  _buildStatItem('Leaves', '$leavesRemaining', Colors.orange[700]!),
                  Container(width: 1, height: 30, color: Colors.grey[400]),
                  _buildStatItem('Overtime', '${overtimeHours.toStringAsFixed(1)}h', Colors.purple[700]!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

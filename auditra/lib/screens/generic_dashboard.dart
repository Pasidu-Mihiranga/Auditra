import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../models/attendance_model.dart';
import 'login_screen.dart';

class GenericDashboard extends StatefulWidget {
  final String role;
  final String roleDisplay;
  
  const GenericDashboard({
    super.key,
    required this.role,
    required this.roleDisplay,
  });

  @override
  State<GenericDashboard> createState() => _GenericDashboardState();
}

class _GenericDashboardState extends State<GenericDashboard> {
  String? _username;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  
  // Attendance state
  Attendance? _todayAttendance;
  bool _isWorkingDay = true;
  String _selectedPeriod = 'daily';
  AttendanceSummary? _summary;
  bool _isLoadingSummary = false;
  bool _isMarkingAttendance = false;
  
  // Timer for countdown
  DateTime? _countdownEnd;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTodayAttendance();
    _loadSummary();
    _startTimer();
  }

  Future<void> _loadUserData() async {
    final username = await ApiService.getUsername();
    final profileResult = await ApiService.getProfile();
    final roleResult = await ApiService.getMyRole();

    if (mounted) {
      setState(() {
        _username = username;
        if (profileResult['success']) {
          _profile = profileResult['data'];
        }
        if (roleResult['success']) {
          _profile?['role'] = roleResult['data']['role'];
          _profile?['role_display'] = roleResult['data']['role_display'];
        }
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    // Set countdown to 5 PM today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _countdownEnd = DateTime(today.year, today.month, today.day, 17, 0);
    
    // Update timer immediately
    _updateTimer();
  }

  void _updateTimer() {
    if (_countdownEnd != null) {
      final now = DateTime.now();
      if (now.isBefore(_countdownEnd!)) {
        setState(() {
          _remainingTime = _countdownEnd!.difference(now);
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _updateTimer();
          }
        });
      } else {
        setState(() {
          _remainingTime = Duration.zero;
        });
      }
    }
  }

  Future<void> _loadTodayAttendance() async {
    final result = await ApiService.getTodayAttendance();
    
    if (mounted) {
      setState(() {
        if (result['success']) {
          final data = result['data'];
          _isWorkingDay = data['is_working_day'] ?? true;
          if (data['data'] != null) {
            _todayAttendance = Attendance.fromJson(data['data']);
          } else {
            _todayAttendance = null;
          }
        }
      });
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoadingSummary = true);
    final result = await ApiService.getAttendanceSummary(period: _selectedPeriod);
    
    if (mounted) {
      setState(() {
        _isLoadingSummary = false;
        if (result['success'] && result['data']['data'] != null) {
          _summary = AttendanceSummary.fromJson(result['data']['data']);
        }
      });
    }
  }

  Future<void> _markAttendance() async {
    setState(() => _isMarkingAttendance = true);
    
    try {
      final result = await ApiService.markAttendance();
      
      if (mounted) {
        if (result['success']) {
          // Update attendance from response
          final responseData = result['data'];
          if (responseData != null && responseData['data'] != null) {
            setState(() {
              _todayAttendance = Attendance.fromJson(responseData['data']);
            });
            _startTimer();
          } else {
            // Fallback to reload
            await _loadTodayAttendance();
            _startTimer();
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Attendance marked successfully!')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result['message'] ?? 'Failed to mark attendance')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingAttendance = false);
      }
    }
  }

  Future<void> _leaveEarly() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Early'),
        content: const Text('Are you sure you want to leave early?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ApiService.leaveEarly();
      
      if (mounted) {
        if (result['success']) {
          final data = result['data'];
          final isFullDay = data['is_full_day'] ?? false;
          final hours = data['working_hours'] ?? 0.0;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFullDay 
                  ? 'Full day recorded (${hours.toStringAsFixed(1)} hours)'
                  : 'Half day recorded (${hours.toStringAsFixed(1)} hours)'
              ),
            ),
          );
          await _loadTodayAttendance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to mark early leave')),
          );
        }
      }
    }
  }

  Future<void> _checkOut() async {
    final result = await ApiService.checkOut();
    
    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked out successfully!')),
        );
        await _loadTodayAttendance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to check out')),
        );
      }
    }
  }

  Future<void> _startOvertime() async {
    final result = await ApiService.startOvertime();
    
    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Overtime started!')),
        );
        await _loadTodayAttendance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to start overtime')),
        );
      }
    }
  }

  Future<void> _endOvertime() async {
    final result = await ApiService.endOvertime();
    
    if (mounted) {
      if (result['success']) {
        final data = result['data'];
        final hours = data['overtime_hours'] ?? 0.0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Overtime ended! Total: ${hours.toStringAsFixed(1)} hours')),
        );
        await _loadTodayAttendance();
        await _loadSummary();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to end overtime')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  String _getDashboardTitle() {
    switch (widget.role) {
      case 'coordinator':
        return 'Coordinator Dashboard';
      case 'accessor':
        return 'Accessor Dashboard';
      case 'senior_valuer':
        return 'Senior Valuer Dashboard';
      case 'md_gm':
        return 'MD/GM Dashboard';
      case 'hr_staff':
        return 'HR Staff Dashboard';
      case 'general_employee':
        return 'Employee Dashboard';
      case 'client':
        return 'Client Portal';
      case 'agent':
        return 'Agent Dashboard';
      case 'unassigned':
        return 'Welcome';
      default:
        return 'Dashboard';
    }
  }

  IconData _getRoleIcon() {
    switch (widget.role) {
      case 'coordinator':
        return Icons.people_outline;
      case 'accessor':
        return Icons.assessment_outlined;
      case 'senior_valuer':
        return Icons.verified_user_outlined;
      case 'md_gm':
        return Icons.business_center_outlined;
      case 'hr_staff':
        return Icons.people_alt_outlined;
      case 'general_employee':
        return Icons.badge_outlined;
      case 'client':
        return Icons.person_outline;
      case 'agent':
        return Icons.handshake_outlined;
      default:
        return Icons.dashboard_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getDashboardTitle(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (_username != null || _profile?['role_display'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_username != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.9)
                                : Colors.black87.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _username!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.95)
                                  : Colors.black87,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    if (_username != null && _profile?['role_display'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Container(
                          width: 1,
                          height: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black26,
                        ),
                      ),
                    if (_profile?['role_display'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: Theme.of(context).brightness == Brightness.dark
                                ? [
                                    Colors.white.withOpacity(0.25),
                                    Colors.white.withOpacity(0.15),
                                  ]
                                : [
                                    Colors.blue.withOpacity(0.15),
                                    Colors.blue.withOpacity(0.1),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.3)
                                : Colors.blue.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _profile!['role_display'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadTodayAttendance();
                await _loadSummary();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Today's Attendance Card
                    _buildTodayAttendanceCard(),
                    const SizedBox(height: 16),
                    
                    // Attendance Summary
                    _buildSummarySection(),
                    const SizedBox(height: 16),
                    
                    // Charts Section
                    if (_summary != null) _buildChartsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTodayAttendanceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Today\'s Attendance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (!_isWorkingDay)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Today is not a working day (Sunday or Holiday)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              )
            else if (_todayAttendance == null)
              Column(
                children: [
                  // Countdown Timer and Attendance Button Row
                  Row(
                    children: [
                      // Animated Countdown Timer
                      Expanded(
                        flex: 2,
                        child: _buildAnimatedCountdown(),
                      ),
                      const SizedBox(width: 12),
                      // Attendance Button
                      Expanded(
                        flex: 3,
                        child: _buildAttendanceButton(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Working Hours Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Working Hours: 8:00 AM - 5:00 PM',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else if (_todayAttendance != null && !_todayAttendance!.isCheckedOut)
              Column(
                children: [
                  // Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Chip(
                        label: Text(_todayAttendance!.statusDisplay),
                        backgroundColor: _getStatusColor(_todayAttendance!.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Check-in time
                  if (_todayAttendance!.checkIn != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Check-in:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(DateFormat('hh:mm a').format(_todayAttendance!.checkIn!)),
                      ],
                    ),
                  
                  const SizedBox(height: 16),
                  // Countdown Timer and Leave Early Button Row
                  Row(
                    children: [
                      // Animated Countdown Timer
                      Expanded(
                        flex: 2,
                        child: _buildAnimatedCountdown(),
                      ),
                      const SizedBox(width: 12),
                      // Leave Early Button
                      Expanded(
                        flex: 3,
                        child: _buildLeaveEarlyButton(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Check Out Button (if after 5 PM or close to it)
                  if (DateTime.now().hour >= 17 || _remainingTime.inMinutes < 5)
                    ElevatedButton.icon(
                      onPressed: _checkOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Check Out'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              )
            else
              Column(
                children: [
                  // Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Chip(
                        label: Text(_todayAttendance!.statusDisplay),
                        backgroundColor: _getStatusColor(_todayAttendance!.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Check-in time
                  if (_todayAttendance!.checkIn != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Check-in:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(DateFormat('hh:mm a').format(_todayAttendance!.checkIn!)),
                      ],
                    ),
                  
                  // Check-out time
                  if (_todayAttendance!.checkOut != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Check-out:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(DateFormat('hh:mm a').format(_todayAttendance!.checkOut!)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Working Hours:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('${_todayAttendance!.workingHours.toStringAsFixed(1)} hrs'),
                      ],
                    ),
                  ],
                  
                  // Overtime Section
                  if (_todayAttendance!.isCheckedOut) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    if (_todayAttendance!.overtimeStart == null && DateTime.now().hour >= 17)
                      ElevatedButton.icon(
                        onPressed: _startOvertime,
                        icon: const Icon(Icons.access_time),
                        label: const Text('Start Overtime'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else if (_todayAttendance!.isOvertimeActive) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Overtime Started:', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(DateFormat('hh:mm a').format(_todayAttendance!.overtimeStart!)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _endOvertime,
                        icon: const Icon(Icons.stop),
                        label: const Text('End Overtime'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ]
                    else if (_todayAttendance!.hasOvertime) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Overtime Hours:', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text('${_todayAttendance!.overtimeHours.toStringAsFixed(1)} hrs'),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedPeriod,
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPeriod = value);
                      _loadSummary();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingSummary)
              const Center(child: CircularProgressIndicator())
            else if (_summary != null)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Present',
                          _summary!.presentDays.toString(),
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'Half Day',
                          _summary!.halfDays.toString(),
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Absent',
                          _summary!.absentDays.toString(),
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'Attendance %',
                          '${_summary!.attendancePercentage.toStringAsFixed(1)}%',
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Working Hours',
                          '${_summary!.totalWorkingHours.toStringAsFixed(1)}h',
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'Overtime',
                          '${_summary!.totalOvertimeHours.toStringAsFixed(1)}h',
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              const Center(child: Text('No data available')),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    if (_summary == null || _summary!.dailyData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Attendance Chart',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildBarChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_summary == null || _summary!.dailyData.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    final data = _summary!.dailyData;
    final maxHours = data.map((d) => d.workingHours).reduce((a, b) => a > b ? a : b);
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxHours > 0 ? maxHours + 1 : 10,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < data.length) {
                  final date = data[value.toInt()].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}h',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final dayData = entry.value;
          final color = _getStatusColor(dayData.status);
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: dayData.workingHours,
                color: color,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'half_day':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAnimatedCountdown() {
    final now = DateTime.now();
    final isAfter5PM = now.isAfter(_countdownEnd ?? now);
    final isNearEnd = _remainingTime.inHours < 1;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAfter5PM
                    ? [Colors.red[300]!, Colors.red[500]!]
                    : isNearEnd
                        ? [Colors.orange[300]!, Colors.orange[500]!]
                        : [Colors.blue[300]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isAfter5PM
                          ? Colors.red
                          : isNearEnd
                              ? Colors.orange
                              : Colors.blue)
                      .withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Pulsing background animation
                if (!isAfter5PM)
                  _PulsingContainer(
                    color: isNearEnd ? Colors.orange : Colors.blue,
                  ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon with rotation animation
                      _RotatingIcon(
                        icon: Icons.timer,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      // Time display with scale animation
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, scaleValue, child) {
                          return Transform.scale(
                            scale: 0.8 + (0.2 * scaleValue),
                            child: Text(
                              isAfter5PM
                                  ? '00:00:00'
                                  : _formatDuration(_remainingTime),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAfter5PM ? 'Time Over' : 'Until 5 PM',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceButton() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green[400]!,
            Colors.green[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isMarkingAttendance ? null : _markAttendance,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _isMarkingAttendance
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Marking...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text(
                          'Mark\nAttendance',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveEarlyButton() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange[400]!,
            Colors.orange[600]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _leaveEarly,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.exit_to_app,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: const Text(
                    'Leave\nEarly',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Animated Widgets
class _PulsingContainer extends StatefulWidget {
  final Color color;

  const _PulsingContainer({required this.color});

  @override
  State<_PulsingContainer> createState() => _PulsingContainerState();
}

class _PulsingContainerState extends State<_PulsingContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: RadialGradient(
              colors: [
                widget.color.withOpacity(0.3 * (0.5 + 0.5 * _controller.value)),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RotatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _RotatingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}


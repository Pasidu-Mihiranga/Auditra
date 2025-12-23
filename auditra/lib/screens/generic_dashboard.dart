import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../models/attendance_model.dart';
import '../models/project_model.dart';
import 'login_screen.dart';
import 'payment_slips_screen.dart';
import 'leave_request_screen.dart';
import 'my_leave_requests_screen.dart';
import 'view_leave_requests_screen.dart';
import 'personal_info_screen.dart';

class GenericDashboard extends StatefulWidget {
  final String role;
  final String roleDisplay;
  final bool isEmbedded;
  final bool showOnlyWeeklyAttendance;
  final bool showOnlyMonthlyLeave;
  
  const GenericDashboard({
    super.key,
    required this.role,
    required this.roleDisplay,
    this.isEmbedded = false,
    this.showOnlyWeeklyAttendance = false,
    this.showOnlyMonthlyLeave = false,
  });

  @override
  State<GenericDashboard> createState() => _GenericDashboardState();
}

class _GenericDashboardState extends State<GenericDashboard> with TickerProviderStateMixin {
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
  
  late TabController _periodTabController;
  TabController? _mainTabController; // For Profile/Projects tabs (client/agent/accessor/senior_valuer)
  TabController? _hrTabController; // For HR staff: Profile tab (deprecated, will be replaced)
  TabController? _profileTabController; // For Profile subtabs: Attendance / Payment / Leave
  
  // Project state (for roles that can view projects)
  List<Project> _projects = [];
  bool _isLoadingProjects = false;
  
  // Timer for countdown
  DateTime? _countdownEnd;
  Duration _remainingTime = Duration.zero;
  
  // Timer for overtime
  Duration _overtimeDuration = Duration.zero;
  
  // Leave statistics state
  Map<String, dynamic>? _leaveStatistics;
  bool _isLoadingLeaveStats = false;
  
  // HR Staff - Monthly leave summary state (like admin dashboard)
  List<Map<String, dynamic>> _monthlyLeaveSummary = [];
  bool _isLoadingLeaveSummary = false;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  // HR Staff - Attendance summary weekly state
  List<Map<String, dynamic>> _weeklyAttendanceSummary = [];
  bool _isLoadingAttendanceSummary = false;
  DateTime _selectedWeekStart = _getWeekStart(DateTime.now());
  String _attendanceSearchQuery = '';
  
  // Helper function to get the start of the week (Monday)
  static DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }
  
  // Check if this role should see projects
  bool get _shouldShowProjects {
    return widget.role == 'client' || 
           widget.role == 'agent' || 
           widget.role == 'accessor' || 
           widget.role == 'senior_valuer';
  }

  @override
  void initState() {
    super.initState();
    // Initialize period tab controller and sync with selected period
    final periods = ['daily', 'weekly', 'monthly', 'yearly'];
    final initialPeriodIndex = periods.indexOf(_selectedPeriod);
    _periodTabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialPeriodIndex >= 0 ? initialPeriodIndex : 0,
    );
    _periodTabController.addListener(() {
      if (!_periodTabController.indexIsChanging) {
        setState(() => _selectedPeriod = periods[_periodTabController.index]);
        _loadSummary();
      }
    });
    
    // Initialize Profile tab controller for subtabs (Attendance / Payment / Leave) 
    // for all roles except admin, client, and agent
    if (widget.role != 'admin' && widget.role != 'client' && widget.role != 'agent') {
      _profileTabController = TabController(length: 3, vsync: this);
      _profileTabController!.addListener(() {
        if (!_profileTabController!.indexIsChanging && mounted) {
          setState(() {});
        }
      });
    }

    // Initialize main tab controller if this role should see projects
    if (_shouldShowProjects) {
      _mainTabController = TabController(length: 2, vsync: this);
      _mainTabController!.addListener(() {
        if (!_mainTabController!.indexIsChanging && mounted) {
          setState(() {});
        }
      });
      _loadProjects();
    }
    
    // Initialize HR staff tab controller (deprecated - will be replaced by Profile tab)
    // Keeping for now to avoid breaking changes
    if (widget.role == 'hr_staff') {
      _hrTabController = TabController(length: 3, vsync: this);
      _hrTabController!.addListener(() {
        if (!_hrTabController!.indexIsChanging && mounted) {
          setState(() {});
          // Load weekly attendance summary when switching to attendance tab (index 0)
          if (_hrTabController!.index == 0) {
            _loadWeeklyAttendanceSummary();
          }
        }
      });
    }
    
    _loadUserData();
    _loadTodayAttendance();
    _loadSummary();
    _loadLeaveStatistics();
    _startTimer();
    
    // Load weekly attendance summary for HR staff and admin only
    if (widget.role == 'hr_staff' || widget.role == 'admin') {
      _loadWeeklyAttendanceSummary();
    }
    
    // Load monthly leave summary for HR staff only
    if (widget.role == 'hr_staff') {
      _loadMonthlyLeaveSummary();
    }
  }

  @override
  void dispose() {
    _periodTabController.dispose();
    _mainTabController?.dispose();
    _hrTabController?.dispose();
    _profileTabController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadProjects() async {
    if (!_shouldShowProjects) return;
    
    setState(() => _isLoadingProjects = true);
    
    final result = await ApiService.getProjects();
    
    if (mounted) {
      setState(() {
        _isLoadingProjects = false;
        if (result['success']) {
          final data = result['data'];
          final projectsList = data is List ? data : (data['results'] ?? []);
          _projects = (projectsList as List<dynamic>)
              .map((p) => Project.fromJson(p))
              .toList();
        }
      });
    }
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
        // Auto-checkout when countdown ends at 5 PM
        if (_todayAttendance != null && 
            _todayAttendance!.isCheckedIn && 
            !_todayAttendance!.isCheckedOut) {
          _checkOut();
        }
      }
    }
    
    // Update overtime timer if active
    if (_todayAttendance != null && _todayAttendance!.isOvertimeActive && _todayAttendance!.overtimeStart != null) {
      final now = DateTime.now();
      setState(() {
        _overtimeDuration = now.difference(_todayAttendance!.overtimeStart!);
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _updateTimer();
        }
      });
    } else {
      setState(() {
        _overtimeDuration = Duration.zero;
      });
    }
  }

  Future<void> _loadTodayAttendance() async {
    try {
      final result = await ApiService.getTodayAttendance();
      
      if (mounted) {
        setState(() {
          if (result['success']) {
            final data = result['data'];
            _isWorkingDay = data['is_working_day'] ?? true;
            if (data['data'] != null) {
              _todayAttendance = Attendance.fromJson(data['data']);
              // Initialize overtime duration if overtime is active
              if (_todayAttendance!.isOvertimeActive && _todayAttendance!.overtimeStart != null) {
                final now = DateTime.now();
                _overtimeDuration = now.difference(_todayAttendance!.overtimeStart!);
              }
            } else {
              _todayAttendance = null;
              _overtimeDuration = Duration.zero;
            }
          } else {
            _todayAttendance = null;
            _overtimeDuration = Duration.zero;
            // Show error message if available
            if (result['message'] != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'Failed to load attendance'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _todayAttendance = null;
          _overtimeDuration = Duration.zero;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading attendance: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final result = await ApiService.getAttendanceSummary(period: _selectedPeriod);
      
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          if (result['success'] && result['data'] != null && result['data']['data'] != null) {
            _summary = AttendanceSummary.fromJson(result['data']['data']);
          } else {
            _summary = null;
            // Only show error for non-connection errors (suppress connection/server errors)
            final errorMessage = result['message'] ?? '';
            if (errorMessage.isNotEmpty && 
                !errorMessage.toLowerCase().contains('server error') &&
                !errorMessage.toLowerCase().contains('connection') &&
                !errorMessage.toLowerCase().contains('backend server') &&
                !errorMessage.toLowerCase().contains('html')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          _summary = null;
        });
        // Suppress connection errors - don't show error banner
        // Only log for debugging
        print('Error loading attendance summary: $e');
      }
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

  bool _isOvertimeAllowed() {
    final now = DateTime.now();
    final hour = now.hour;
    // Overtime allowed from 5 PM (17:00) to 8 AM (08:00) next day
    return hour >= 17 || hour < 8;
  }

  bool _isAfter12PM() {
    final now = DateTime.now();
    return now.hour >= 12;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.exit_to_app_rounded,
                      size: 64,
                      color: Colors.orange[300],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Are you sure?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You are about to logout from your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, size: 20),
                            SizedBox(width: 8),
                            Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      case 'field_officer':
        return 'Field Officer Dashboard';
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

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      // When embedded, check if showing only specific sections
      if (widget.showOnlyWeeklyAttendance) {
        // Show only Weekly Attendance Summary
        return _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadWeeklyAttendanceSummary();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: _buildWeeklyAttendanceSummarySection(),
                ),
              );
      }
      
      if (widget.showOnlyMonthlyLeave) {
        // Show only Monthly Leave Summary
        return _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadMonthlyLeaveSummary();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: _buildMonthlyLeaveSummarySection(),
                ),
              );
      }
      
      // When embedded, show Profile tab with subtabs for non-admin roles (except client and agent)
      if (widget.role != 'admin' && widget.role != 'client' && widget.role != 'agent' && _profileTabController != null) {
        return _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildProfileTabBody();
      }
      // Otherwise show dashboard body
      final body = _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDashboardBody();
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getDashboardTitle(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            if (_username != null || _profile?['role_display'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_username != null)
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.black87.withOpacity(0.8),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                _username!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withOpacity(0.95)
                                      : Colors.black87,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_username != null && _profile?['role_display'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Container(
                          width: 1,
                          height: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black26,
                        ),
                      ),
                    if (_profile?['role_display'] != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            borderRadius: BorderRadius.circular(10),
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
                                size: 10,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.blue[700],
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  _profile!['role_display'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.blue[900],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
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
        bottom: widget.role != 'admin' && widget.role != 'client' && widget.role != 'agent'
            ? (_shouldShowProjects && _mainTabController != null
                ? TabBar(
                    controller: _mainTabController!,
                    tabs: const [
                      Tab(icon: Icon(Icons.person), text: 'Profile'),
                      Tab(icon: Icon(Icons.folder), text: 'Projects'),
                    ],
                  )
                : _profileTabController != null
                    ? TabBar(
                        controller: _profileTabController!,
                        tabs: [
                          Tab(
                            icon: Icon(Icons.calendar_today, color: Colors.blue[600]),
                            text: 'Attendance',
                          ),
                          Tab(
                            icon: Icon(Icons.event_note, color: Colors.orange[600]),
                            text: 'Leave',
                          ),
                          Tab(
                            icon: Icon(Icons.payment, color: Colors.green[600]),
                            text: 'Payment',
                          ),
                        ],
                      )
                    : null)
            : _shouldShowProjects && _mainTabController != null
                ? TabBar(
                    controller: _mainTabController!,
                    tabs: const [
                      Tab(icon: Icon(Icons.access_time), text: 'Attendance'),
                      Tab(icon: Icon(Icons.folder), text: 'Projects'),
                    ],
                  )
                : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shouldShowProjects && _mainTabController != null
              ? TabBarView(
                  controller: _mainTabController!,
                  children: [
                    // For client and agent, show dashboard body. For others (accessor, senior_valuer), show Profile tab
                    (widget.role == 'client' || widget.role == 'agent')
                        ? _buildDashboardBody()
                        : _buildProfileTabBody(),
                    _buildProjectsTab(),
                  ],
                )
              : widget.role != 'admin' && widget.role != 'client' && widget.role != 'agent' && _profileTabController != null
                  ? _buildProfileTabBody()
                  : _buildDashboardBody(),
    );
  }

  Widget _buildDashboardBody() {
    // For admin, show only charts and weekly attendance summary
    if (widget.role == 'admin') {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
          await _loadTodayAttendance();
          await _loadSummary();
          await _loadLeaveStatistics();
          await _loadWeeklyAttendanceSummary();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Weekly Attendance Summary - Show for admin
              _buildWeeklyAttendanceSummarySection(),
              const SizedBox(height: 16),
              
              // Charts Section
              if (_summary != null) _buildChartsSection(),
            ],
          ),
        ),
      );
    }
    
    // For all non-admin roles, show all content
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserData();
        await _loadTodayAttendance();
        await _loadSummary();
        await _loadLeaveStatistics();
        if (widget.role == 'hr_staff' || widget.role == 'admin') {
          await _loadWeeklyAttendanceSummary();
        }
        if (widget.role == 'hr_staff') {
          await _loadMonthlyLeaveSummary();
        }
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
            
            // Summary Section
            _buildSummarySection(),
            const SizedBox(height: 16),
            
            // Charts Section
            if (_summary != null) ...[
              _buildChartsSection(),
              const SizedBox(height: 24),
            ],
            
            // Weekly Attendance Summary - Only show for HR staff and admin
            if (widget.role == 'hr_staff' || widget.role == 'admin') ...[
              _buildWeeklyAttendanceSummarySection(),
              const SizedBox(height: 24),
            ],
            
            // Leave Statistics Section
            _buildLeaveStatisticsSection(),
            const SizedBox(height: 24),
            
            // Payment Section
            _buildPaymentSection(),
          ],
        ),
      ),
    );
  }

  /// HR Staff - Attendance tab body (like admin "Attendance" navigation)
  Widget _buildHRAttendanceTabBody() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserData();
        await _loadTodayAttendance();
        await _loadSummary();
        await _loadLeaveStatistics();
        await _loadWeeklyAttendanceSummary();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTodayAttendanceCard(),
            const SizedBox(height: 16),
            _buildSummarySection(),
            const SizedBox(height: 16),
            if (_summary != null) _buildChartsSection(),
            // Weekly Attendance Summary - Only show for HR staff and admin
            if (widget.role == 'hr_staff' || widget.role == 'admin') ...[
              const SizedBox(height: 24),
              _buildWeeklyAttendanceSummarySection(),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _loadWeeklyAttendanceSummary() async {
    // Only allow HR staff and admin to view weekly attendance summary
    if (widget.role != 'hr_staff' && widget.role != 'admin') return;
    
    setState(() => _isLoadingAttendanceSummary = true);
    
    try {
      final result = await ApiService.getWeeklyAttendanceSummary(
        weekStart: _selectedWeekStart,
      );
      
      if (!mounted) return;
      
      setState(() {
        _isLoadingAttendanceSummary = false;
        if (result['success']) {
          _weeklyAttendanceSummary = (result['data'] as List<dynamic>)
              .map((item) => item as Map<String, dynamic>)
              .toList();
        } else {
          // Silently fail - don't show error message
          _weeklyAttendanceSummary = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAttendanceSummary = false;
        _weeklyAttendanceSummary = [];
      });
      // Silently fail - don't show error message
    }
  }

  Future<void> _selectWeek() async {
    final now = DateTime.now();
    final initialDate = _selectedWeekStart;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select Week Start (Monday)',
    );
    
    if (picked != null) {
      setState(() {
        _selectedWeekStart = _getWeekStart(picked);
      });
      await _loadWeeklyAttendanceSummary();
    }
  }

  Future<void> _loadMonthlyLeaveSummary() async {
    // Only allow HR staff to view monthly leave summary
    if (widget.role != 'hr_staff') return;
    
    setState(() => _isLoadingLeaveSummary = true);
    
    try {
      final result = await ApiService.getMonthlyLeaveSummary(
        month: _selectedMonth,
        year: _selectedYear,
      );
      
      if (!mounted) return;
      
      setState(() {
        _isLoadingLeaveSummary = false;
        if (result['success']) {
          _monthlyLeaveSummary = (result['data'] as List<dynamic>)
              .map((item) => item as Map<String, dynamic>)
              .toList();
        } else {
          // Silently fail - don't show error message
          _monthlyLeaveSummary = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLeaveSummary = false;
        _monthlyLeaveSummary = [];
      });
      // Silently fail - don't show error message
    }
  }

  Future<void> _selectMonthYear() async {
    final now = DateTime.now();
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    int? selectedMonth = _selectedMonth;
    int? selectedYear = _selectedYear;
    
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Month & Year'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: const InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(12, (index) {
                  final month = index + 1;
                  return DropdownMenuItem(
                    value: month,
                    child: Text(monthNames[index]),
                  );
                }),
                onChanged: (value) {
                  setDialogState(() => selectedMonth = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(5, (index) {
                  final year = now.year - 2 + index;
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }),
                onChanged: (value) {
                  setDialogState(() => selectedYear = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'month': selectedMonth!,
                'year': selectedYear!,
              }),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedMonth = result['month']!;
        _selectedYear = result['year']!;
      });
      await _loadMonthlyLeaveSummary();
    }
  }

  Widget _buildWeeklyAttendanceSummarySection() {
    // Only show for HR staff and admin
    if (widget.role != 'hr_staff' && widget.role != 'admin') {
      return const SizedBox.shrink();
    }
    
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    final weekRange = '${_selectedWeekStart.day}/${_selectedWeekStart.month}/${_selectedWeekStart.year} - ${weekEnd.day}/${weekEnd.month}/${weekEnd.year}';
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.teal[700], size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Attendance Summary Weekly',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _selectWeek,
                  tooltip: 'Select Week',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Week: $weekRange',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by Employee ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _attendanceSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _attendanceSearchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _attendanceSearchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_isLoadingAttendanceSummary)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_weeklyAttendanceSummary.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No attendance records for this week',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Builder(
                builder: (context) {
                  // Filter employees based on search query
                  List<Map<String, dynamic>> filteredEmployees = _attendanceSearchQuery.isEmpty
                      ? _weeklyAttendanceSummary
                      : _weeklyAttendanceSummary.where((employee) {
                          final employeeNumber = (employee['employee_number'] as String? ?? '').toString();
                          return employeeNumber.toLowerCase().contains(_attendanceSearchQuery.toLowerCase());
                        }).toList();
                  
                  if (filteredEmployees.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No employees found with employee ID: $_attendanceSearchQuery',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  'Employee Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Employee ID',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  'Absent Days',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  'Half Days',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Attendance %',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Overtime Hours',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Employee rows - Interactive
                        ...filteredEmployees.map((employee) {
                          final attendancePercentage = (employee['attendance_percentage'] as num?)?.toDouble() ?? 0.0;
                          final absentDays = employee['absent_days'] ?? 0;
                          final halfDays = employee['half_days'] ?? 0;
                          final overtimeHours = (employee['overtime_hours'] as num?)?.toDouble() ?? 0.0;
                          
                          Color percentageColor;
                          if (attendancePercentage >= 90) {
                            percentageColor = Colors.green[700]!;
                          } else if (attendancePercentage >= 80) {
                            percentageColor = Colors.orange[700]!;
                          } else {
                            percentageColor = Colors.red[700]!;
                          }
                          
                          return InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(employee['employee_name'] as String? ?? 'N/A'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Employee ID: ${employee['employee_number'] ?? 'N/A'}'),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Attendance',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                '${attendancePercentage.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: percentageColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Absent Days',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                '$absentDays',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Half Days',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                '$halfDays',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Overtime Hours: ${overtimeHours.toStringAsFixed(1)} hrs',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.teal[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        employee['employee_name'] as String? ?? 'N/A',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        employee['employee_number'] as String? ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                          fontFamily: 'monospace',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 80,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$absentDays',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 80,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$halfDays',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 100,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: percentageColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${attendancePercentage.toStringAsFixed(1)}%',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: percentageColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        '${overtimeHours.toStringAsFixed(1)} hrs',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal[700],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.visibility,
                                      color: Colors.teal[600],
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  // Project viewing methods (for client, agent, accessor, senior valuer)
  
  /// HR Staff - Leave tab body (like admin "Leave" navigation)
  Widget _buildHRLeaveTabBody() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserData();
        await _loadLeaveStatistics();
        await _loadMonthlyLeaveSummary();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card with Quick Actions
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.purple,
                          child: Icon(Icons.event_note,
                              size: 30, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Leave Management',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Welcome, $_username!',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ViewLeaveRequestsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.purple[200]!),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_calendar, color: Colors.purple[700], size: 18),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'View',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            onTap: _selectMonthYear,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.blue[700], size: 18),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Month',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Monthly Leave Summary
            _buildMonthlyLeaveSummarySection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMonthlyLeaveSummarySection() {
    // Only show for HR staff
    if (widget.role != 'hr_staff') {
      return const SizedBox.shrink();
    }
    
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_note, color: Colors.purple[700], size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Monthly Leave Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectMonthYear,
                  tooltip: 'Select Month & Year',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadMonthlyLeaveSummary,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${monthNames[_selectedMonth - 1]} $_selectedYear',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingLeaveSummary)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_monthlyLeaveSummary.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No leave records for this month',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Emp ID',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[900],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Employee Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[900],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Leave Taken',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[900],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Employee rows - Interactive
                  ..._monthlyLeaveSummary.map((employee) {
                    final leaveDays = employee['leave_taken'] as int;
                    return InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(employee['employee_name'] as String),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Employee ID: ${employee['employee_id']}'),
                                const SizedBox(height: 8),
                                Text('Leave Taken: $leaveDays day(s)'),
                                const SizedBox(height: 8),
                                Text(
                                  'Month: ${monthNames[_selectedMonth - 1]} $_selectedYear',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  employee['employee_id'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  employee['employee_name'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: leaveDays > 5 
                                              ? Colors.red[100] 
                                              : leaveDays > 2 
                                                  ? Colors.orange[100] 
                                                  : Colors.green[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$leaveDays day(s)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: leaveDays > 5 
                                                ? Colors.red[700] 
                                                : leaveDays > 2 
                                                    ? Colors.orange[700] 
                                                    : Colors.green[700],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey[400],
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// HR Staff - Payments tab body (like admin "Payments" navigation)
  Widget _buildHRPaymentsTabBody() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserData();
        await _loadSummary();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card with Quick Stats
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.green,
                          child: Icon(Icons.payment,
                              size: 30, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payments',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Welcome, $_username!',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Quick Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const PaymentSlipsScreen(role: 'hr_staff'),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long, color: Colors.blue[700], size: 24),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'View All',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _createPaymentSlips,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.add_circle, color: Colors.green[700], size: 24),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Create',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _uploadPaymentSlips,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.upload_file, color: Colors.orange[700], size: 24),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Upload',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Profile tab with subtabs (Attendance, Payment, Leave)
  Widget _buildProfileTabBody() {
    if (_profileTabController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // If embedded or used as a nested tab (e.g., inside Projects tab structure),
    // we need to show the subtabs. Otherwise, subtabs are shown in AppBar bottom
    if (widget.isEmbedded || (_shouldShowProjects && _mainTabController != null)) {
      // Nested/embedded structure - show subtabs here
      return Column(
        children: [
          // Subtabs for Profile (shown here for nested/embedded case)
          TabBar(
            controller: _profileTabController,
            tabs: [
              Tab(
                icon: Icon(Icons.calendar_today, color: Colors.blue[600]),
                text: 'Attendance',
              ),
              Tab(
                icon: Icon(Icons.event_note, color: Colors.orange[600]),
                text: 'Leave',
              ),
              Tab(
                icon: Icon(Icons.payment, color: Colors.green[600]),
                text: 'Payment',
              ),
            ],
          ),
          // Subtab content
          Expanded(
            child: TabBarView(
              controller: _profileTabController,
              children: [
                _buildProfileAttendanceSubtab(),
                _buildProfileLeaveSubtab(),
                _buildProfilePaymentSubtab(),
              ],
            ),
          ),
        ],
      );
    } else {
      // Subtabs are in AppBar bottom, just show the content
      // TabBarView must be used directly when subtabs are in AppBar
      return TabBarView(
        controller: _profileTabController!,
        children: [
          _buildProfileAttendanceSubtab(),
          _buildProfileLeaveSubtab(),
          _buildProfilePaymentSubtab(),
        ],
      );
    }
  }

  /// Profile - Attendance subtab
  Widget _buildProfileAttendanceSubtab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserData();
        await _loadTodayAttendance();
        await _loadSummary();
        // Weekly Attendance Summary is not shown in Profile tab (only in View tab or main dashboard)
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTodayAttendanceCard(),
            const SizedBox(height: 16),
            _buildSummarySection(),
            const SizedBox(height: 16),
            if (_summary != null) _buildChartsSection(),
          ],
        ),
      ),
    );
  }

  /// Profile - Payment subtab
  Widget _buildProfilePaymentSubtab() {
    return PaymentSlipsScreen(
      role: widget.role,
      showAppBar: false, // No AppBar when embedded as subtab
      showOnlyOwn: true, // Always show only own payment slips in Profile tab
    );
  }

  /// Profile - Leave subtab
  Widget _buildProfileLeaveSubtab() {
    // Check if leave request buttons should be shown (exclude client, agent, admin)
    // HR staff can now see leave request buttons in Profile tab
    final showLeaveRequestButtons = widget.role != 'client' && 
                                   widget.role != 'agent' && 
                                   widget.role != 'admin';
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserData();
        await _loadLeaveStatistics();
        // Don't load monthly leave summary for HR staff in Profile tab (they have View tab)
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLeaveStatisticsSection(),
            // Leave Request Buttons - Show for roles except client, agent, admin
            // Now includes HR staff
            if (showLeaveRequestButtons) ...[
              const SizedBox(height: 24),
              _buildLeaveRequestButtonsSection(),
            ],
            // Monthly Leave Summary - Not shown for HR staff in Profile tab (they have View tab)
          ],
        ),
      ),
    );
  }

  /// Build Leave Request Buttons Section
  Widget _buildLeaveRequestButtonsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_note, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Leave Requests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LeaveRequestScreen(),
                        ),
                      ).then((_) {
                        // Refresh leave statistics after creating/updating leave request
                        _loadLeaveStatistics();
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Leave Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyLeaveRequestsScreen(),
                        ),
                      ).then((_) {
                        // Refresh leave statistics after viewing/updating leave requests
                        _loadLeaveStatistics();
                      });
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('View My Requests'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _createPaymentSlips() async {
    // Automatically generate payment slips for current month/year for all employees
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Payment Slips'),
        content: Text(
          'Generate payment slips for all employees for ${_getMonthName(currentMonth)} $currentYear.\n\nExisting payment slips for this month will be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final generateResult = await ApiService.generatePaymentSlips(
      month: currentMonth,
      year: currentYear,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (generateResult['success']) {
      final data = generateResult['data'];
      final generated = data['generated_count'] ?? 0;
      final updated = data['updated_count'] ?? 0;
      final total = data['total_count'] ?? 0;
      
      String message;
      if (total > 0) {
        if (generated > 0 && updated > 0) {
          message = 'Payment slips created successfully!\n$generated created, $updated updated\n(Total: $total employees)';
        } else if (updated > 0) {
          message = 'Payment slips updated successfully for $updated employees';
        } else {
          message = 'Payment slips created successfully for $generated employees';
        }
      } else {
        message = data['message'] ?? 'No payment slips generated. All eligible employees may already have payment slips for this month/year.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: total > 0 ? Colors.green : Colors.orange,
          duration: Duration(seconds: total > 0 ? 4 : 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(generateResult['message'] ?? 'Failed to create payment slips'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }

  Future<void> _uploadPaymentSlips() async {
    // Upload/publish payment slips for employees to view
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Payment Slips'),
        content: Text(
          'This will make payment slips visible to all employees for ${_getMonthName(currentMonth)} $currentYear.\n\nEmployees will be able to view their own payment slips after this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final uploadResult = await ApiService.uploadPaymentSlips(
      month: currentMonth,
      year: currentYear,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (uploadResult['success']) {
      final data = uploadResult['data'];
      final uploaded = data['uploaded_count'] ?? 0;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment slips uploaded successfully for $uploaded employees!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadResult['message'] ?? 'Failed to upload payment slips'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  // Project viewing methods (for client, agent, accessor, senior valuer)
  Widget _buildProjectsTab() {
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: _isLoadingProjects
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No projects assigned',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Projects assigned to you will appear here',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return _buildProjectCard(project);
                  },
                ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final priority = project.priority ?? 'medium';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _viewProjectDetails(project),
            borderRadius: BorderRadius.circular(12),
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
            ],
          ),
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
  
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red[600]!;
      case 'low':
        return Colors.green[600]!;
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
        return Colors.green[100]!;
      case 'cancelled':
        return Colors.red[100]!;
      default:
        return Colors.grey[200]!;
    }
  }

  Future<void> _viewProjectDetails(Project project) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(project.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (project.description != null) ...[
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(project.description!),
                const SizedBox(height: 16),
              ],
              Text(
                'Status: ${project.statusDisplay}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Priority: ${_formatPriorityLabel(project.priority ?? 'medium')}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Coordinator: ${project.coordinatorName ?? project.coordinatorUsername}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (project.documents.isNotEmpty) ...[
                const Text(
                  'Documents:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...project.documents.map((doc) => ListTile(
                      title: Text(doc.name),
                      subtitle: Text(doc.fileSizeFormatted),
                      trailing: doc.fileUrl != null
                          ? IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Download: ${doc.fileUrl}')),
                                );
                              },
                            )
                          : null,
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
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
                  // Check if it's after 12 PM
                  if (_isAfter12PM())
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Marked as Absent',
                                  style: TextStyle(
                                    color: Colors.red[900],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Attendance cannot be marked after 12 PM',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
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
                        label: Text(
                          _todayAttendance!.statusDisplay,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
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
                  
                  // Hide all buttons for absentees
                  if (_todayAttendance!.status != 'absent') ...[
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
                    
                    // Overtime Section (available from 5 PM to 8 AM, even if not checked out)
                    if (_isOvertimeAllowed()) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      if (_todayAttendance!.overtimeStart == null)
                        _buildStartOvertimeButton()
                      else if (_todayAttendance!.isOvertimeActive) ...[
                        // Overtime Countdown Timer
                        _buildOvertimeCountdown(),
                        const SizedBox(height: 16),
                        // End Overtime Button
                        _buildEndOvertimeButton(),
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
                  ] else ...[
                    // Show message for absentees
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.red[700], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You are marked as absent. Attendance actions are not available.',
                              style: TextStyle(
                                color: Colors.red[900],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                        label: Text(
                          _todayAttendance!.statusDisplay,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
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
                  
                  // Overtime Section (available from 5 PM to 8 AM, even if not checked out)
                  // Absentees cannot do overtime
                  if (_todayAttendance!.isCheckedIn && 
                      _todayAttendance!.status != 'absent' && 
                      _isOvertimeAllowed()) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    if (_todayAttendance!.overtimeStart == null)
                      _buildStartOvertimeButton()
                    else if (_todayAttendance!.isOvertimeActive) ...[
                      // Overtime Countdown Timer
                      _buildOvertimeCountdown(),
                      const SizedBox(height: 16),
                      // End Overtime Button
                      _buildEndOvertimeButton(),
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
            Text(
              'Attendance Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Period Selection Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200]?.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _periodTabController,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[700],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.today, size: 18),
                    text: 'Daily',
                  ),
                  Tab(
                    icon: Icon(Icons.date_range, size: 18),
                    text: 'Weekly',
                  ),
                  Tab(
                    icon: Icon(Icons.calendar_month, size: 18),
                    text: 'Monthly',
                  ),
                  Tab(
                    icon: Icon(Icons.calendar_today, size: 18),
                    text: 'Yearly',
                  ),
                ],
              ),
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

  Future<void> _loadLeaveStatistics() async {
    // Load for all non-admin roles
    if (widget.role == 'admin') {
      return;
    }
    
    setState(() => _isLoadingLeaveStats = true);
    
    final result = await ApiService.getMyLeaveStatistics();
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingLeaveStats = false;
      if (result['success']) {
        _leaveStatistics = result['data'];
      }
    });
  }

  Widget _buildLeaveStatisticsSection() {
    // Show for all non-admin roles
    if (widget.role == 'admin') {
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
            Row(
              children: [
                Icon(Icons.event_available, color: Colors.teal[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Leave Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingLeaveStats)
              const Center(child: CircularProgressIndicator())
            else if (_leaveStatistics != null)
              Row(
                children: [
                  Expanded(
                    child: _buildLeaveStatCard(
                      'Remaining Leaves',
                      '${_leaveStatistics!['remaining_leaves'] ?? 0}',
                      Colors.green,
                      Icons.event_available,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLeaveStatCard(
                      'Leave Taken',
                      '${_leaveStatistics!['leave_taken'] ?? 0}',
                      Colors.orange,
                      Icons.event_busy,
                    ),
                  ),
                ],
              )
            else
              const Center(child: Text('Unable to load leave statistics')),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
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

  Widget _buildPaymentSection() {
    // Show payment section for all non-admin roles
    if (widget.role == 'admin') {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.green[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Payment Slips',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'View your own monthly payment slips and salary information.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentSlipsScreen(
                      role: widget.role,
                      showOnlyOwn: true, // Always show only own payment slips in Profile tab
                    ),
                  ),
                ).catchError((error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening payment slips: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View My Payment Slips'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    if (_summary == null || _summary!.dailyData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Attendance Chart',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: _buildBarChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_summary == null || _summary!.dailyData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No data to display',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Process data based on selected period
    final processedData = _processChartData(_summary!.dailyData, _selectedPeriod);
    if (processedData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No data to display',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    final data = processedData;
    final maxHours = data.map((d) => d.workingHours).reduce((a, b) => a > b ? a : b);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: data.length * 50.0 > MediaQuery.of(context).size.width - 40
            ? data.length * 50.0
            : MediaQuery.of(context).size.width - 40,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxHours > 0 ? maxHours + 2 : 10,
            minY: 0,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 12,
                tooltipBgColor: Colors.blue[900]!.withOpacity(0.9),
                tooltipPadding: const EdgeInsets.all(12),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final chartData = data[groupIndex];
                  String tooltipText;
                  if (_selectedPeriod == 'daily') {
                    tooltipText = '${chartData.workingHours.toStringAsFixed(1)}h\n${_getStatusDisplay(chartData.status)}';
                  } else if (_selectedPeriod == 'weekly') {
                    tooltipText = 'Avg: ${chartData.workingHours.toStringAsFixed(1)}h\nWeek ${_formatWeekLabel(chartData.date)}';
                  } else if (_selectedPeriod == 'monthly') {
                    tooltipText = 'Avg: ${chartData.workingHours.toStringAsFixed(1)}h\n${DateFormat('MMM yyyy').format(chartData.date)}';
                  } else {
                    tooltipText = 'Avg: ${chartData.workingHours.toStringAsFixed(1)}h\n${DateFormat('yyyy').format(chartData.date)}';
                  }
                  return BarTooltipItem(
                    tooltipText,
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() < data.length && value.toInt() >= 0) {
                      final chartData = data[value.toInt()];
                      String label;
                      if (_selectedPeriod == 'daily') {
                        label = DateFormat('dd/MM').format(chartData.date);
                      } else if (_selectedPeriod == 'weekly') {
                        label = _formatWeekLabel(chartData.date);
                      } else if (_selectedPeriod == 'monthly') {
                        label = DateFormat('MMM').format(chartData.date);
                      } else {
                        label = DateFormat('yyyy').format(chartData.date);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
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
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        '${value.toInt()}h',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
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
              drawHorizontalLine: true,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[300]!.withOpacity(0.3),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                );
              },
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                left: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            barGroups: data.asMap().entries.map((entry) {
              final index = entry.key;
              final chartData = entry.value;
              // For aggregated views, use blue color; for daily, use status color
              final color = _selectedPeriod == 'daily' 
                  ? _getStatusColor(chartData.status)
                  : Colors.blue;
              
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: chartData.workingHours,
                    color: color,
                    width: 24,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxHours > 0 ? maxHours + 2 : 10,
                      color: Colors.grey[200]!.withOpacity(0.3),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'half_day':
        return 'Half Day';
      case 'absent':
        return 'Absent';
      default:
        return 'Unknown';
    }
  }

  // Process chart data based on selected period
  List<DailyAttendanceData> _processChartData(List<DailyAttendanceData> dailyData, String period) {
    if (period == 'daily') {
      // Return daily data as is
      return dailyData;
    } else if (period == 'weekly') {
      // Group by week and calculate average
      final Map<String, List<DailyAttendanceData>> weeklyGroups = {};
      for (var data in dailyData) {
        final weekKey = _getWeekKey(data.date);
        weeklyGroups.putIfAbsent(weekKey, () => []).add(data);
      }
      
      return weeklyGroups.entries.map((entry) {
        final avgHours = entry.value.map((d) => d.workingHours).reduce((a, b) => a + b) / entry.value.length;
        return DailyAttendanceData(
          date: entry.value.first.date, // Use first date of the week
          status: 'present', // Default for aggregated data
          workingHours: avgHours,
          overtimeHours: entry.value.map((d) => d.overtimeHours).reduce((a, b) => a + b) / entry.value.length,
        );
      }).toList()..sort((a, b) => a.date.compareTo(b.date));
    } else if (period == 'monthly') {
      // Group by month and calculate average
      final Map<String, List<DailyAttendanceData>> monthlyGroups = {};
      for (var data in dailyData) {
        final monthKey = '${data.date.year}-${data.date.month}';
        monthlyGroups.putIfAbsent(monthKey, () => []).add(data);
      }
      
      return monthlyGroups.entries.map((entry) {
        final avgHours = entry.value.map((d) => d.workingHours).reduce((a, b) => a + b) / entry.value.length;
        return DailyAttendanceData(
          date: DateTime(entry.value.first.date.year, entry.value.first.date.month, 1),
          status: 'present',
          workingHours: avgHours,
          overtimeHours: entry.value.map((d) => d.overtimeHours).reduce((a, b) => a + b) / entry.value.length,
        );
      }).toList()..sort((a, b) => a.date.compareTo(b.date));
    } else {
      // Group by year and calculate average
      final Map<int, List<DailyAttendanceData>> yearlyGroups = {};
      for (var data in dailyData) {
        final year = data.date.year;
        yearlyGroups.putIfAbsent(year, () => []).add(data);
      }
      
      return yearlyGroups.entries.map((entry) {
        final avgHours = entry.value.map((d) => d.workingHours).reduce((a, b) => a + b) / entry.value.length;
        return DailyAttendanceData(
          date: DateTime(entry.key, 1, 1),
          status: 'present',
          workingHours: avgHours,
          overtimeHours: entry.value.map((d) => d.overtimeHours).reduce((a, b) => a + b) / entry.value.length,
        );
      }).toList()..sort((a, b) => a.date.compareTo(b.date));
    }
  }

  String _getWeekKey(DateTime date) {
    // Get the Monday of the week
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-W${_getWeekNumber(monday)}';
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday) / 7).ceil();
  }

  String _formatWeekLabel(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${DateFormat('dd/MM').format(monday)} - ${DateFormat('dd/MM').format(sunday)}';
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

  Widget _buildStartOvertimeButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Container(
            width: double.infinity,
            height: 70,
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
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _startOvertime,
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.1),
                child: Stack(
                  children: [
                    // Pulsing background effect
                    _PulsingButtonBackground(color: Colors.orange),
                    // Button content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.access_time,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Flexible(
                            child: Text(
                              'Start Overtime',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withOpacity(0.9),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOvertimeCountdown() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red[400]!,
                  Colors.orange[500]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Pulsing background animation
                _PulsingContainer(
                  color: Colors.red,
                ),
                // Content - Horizontal layout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Row(
                    children: [
                      // Icon on the left
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _RotatingIcon(
                          icon: Icons.timer_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Time and label in the center
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Time display with scale animation
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              builder: (context, scaleValue, child) {
                                return Transform.scale(
                                  scale: 0.8 + (0.2 * scaleValue),
                                  child: Text(
                                    _formatDuration(_overtimeDuration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Overtime Duration',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
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
          ),
        );
      },
    );
  }

  Widget _buildEndOvertimeButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Container(
            width: double.infinity,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red[400]!,
                  Colors.red[600]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.red.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _endOvertime,
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.1),
                child: Stack(
                  children: [
                    // Pulsing background effect
                    _PulsingButtonBackground(color: Colors.red),
                    // Button content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.stop_circle_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Flexible(
                            child: Text(
                              'End Overtime',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withOpacity(0.9),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

class _PulsingButtonBackground extends StatefulWidget {
  final Color color;

  const _PulsingButtonBackground({required this.color});

  @override
  State<_PulsingButtonBackground> createState() => _PulsingButtonBackgroundState();
}

class _PulsingButtonBackgroundState extends State<_PulsingButtonBackground>
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


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../models/attendance_model.dart';
import '../models/project_model.dart';
import '../models/valuation_model.dart';
import 'login_screen.dart';

class GenericDashboard extends StatefulWidget {
  final String role;
  final String roleDisplay;
  final bool isEmbedded;
  
  const GenericDashboard({
    super.key,
    required this.role,
    required this.roleDisplay,
    this.isEmbedded = false,
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
  TabController? _mainTabController; // For Attendance/Projects tabs
  
  // Project state (for roles that can view projects)
  List<Project> _projects = [];
  bool _isLoadingProjects = false;
  
  // Timer for countdown
  DateTime? _countdownEnd;
  Duration _remainingTime = Duration.zero;
  
  // Timer for overtime
  Duration _overtimeDuration = Duration.zero;
  
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
    
    _loadUserData();
    _loadTodayAttendance();
    _loadSummary();
    _startTimer();
  }

  @override
  void dispose() {
    _periodTabController.dispose();
    _mainTabController?.dispose();
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
        bottom: _shouldShowProjects && _mainTabController != null
            ? TabBar(
                controller: _mainTabController,
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
                  controller: _mainTabController,
                  children: [
                    _buildDashboardBody(),
                    _buildProjectsTab(),
                  ],
                )
              : _buildDashboardBody(),
    );
  }

  Widget _buildDashboardBody() {
    return RefreshIndicator(
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
    );
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

  Widget _buildHistoryTab() {
    // Get all valuations from all projects
    List<Valuation> allValuations = [];
    for (var project in _projects) {
      allValuations.addAll(project.valuations);
    }
    
    // Sort by date (newest first)
    allValuations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: allValuations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No valuation history yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All received valuations will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allValuations.length,
              itemBuilder: (context, index) {
                final valuation = allValuations[index];
                final project = _projects.firstWhere(
                  (p) => p.id == valuation.projectId,
                  orElse: () => _projects.first,
                );
                return _buildHistoryValuationCard(valuation, project);
              },
            ),
    );
  }

  Widget _buildHistoryValuationCard(Valuation valuation, Project project) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (valuation.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'reviewed':
        statusColor = Colors.blue;
        statusIcon = Icons.visibility;
        statusText = 'Reviewed (Pending Approval)';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      case 'submitted':
        statusColor = Colors.orange;
        statusIcon = Icons.send;
        statusText = 'Submitted';
        break;
      case 'draft':
        statusColor = Colors.grey;
        statusIcon = Icons.edit;
        statusText = 'Draft';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.description;
        statusText = valuation.statusDisplay;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewHistoryValuationDetails(valuation, project),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          valuation.categoryDisplay,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: _getShadeColor(statusColor, 700),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (valuation.rejectionReason != null && valuation.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.red[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rejection Reason: ${valuation.rejectionReason}',
                          style: TextStyle(
                            color: Colors.red[900],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Created: ${DateFormat('MMM dd, yyyy').format(valuation.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (valuation.submittedAt != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.send, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Submitted: ${DateFormat('MMM dd, yyyy').format(valuation.submittedAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewHistoryValuationDetails(Valuation valuation, Project project) async {
    // Fetch fresh project data
    final projectResult = await ApiService.getProject(project.id);
    Project? updatedProject = project;
    
    if (projectResult['success'] && projectResult['data'] != null) {
      try {
        updatedProject = Project.fromJson(projectResult['data']);
      } catch (e) {
        print('Error parsing updated project: $e');
      }
    }
    
    final finalProject = updatedProject ?? project;
    final updatedValuation = finalProject.valuations.firstWhere(
      (v) => v.id == valuation.id,
      orElse: () => valuation,
    );
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
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
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            finalProject.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            updatedValuation.categoryDisplay,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getValuationStatusColor(updatedValuation.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getValuationStatusColor(updatedValuation.status).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(updatedValuation.status),
                              color: _getValuationStatusColor(updatedValuation.status),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: ${updatedValuation.statusDisplay}',
                              style: TextStyle(
                                color: _getValuationStatusColor(updatedValuation.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Description
                      if (updatedValuation.description != null && updatedValuation.description!.isNotEmpty) ...[
                        const Text(
                          'Description:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(updatedValuation.description!),
                        const SizedBox(height: 16),
                      ],
                      // Estimated Value
                      if (updatedValuation.estimatedValue != null) ...[
                        const Text(
                          'Estimated Value:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rs. ${NumberFormat('#,##0.00').format(updatedValuation.estimatedValue)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Rejection Reason
                      if (updatedValuation.rejectionReason != null && updatedValuation.rejectionReason!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rejection Reason:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(updatedValuation.rejectionReason!),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Created:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(updatedValuation.createdAt),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          if (updatedValuation.submittedAt != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Submitted:',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(updatedValuation.submittedAt!),
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // View PDF Button (view-only, no accept/reject)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _viewValuationPDF(updatedValuation, finalProject);
                          },
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('View PDF Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'reviewed':
        return Icons.visibility;
      case 'rejected':
        return Icons.cancel;
      case 'submitted':
        return Icons.send;
      case 'draft':
        return Icons.edit;
      default:
        return Icons.description;
    }
  }

  Color _getValuationStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey[600]!;
      case 'submitted':
        return Colors.blue[600]!;
      case 'reviewed':
        return Colors.purple[600]!;
      case 'approved':
        return Colors.green[600]!;
      case 'rejected':
        return Colors.red[600]!;
      default:
        return Colors.grey[400]!;
    }
  }

  Future<void> _viewValuationPDF(Valuation valuation, Project project) async {
    try {
      final pdfFile = await PdfService.generateValuationReport(
        valuation: valuation,
        project: project,
      );
      await PdfService.saveAndOpenPdf(pdfFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error viewing PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getShadeColor(Color color, int shade) {
    if (color == Colors.green) return Colors.green[shade]!;
    if (color == Colors.blue) return Colors.blue[shade]!;
    if (color == Colors.red) return Colors.red[shade]!;
    if (color == Colors.orange) return Colors.orange[shade]!;
    if (color == Colors.grey) return Colors.grey[shade]!;
    return color;
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


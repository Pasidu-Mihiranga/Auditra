import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../services/offline_db_service.dart';
import '../services/sync_engine.dart';
import '../services/network_service.dart';
import '../models/attendance_model.dart';
import '../models/project_model.dart';
import '../models/valuation_model.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/shared_dashboard_widgets.dart';
import '../services/offline_storage_service.dart';
import 'field_officer/components/offline_queue_section.dart';
import 'field_officer/components/field_officer_project_card.dart';
import 'login_screen.dart';
import 'generic_dashboard.dart';
import 'valuation_form_screen.dart';
import 'field_officer/styles/field_officer_styles.dart';
import 'field_officer/components/field_officer_header.dart';
import 'field_officer/tabs/field_officer_projects_tab.dart';
import 'field_officer/utils/field_officer_document_manager.dart';
import 'field_officer/dialogs/project_details_modal.dart';
import 'field_officer/utils/field_officer_ui_helpers.dart';
import 'field_officer/dialogs/project_details_modal.dart';
import 'field_officer/dialogs/valuation_reports_modal.dart';

class FieldOfficerDashboard extends StatefulWidget {
  const FieldOfficerDashboard({super.key});

  @override
  State<FieldOfficerDashboard> createState() => _FieldOfficerDashboardState();
}

class _FieldOfficerDashboardState extends State<FieldOfficerDashboard> with TickerProviderStateMixin {
  Attendance? _todayAttendance;
  bool _isLoading = true;
  bool _isWorkingDay = true;
  String _selectedPeriod = 'daily';
  AttendanceSummary? _summary;
  bool _isLoadingSummary = false;
  bool _isMarkingAttendance = false;
  String? _username;
  String? _roleDisplay;
  
  // Project state
  List<Project> _projects = [];
  bool _isLoadingProjects = false;
  late TabController _tabController;
  
  // Timer for countdown
  DateTime? _countdownEnd;
  Duration _remainingTime = Duration.zero;
  
  // Network monitoring for auto-refresh
  StreamSubscription<bool>? _networkSubscription;
  
  // Sync event listener for refreshing offline queue
  Function(Map<String, dynamic>)? _syncListener;
  

  
  // Document Manager
  late FieldOfficerDocumentManager _documentManager;
  
  @override
  void initState() {
    super.initState();
    _documentManager = FieldOfficerDocumentManager(
      context: context,
      setState: setState,
    );
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _initOfflineMode();
    _loadUserInfo();
    _loadProjects();
    
    // Initialize network monitoring for auto-refresh
    _initNetworkMonitoring();
    
    // Initialize sync event listener
    _initSyncListener();
    
  }

  String _formatPriorityLabel(String priority) {
    if (priority.isEmpty) return 'Medium';
    final lower = priority.toLowerCase();
    if (lower == 'high') return 'High';
    if (lower == 'low') return 'Low';
    return 'Medium';
  }

  Future<void> _initOfflineMode() async {
    try {
      // Initialize offline mode for field officers
      await OfflineDBService.initOfflineDB();
      await NetworkService.init();
      await SyncEngine.init();
      
      // Clean up old synced valuations on startup
      final cleanedCount = await OfflineStorageService.cleanupSyncedValuations();
      if (cleanedCount > 0) {
        print('ðŸ§¹ Cleaned up $cleanedCount old synced valuations on startup');
      }
      
      // Delete all unsynced valuations that are failing (they have invalid data and can't sync)
      // This removes valuations that fail validation (like estimated_value > 15 digits)
      final deletedCount = await OfflineStorageService.deleteAllUnsyncedValuations();
      if (deletedCount > 0) {
        print('ðŸ—‘ï¸ Deleted $deletedCount unsynced valuations with invalid data on startup');
        // Refresh the UI after cleanup
        if (mounted) {
          setState(() {});
        }
      }
      
      print('âœ… Offline mode initialized for field officer');
    } catch (e) {
      print('Warning: Failed to initialize offline mode: $e');
    }
  }
  
  void _initNetworkMonitoring() {
    // NetworkService is already initialized in _initOfflineMode()
    _networkSubscription = NetworkService.networkStatusStream.listen((isOnline) {
      if (mounted) {
        print('ðŸ“¶ Field Officer Dashboard: Network status changed to ${isOnline ? "Online" : "Offline"}');
        // Refresh projects when network status changes
        _loadProjects();
      }
    });
  }
  
  void _initSyncListener() {
    // Listen to sync events to refresh offline queue when valuations are synced
    _syncListener = (event) {
      if (mounted) {
        final eventType = event['event'] as String?;
        if (eventType == 'syncComplete' || eventType == 'valuationSynced' || eventType == 'syncSuccess') {
          print('ðŸ”„ Sync event received: $eventType - Refreshing offline queue and projects');
          // Trigger rebuild to refresh offline queue (reads from local storage)
          // Also reload projects to get updated valuations from server
          setState(() {});
          _loadProjects();
        }
      }
    };
    SyncEngine.addListener(_syncListener!);
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    if (_syncListener != null) {
      SyncEngine.removeListener(_syncListener!);
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final username = await ApiService.getUsername();
    final roleResult = await ApiService.getMyRole();
    if (mounted) {
      setState(() {
        _username = username;
        if (roleResult['success']) {
          _roleDisplay = roleResult['data']['role_display'];
        }
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
  }

  Future<void> _loadTodayAttendance() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getTodayAttendance();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
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

  Future<void> _loadProjects() async {
    // Only show loading indicator if we don't have projects yet (initial load)
    final isInitialLoad = _projects.isEmpty;
    
    if (isInitialLoad) {
      setState(() {
        _isLoading = true;
        _isLoadingProjects = true;
      });
    }
    
    final result = await ApiService.getProjects();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoadingProjects = false;
        if (result['success']) {
          try {
            final data = result['data'] as List<dynamic>;
            _projects = data.map((p) => Project.fromJson(p)).toList();
          } catch (e) {
            print('Error parsing projects: $e');
            print('Response data: ${result['data']}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading projects: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load projects: ${result['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
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
              backgroundColor: const Color(0xFF84BCDA),
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
          _loadTodayAttendance();
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
        _loadTodayAttendance();
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
        _loadTodayAttendance();
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
        _loadTodayAttendance();
        _loadSummary();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to end overtime')),
        );
      }
    }
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
                  color: Colors.orange[500]!,
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
                        color: Colors.orange[400]!,
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }









  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _username != null || _roleDisplay != null
            ? Row(
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
                            size: 16,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.9)
                                : Colors.black87.withOpacity(0.8),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _username!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.95)
                                    : Colors.black87,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_username != null && _roleDisplay != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Container(
                        width: 1,
                        height: 18,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black26,
                      ),
                    ),
                  if (_roleDisplay != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                              size: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.blue[700],
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _roleDisplay!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.blue[900],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            : null,
        centerTitle: true,
        actions: [
          const SyncStatusIndicator(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.access_time), text: 'Attendance'),
            Tab(icon: Icon(Icons.folder), text: 'Projects'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                GenericDashboard(
                  role: 'field_officer',
                  roleDisplay: _roleDisplay ?? 'Field Officer',
                  isEmbedded: true,
                ),
                _buildProjectsTab(),
              ],
            ),
    );
  }

  List<Project> _filterAndSortProjects(List<Project> projects) {
    // Get search query
    final searchQuery = _searchController.text.toLowerCase().trim();
    
    // Filter by search query
    var filtered = projects.where((p) {
      if (searchQuery.isEmpty) return true;
      return p.title.toLowerCase().contains(searchQuery) ||
          (p.description?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();
    
    // Sort projects
    switch (_sortOption) {
      case 'date_desc':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'title_asc':
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'title_desc':
        filtered.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'priority':
        final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
        filtered.sort((a, b) {
          final aPriority = priorityOrder[a.priority?.toLowerCase() ?? 'medium'] ?? 2;
          final bPriority = priorityOrder[b.priority?.toLowerCase() ?? 'medium'] ?? 2;
          if (aPriority != bPriority) return bPriority.compareTo(aPriority);
          return a.createdAt.compareTo(b.createdAt);
        });
        break;
      case 'date_asc':
      default:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }
    
    return filtered;
  }

  Widget _buildProjectsTab() {
    final filteredProjects = _filterAndSortProjects(_projects);
    
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: _isLoadingProjects && _projects.isEmpty
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
              : Column(
                  children: [
                    _buildOfflineQueueSection(),
                    // Search and Sort Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.white,
                      child: Row(
                        children: [
                          // Search field
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search projects...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Sort dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue[200]!, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey[200]!,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sort, size: 20, color: Colors.blue[700]),
                                const SizedBox(width: 6),
                                DropdownButton<String>(
                                  value: _sortOption,
                                  underline: const SizedBox(),
                                  icon: Icon(Icons.arrow_drop_down, size: 22, color: Colors.blue[700]),
                                  isDense: false,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[900],
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'date_asc',
                                      child: Text('Date ↑', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ),
                                    DropdownMenuItem(
                                      value: 'date_desc',
                                      child: Text('Date ↓', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ),
                                    DropdownMenuItem(
                                      value: 'title_asc',
                                      child: Text('Title A-Z', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ),
                                    DropdownMenuItem(
                                      value: 'title_desc',
                                      child: Text('Title Z-A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ),
                                    DropdownMenuItem(
                                      value: 'priority',
                                      child: Text('Priority', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _sortOption = value!;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredProjects.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No projects found',
                                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your search criteria',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredProjects.length,
                              itemBuilder: (context, index) {
                                final project = filteredProjects[index];
                                return _buildProjectCard(project);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOfflineQueueSection() {
    final unsyncedValuations = OfflineStorageService.getUnsyncedValuations();
    final isOnline = NetworkService.isOnline;
    
    // Don't show queue if there are no unsynced items
    if (unsyncedValuations.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.orange[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Offline Queue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  '${unsyncedValuations.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                backgroundColor: Colors.orange[700],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isOnline 
              ? 'Syncing reports... They will be submitted automatically.'
              : 'Reports saved offline. They will be submitted when internet connects.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 12),
          ...unsyncedValuations.take(3).map((valuation) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.description, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${valuation['category'] ?? 'Valuation'} - ${valuation['description'] ?? 'No description'}',
                    style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isOnline)
                  Icon(Icons.cloud_off, size: 16, color: Colors.orange[700]),
              ],
            ),
          )),
          if (unsyncedValuations.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'And ${unsyncedValuations.length - 3} more...',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.orange[700],
                ),
              ),
            ),
        ],
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20), // Space for priority label
                  // Show MD/GM approval/rejection status
                  if (project.mdGmApprovalStatus == 'approved') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Project Approved by MD/GM',
                              style: TextStyle(
                                color: Colors.green[900],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (project.mdGmApprovalStatus == 'rejected') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Project Rejected by MD/GM',
                                  style: TextStyle(
                                    color: Colors.red[900],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (project.mdGmRejectionReason != null && project.mdGmRejectionReason!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Reason: ${project.mdGmRejectionReason}',
                              style: TextStyle(
                                color: Colors.red[800],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
            ),
    );
  }







  Future<void> _viewProjectDetails(Project project) async {
    // Fetch fresh project data to ensure valuations are loaded
    final projectResult = await ApiService.getProject(project.id);
    Project? updatedProject = project;
    
    if (projectResult['success'] && projectResult['data'] != null) {
      try {
        updatedProject = Project.fromJson(projectResult['data']);
        print('Loaded project with ${updatedProject.valuations.length} valuations');
        print('Valuations count: ${updatedProject.valuationsCount}');
      } catch (e) {
        print('Error parsing updated project: $e');
        print('Error details: ${e.toString()}');
        // Fall back to original project if parsing fails
      }
    } else {
      print('Failed to fetch project data: ${projectResult['message']}');
    }
    
    // Ensure updatedProject is never null
    final finalProject = updatedProject ?? project;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => ProjectDetailsModal(project: finalProject),
    );
  }

  Future<void> _viewValuationReports(Project project) async {
    // Fetch fresh project data to ensure valuations are loaded
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20)),
        child: Container(
          width: screenWidth * (isSmallScreen ? 0.95 : 0.9),
          constraints: BoxConstraints(
            maxHeight: screenHeight * (isSmallScreen ? 0.9 : 0.85),
          ),
          child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
              // Header with gradient
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.blue[500]!,
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
                        color: Colors.blue[400]!,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.assessment, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Valuation Reports',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            finalProject.title,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                            IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Generated Reports Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.assessment, color: Colors.blue[700], size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Generated Reports',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[700],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '${finalProject.valuations.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            if (finalProject.valuations.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.description_outlined, size: 48, color: Colors.grey[400]),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No reports generated yet',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Create a valuation report to get started',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                child: Column(
                                  children: finalProject.valuations.map((valuation) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: _getValuationStatusColor(valuation.status).withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.description,
                                                      color: _getValuationStatusColor(valuation.status),
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        valuation.categoryDisplay,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: _getValuationStatusColor(valuation.status).withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          valuation.status == 'draft' ? 'Saved' : valuation.statusDisplay,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                            color: _getValuationStatusColor(valuation.status),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
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
                                              ],
                                            ),
                                            // Assessor and Senior Valuer Status
                                            if (valuation.status != 'draft' && valuation.status != 'submitted') ...[
                                              const SizedBox(height: 12),
                                              const Divider(height: 1),
                                              const SizedBox(height: 12),
                                              _buildReviewerStatusSection(valuation),
                                            ],
                                            const SizedBox(height: 12),
                                            // Action buttons row
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange[50],
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.article, size: 20),
                                                    color: Colors.orange[700],
                                                    tooltip: 'Generate PDF Report',
                                                    padding: const EdgeInsets.all(8),
                                                    constraints: const BoxConstraints(
                                                      minWidth: 40,
                                                      minHeight: 40,
                                                    ),
                                                    onPressed: () async {
                                                      await _generatePdfReport(valuation, finalProject);
                                                    },
                                                  ),
                                                ),
                                                // Show edit button if valuation can be edited (within 2 days of creation) and not rejected
                                                if (_canEditValuation(valuation) && valuation.status != 'rejected') ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue[50],
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: IconButton(
                                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                                      color: Colors.blue[700],
                                                      tooltip: 'Edit Report',
                                                      padding: const EdgeInsets.all(8),
                                                      constraints: const BoxConstraints(
                                                        minWidth: 40,
                                                        minHeight: 40,
                                                      ),
                                                      onPressed: () async {
                                                        Navigator.of(context).pop();
                                                        final result = await Navigator.of(context).push(
                                                          MaterialPageRoute(
                                                            builder: (_) => ValuationFormScreen(
                                                              project: finalProject,
                                                              existingValuation: valuation,
                                                            ),
                                                          ),
                                                        );
                                                        // Refresh projects when form returns (valuation saved/submitted)
                                                        if (result == true) {
                                                          _loadProjects();
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ],
                                                // Show delete button if valuation was created within 2 days
                                                if (_canDeleteValuation(valuation)) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.red[50],
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 20),
                                                      color: Colors.red[700],
                                                      tooltip: 'Delete Report',
                                                      padding: const EdgeInsets.all(8),
                                                      constraints: const BoxConstraints(
                                                        minWidth: 40,
                                                        minHeight: 40,
                                                      ),
                                                      onPressed: () async {
                                                        await _deleteValuation(valuation, finalProject);
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            // Show "Update the report" button for rejected valuations (full-width button)
                                            if (valuation.status == 'rejected') ...[
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  onPressed: () async {
                                                    Navigator.of(context).pop();
                                                    final result = await Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) => ValuationFormScreen(
                                                          project: finalProject,
                                                          existingValuation: valuation,
                                                        ),
                                                      ),
                                                    );
                                                    // Refresh projects when form returns (valuation saved/submitted)
                                                    if (result == true) {
                                                      _loadProjects();
                                                    }
                                                  },
                                                  icon: const Icon(Icons.update, size: 20),
                                                  label: const Text(
                                                    'Update the report',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green[700],
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ),
            ],
          ),
        ),
                    ],
                  ),
                ),
              ),
              // Footer Actions
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () async {
              Navigator.of(context).pop();
                      final result = await Navigator.of(context).push(
                MaterialPageRoute(
                          builder: (_) => ValuationFormScreen(project: finalProject),
                        ),
                      );
                      // Refresh projects when form returns (valuation saved/submitted)
                      if (result == true) {
                        _loadProjects();
                      }
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add_rounded, size: 20),
                    ),
                    label: const Text(
                      'Create New Report',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoCard({
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  /// Build reviewer status section showing assessor and senior valuer status
  Widget _buildReviewerStatusSection(Valuation valuation) {
    // Determine assessor status
    // Logic: If status is 'reviewed' or 'approved', assessor accepted
    // If status is 'rejected' and has senior_valuer_comments, assessor accepted (it reached senior valuer)
    // If status is 'rejected' and no senior_valuer_comments, assessor rejected
    String assessorStatus;
    Color assessorStatusColor;
    IconData assessorStatusIcon;
    String? assessorRejectionReason;
    
    final hasSeniorValuerComments = valuation.seniorValuerComments != null && 
                                     valuation.seniorValuerComments!.isNotEmpty;
    
    if (valuation.status == 'reviewed' || valuation.status == 'approved') {
      assessorStatus = 'Accepted';
      assessorStatusColor = Colors.green;
      assessorStatusIcon = Icons.check_circle;
    } else if (valuation.status == 'rejected') {
      if (hasSeniorValuerComments) {
        // Reached senior valuer, so assessor accepted it first
        assessorStatus = 'Accepted';
        assessorStatusColor = Colors.green;
        assessorStatusIcon = Icons.check_circle;
      } else {
        // Rejected by assessor (never reached senior valuer)
        assessorStatus = 'Rejected';
        assessorStatusColor = Colors.red;
        assessorStatusIcon = Icons.cancel;
        assessorRejectionReason = valuation.rejectionReason;
      }
    } else {
      assessorStatus = 'Pending';
      assessorStatusColor = Colors.orange;
      assessorStatusIcon = Icons.pending;
    }
    
    // Determine senior valuer status
    // Logic: If status is 'approved', senior valuer accepted
    // If status is 'reviewed', pending senior valuer review
    // If status is 'rejected' and has senior_valuer_comments, senior valuer rejected
    // Otherwise, not applicable (never reached senior valuer)
    String seniorValuerStatus;
    Color seniorValuerStatusColor;
    IconData seniorValuerStatusIcon;
    String? seniorValuerRejectionReason;
    
    if (valuation.status == 'approved') {
      seniorValuerStatus = 'Accepted';
      seniorValuerStatusColor = Colors.green;
      seniorValuerStatusIcon = Icons.check_circle;
    } else if (valuation.status == 'reviewed') {
      seniorValuerStatus = 'Pending Review';
      seniorValuerStatusColor = Colors.blue;
      seniorValuerStatusIcon = Icons.pending;
    } else if (valuation.status == 'rejected' && hasSeniorValuerComments) {
      // Rejected by senior valuer (it was reviewed first, so assessor accepted)
      seniorValuerStatus = 'Rejected';
      seniorValuerStatusColor = Colors.red;
      seniorValuerStatusIcon = Icons.cancel;
      seniorValuerRejectionReason = valuation.rejectionReason;
    } else {
      seniorValuerStatus = 'Not Applicable';
      seniorValuerStatusColor = Colors.grey;
      seniorValuerStatusIcon = Icons.remove_circle_outline;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Status:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        // Assessor Status
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: assessorStatusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: assessorStatusColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(assessorStatusIcon, size: 16, color: assessorStatusColor),
                  const SizedBox(width: 6),
                  const Text(
                    'Assessor:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    assessorStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: assessorStatusColor,
                    ),
                  ),
                ],
              ),
              if (assessorRejectionReason != null && assessorRejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    'Reason: $assessorRejectionReason',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Senior Valuer Status
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: seniorValuerStatusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: seniorValuerStatusColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(seniorValuerStatusIcon, size: 16, color: seniorValuerStatusColor),
                  const SizedBox(width: 6),
                  const Text(
                    'Senior Valuer:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    seniorValuerStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: seniorValuerStatusColor,
                    ),
                  ),
                ],
              ),
              if (seniorValuerRejectionReason != null && seniorValuerRejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    'Reason: $seniorValuerRejectionReason',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              if (valuation.seniorValuerComments != null && 
                  valuation.seniorValuerComments!.isNotEmpty && 
                  valuation.status != 'rejected') ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    'Comments: ${valuation.seniorValuerComments}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Check if a valuation can be edited (created within 2 days)
  bool _canEditValuation(Valuation valuation) {
    final now = DateTime.now();
    final createdAt = valuation.createdAt;
    final difference = now.difference(createdAt);
    
    // Allow editing if created within 2 days (48 hours)
    return difference.inDays < 2;
  }




  Future<void> _submitReportsToAccessor(Project project) async {
    // Check if accessor is assigned
    if (project.assignedAccessorId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No accessor assigned to this project. Please contact the coordinator.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Fetch fresh project data to ensure valuations are loaded
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
    
    // Filter draft valuations
    final draftValuations = finalProject.valuations.where((v) => v.status == 'draft').toList();
    
    if (draftValuations.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No draft reports to submit. All reports are already submitted.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Reports to Accessor'),
        content: Text(
          'Are you sure you want to submit ${draftValuations.length} report(s) to ${finalProject.assignedAccessorName ?? finalProject.assignedAccessorUsername ?? 'the accessor'} for review?\n\n'
          'Once submitted, you will not be able to edit these reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting reports...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    int successCount = 0;
    int failCount = 0;
    List<String> errors = [];

    // Submit each draft valuation
    for (var valuation in draftValuations) {
      try {
        final result = await ApiService.submitValuation(valuation.id);
        if (result['success']) {
          successCount++;
        } else {
          failCount++;
          errors.add('${valuation.categoryDisplay}: ${result['message'] ?? 'Failed to submit'}');
        }
      } catch (e) {
        failCount++;
        errors.add('${valuation.categoryDisplay}: ${e.toString()}');
      }
    }

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Show results
    if (mounted) {
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully submitted $successCount report(s) to the accessor!'),
            backgroundColor: const Color(0xFF84BCDA),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submitted $successCount report(s), but $failCount failed. ${errors.join('; ')}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit reports. ${errors.join('; ')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      // Refresh projects list
      await _loadProjects();
    }
  }

  Future<void> _generatePdfReport(Valuation valuation, Project project) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating PDF report...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Generate PDF
      print('Generating PDF for valuation ${valuation.id}, category: ${valuation.category}, statusDisplay: ${valuation.statusDisplay}');
      final pdfFile = await PdfService.generateValuationReport(
        valuation: valuation,
        project: project,
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Share/Print the PDF
      if (context.mounted) {
        try {
          await PdfService.sharePdf(
            pdfFile,
            subject: 'Valuation Report - ${valuation.categoryDisplay}',
          );
        } catch (shareError) {
          print('Error sharing PDF: $shareError');
          // Try alternative method
          if (context.mounted) {
            await PdfService.saveAndOpenPdf(pdfFile);
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report generated successfully!'),
            backgroundColor: const Color(0xFF84BCDA),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error generating PDF: $e');
    }
  }

  Widget _buildInfoCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
                  
                  // Countdown timer
                  if (_todayAttendance!.isCheckedIn && !_todayAttendance!.isCheckedOut) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Time Remaining',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(_remainingTime),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Until 5:00 PM',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                    const SizedBox(height: 16),
                    
                    // Leave Early Button
                    OutlinedButton.icon(
                      onPressed: _leaveEarly,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Leave Early'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
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
                      _buildStartOvertimeButton()
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

  // ignore: unused_element
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
                          const Color(0xFF84BCDA),
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
                          const Color(0xFF0570B0),
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

  // ignore: unused_element
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
        return const Color(0xFF84BCDA);
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
            const Color(0xFF84BCDA)!,
            const Color(0xFF0570B0)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF84BCDA).withOpacity(0.4),
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
                    'All submitted valuations will appear here',
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


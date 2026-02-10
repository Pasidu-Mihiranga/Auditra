import 'package:flutter/material.dart';



import 'coordinator/components/coordinator_header.dart';
import 'coordinator/components/coordinator_bottom_nav.dart';
import 'coordinator/components/coordinator_project_list.dart';
import 'coordinator/components/project_edit_dialog.dart';
import 'coordinator/components/coordinator_actions.dart';
import 'coordinator/components/coordinator_attendance_widgets.dart';
import 'coordinator/components/coordinator_workflow.dart';
import 'coordinator/components/coordinator_document_manager.dart';
import 'coordinator/components/coordinator_ui_builders.dart';
import 'coordinator/styles/coordinator_styles.dart';
import 'coordinator/utils/responsive_utils.dart';
import 'coordinator/utils/project_report_handler.dart';
import 'coordinator/dialogs/field_officer_assignment_dialog.dart';
import 'coordinator/dialogs/client_assignment_dialog.dart';
import 'coordinator/dialogs/agent_assignment_dialog.dart';
import 'coordinator/tabs/coordinator_projects_tab.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'dart:async';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../models/attendance_model.dart';

import 'coordinator/dialogs/status_update_dialog.dart';
import 'coordinator/dialogs/documents_dialog.dart';
import 'coordinator/dialogs/logout_dialog.dart';
import 'coordinator/tabs/coordinator_home_tab.dart';

import 'coordinator/dialogs/assign_users_dialog.dart';
import '../models/project_model.dart';
import '../models/valuation_model.dart';
import 'login_screen.dart';
import 'generic_dashboard.dart';
import 'create_project_screen.dart';
import 'project_details_screen.dart';

// Helper class to hold upload dialog state


class CoordinatorDashboard extends StatefulWidget {
  const CoordinatorDashboard({super.key});

  @override
  State<CoordinatorDashboard> createState() => _CoordinatorDashboardState();
}

class _CoordinatorDashboardState extends State<CoordinatorDashboard> with TickerProviderStateMixin {
  bool _isCreatingProject = false;
  // User info
  String? _username;
  String? _roleDisplay;
  
  // Legacy attendance state (attendance UI now comes from GenericDashboard but these remain for compatibility)
  Attendance? _todayAttendance;
  bool _isWorkingDay = true;
  String _selectedPeriod = 'daily';
  AttendanceSummary? _summary;
  bool _isLoadingSummary = false;
  bool _isMarkingAttendance = false;
  DateTime? _countdownEnd;
  Duration _remainingTime = Duration.zero;
  
  // Project state
  List<Project> _projects = [];
  bool _isLoadingProjects = false;
  // Track projects that have been recreated (to hide recreate button)
  Set<int> _recreatedProjectIds = {};
  // Track which projects were recreated from which original projects (newProjectId -> originalProjectTitle)
  Map<int, String> _recreatedFromProjects = {};
  // Store original project info when recreating (to map after creation)
  String? _pendingRecreationOriginalTitle;
  bool _isCreatingProject = false;
  // Search and sort state for each tab

 // 'date_asc', 'date_desc', 'title_asc', 'title_desc', 'priority'
  late TabController _tabController;
  TabController? _projectSubTabController;
  
  // Swipe gesture tracking




  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    // Dispose old controller if it exists (for hot reload)
    _projectSubTabController?.dispose();
    _projectSubTabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _projectSubTabController!.addListener(() {
      if (!_projectSubTabController!.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _loadUserInfo();
    _loadProjects();
    _loadRecreatedProjectIds();
  }

  @override
  void dispose() {
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _countdownEnd = DateTime(today.year, today.month, today.day, 17, 0);
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

  Future<void> _loadProjects() async {
    setState(() => _isLoadingProjects = true);
    final result = await ApiService.getProjects();
    
    if (mounted) {
      setState(() {
        _isLoadingProjects = false;
        if (result['success']) {
          try {
            final data = result['data'] as List<dynamic>;
            _projects = data.map((p) => Project.fromJson(p)).toList();
            // Sort by creation date (oldest first - creation order)
            _projects.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          } catch (e) {
            print('Error parsing projects: $e');
            print('Response data: ${result['data']}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading projects: $e'),
                backgroundColor: Colors.red,
              ),
            );
            _projects = [];
          }
        } else {
          // Show error message if loading fails
          if (result['message'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Failed to load projects'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          _projects = [];
        }
      });
      
      // Reload recreated project IDs after projects are loaded to ensure sync
      await _loadRecreatedProjectIds();
    }
  }

  Future<void> _loadRecreatedProjectIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recreatedIdsJson = prefs.getString('recreated_project_ids');
      print('🔍 Loading recreated project IDs from SharedPreferences...');
      print('📦 Raw JSON: $recreatedIdsJson');
      
      if (recreatedIdsJson != null) {
        final List<dynamic> idsList = jsonDecode(recreatedIdsJson);
        _recreatedProjectIds = idsList.map((id) {
          // Handle both int and String types
          if (id is int) return id;
          if (id is String) return int.tryParse(id) ?? 0;
          return id as int;
        }).where((id) => id > 0).toSet();
        print('✅ Loaded ${_recreatedProjectIds.length} recreated project IDs: $_recreatedProjectIds');
      } else {
        print('⚠️ No recreated project IDs found in SharedPreferences');
      }
      
      final recreatedFromJson = prefs.getString('recreated_from_projects');
      if (recreatedFromJson != null) {
        final Map<String, dynamic> map = jsonDecode(recreatedFromJson);
        _recreatedFromProjects = map.map((key, value) => MapEntry(int.parse(key), value as String));
        print('✅ Loaded ${_recreatedFromProjects.length} recreated from mappings');
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error loading recreated project IDs: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _saveRecreatedProjectIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsList = _recreatedProjectIds.toList();
      final idsJson = jsonEncode(idsList);
      await prefs.setString('recreated_project_ids', idsJson);
      
      final fromMap = _recreatedFromProjects.map((key, value) => MapEntry(key.toString(), value));
      final fromJson = jsonEncode(fromMap);
      await prefs.setString('recreated_from_projects', fromJson);
      
      print('💾 Saved ${_recreatedProjectIds.length} recreated project IDs: $_recreatedProjectIds');
      print('💾 Saved JSON: $idsJson');
    } catch (e) {
      print('❌ Error saving recreated project IDs: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _markAttendance() async {
    setState(() => _isMarkingAttendance = true);
    
    try {
      final result = await ApiService.markAttendance();
      
      if (mounted) {
        if (result['success']) {
          final responseData = result['data'];
          if (responseData != null && responseData['data'] != null) {
            setState(() {
              _todayAttendance = Attendance.fromJson(responseData['data']);
            });
            _startTimer();
          } else {
            await _loadTodayAttendance();
            _startTimer();
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Attendance marked successfully!')),
                ],
              ),
              backgroundColor: const Color(0xFF84BCDA),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to mark attendance')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isMarkingAttendance = false);
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

  Future<void> _createProject() async {
    setState(() => _isCreatingProject = true);
    
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const CreateProjectScreen(),
      ),
    );

    setState(() => _isCreatingProject = false);

    if (result == true) {
      await _loadProjects();
    }
  }

  Future<void> _recreateProject(Project rejectedProject) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recreate Project'),
        content: Text(
          'Do you want to create a new project based on "${rejectedProject.title}"? '
          'You will be taken to the project creation form where you can review and modify the details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
            child: const Text('Recreate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Store the original project title to track recreation
    _pendingRecreationOriginalTitle = rejectedProject.title;

    // Navigate to create project screen with rejected project data
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreateProjectScreen(rejectedProject: rejectedProject),
      ),
    );

    if (result == true) {
      // Mark this project as recreated
      print('🔄 Marking project ${rejectedProject.id} as recreated');
      _recreatedProjectIds.add(rejectedProject.id);
      print('📝 Current recreated IDs: $_recreatedProjectIds');
      
      // Save immediately before refreshing projects
      await _saveRecreatedProjectIds();
      
      // Refresh projects list to get the newly created project
      await _loadProjects();
      
      // Find the most recently created project and map it to the original
      if (_pendingRecreationOriginalTitle != null && _projects.isNotEmpty) {
        // Sort projects by creation date (newest first)
        final sortedProjects = List<Project>.from(_projects)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // The first project should be the newly created one
        if (sortedProjects.isNotEmpty) {
          final newProject = sortedProjects.first;
          _recreatedFromProjects[newProject.id] = _pendingRecreationOriginalTitle!;
          print('🔗 Mapped new project ${newProject.id} to original "${_pendingRecreationOriginalTitle}"');
        }
        _pendingRecreationOriginalTitle = null;
      }
      
      // Save again after mapping (in case mapping was added)
      await _saveRecreatedProjectIds();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Project recreated successfully')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Force UI rebuild to hide the recreate button on the rejected project
      if (mounted) {
        setState(() {});
      }
    } else {
      // Clear pending recreation if user cancelled
      _pendingRecreationOriginalTitle = null;
    }
  }

  Future<void> _editProject(Project project) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProjectEditDialog(
        project: project,
        onProjectUpdated: _loadProjects,
      ),
    );
  }



  Future<void> _deleteProject(Project project) async {
    await CoordinatorActions.deleteProject(context, project, _loadProjects);
  }

  // Helper method to check if all required users are assigned
  Future<void> _startProject(Project project) async {
    await CoordinatorActions.startProject(context, project, _loadProjects);
  }

  Future<void> _cancelProject(Project project) async {
    await CoordinatorActions.cancelProject(context, project, _loadProjects);
  }

  Future<void> _completeProject(Project project) async {
    await CoordinatorActions.completeProject(context, project, _loadProjects);
  }



  // Workflow stages

  



  

  Future<void> _assignFieldOfficer(Project project) async {
    await FieldOfficerAssignmentDialog.show(context, project, (_) => _loadProjects());
  }

  Future<void> _assignClient(Project project) async {
    await ClientAssignmentDialog.show(context, project, (_) => _loadProjects());
  }


  Future<void> _assignAgent(Project project) async {
    await AgentAssignmentDialog.show(context, project, (_) => _loadProjects());
  }

  

  


  

  String _getFullName(dynamic user) {
    if (user is FieldOfficer || user is Client || user is Agent || user is Accessor || user is SeniorValuer) {
      return user.fullName;
    }
    return '';
  }

  String _getUsername(dynamic user) {
    if (user is FieldOfficer || user is Client || user is Agent || user is Accessor || user is SeniorValuer) {
      return user.username;
    }
    return '';
  }

  int _getUserId(dynamic user) {
    if (user is FieldOfficer || user is Client || user is Agent || user is Accessor || user is SeniorValuer) {
      return user.id;
    }
    return 0;
  }

  int? _getAssignedProjectsCount(dynamic user) {
    if (user is FieldOfficer || user is Client || user is Agent || user is Accessor || user is SeniorValuer) {
      return user.assignedProjectsCount;
    }
    return null;
  }

  Future<void> _showDocumentsDialog(Project project) async {
    await DocumentsDialog.show(context, project, () => _loadProjects());
  }

  

  

  Future<void> _viewProjectDetails(Project project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailsScreen(project: project),
      ),
    );
    // Refresh lists after returning
    _loadProjects(); 
  }
  
  
  
  
  

  
  

  

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  bool _isAfter12PM() {
    final now = DateTime.now();
    return now.hour >= 12;
  }

  // ========== NEW UI COMPONENTS FOR MODERN DESIGN ==========
  
  // Custom Header Widget
  String _getProjectSubTabName(int index) {
    switch (index) {
      case 0:
        return 'Received';
      case 1:
        return 'Ongoing';
      case 2:
        return 'Completed';
      case 3:
        return 'Cancelled';
      default:
        return 'All';
    }
  }

  IconData _getProjectSubTabIcon(int index) {
    switch (index) {
      case 0:
        return Icons.move_to_inbox;
      case 1:
        return Icons.work_outline;
      case 2:
        return Icons.task_alt;
      case 3:
        return Icons.cancel_outlined;
      default:
        return Icons.folder_outlined;
    }
  }



  // Main Statistics Card
  
  



  // Latest Transactions Section
  


  // Project Categories Section
  










  // Circular Tab for Project Subtabs
  // Restored Core Logic

  

  

  

  Widget _buildAttendanceTab() {
    return GenericDashboard(
      role: 'coordinator',
      roleDisplay: _roleDisplay ?? 'Coordinator',
      isEmbedded: true,
    );
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
             children: [
               CoordinatorHeader(
                  username: _username,
                  roleDisplay: _roleDisplay ?? '',
                  tabController: _tabController,
                  projectSubTabController: _projectSubTabController,
                  onNotificationTap: () {},
                  onStatsTap: () {},
                  getProjectSubTabName: (index) {
                    const names = ['Received', 'Ongoing', 'Completed', 'Cancelled'];
                    if (index >= 0 && index < names.length) return names[index];
                    return '';
                  },
                  onLogout: _handleLogout,
               ),
               Expanded(
                 child: IndexedStack(
                   index: _tabController.index,
                   children: [
                     CoordinatorHomeTab(
                      projects: _projects,
                      onViewDetails: _viewProjectDetails,
                    ),
                     _buildProjectsTab(),  // Index 1: Projects
                     _buildAttendanceTab(), // Index 2: Attendance
                   ],
                 ),
               ),
             ],
          ),
          Positioned(
             bottom: 0,
             left: 0,
             right: 0,
             child: CoordinatorBottomNav(
               tabController: _tabController,
             ),
          ),
          if (_tabController.index == 1)
             Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: CreateProjectButton(
                   isCreatingProject: _isCreatingProject,
                   onCreateProject: _createProject,
                ),
             ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    await LogoutDialog.show(context);
  }




  Widget _buildProjectsTab() {
    // Filter projects by status
    // Use case-insensitive comparison to handle any potential case variations
    // Exclude rejected projects from pending (they should appear in cancelled tab)
    final pendingProjects = _projects.where((p) => 
      p.status.toLowerCase() == 'pending' && p.mdGmApprovalStatus != 'rejected'
    ).toList();
    final ongoingProjects = _projects.where((p) => p.status.toLowerCase() == 'in_progress').toList();
    final completedProjects = _projects.where((p) => p.status.toLowerCase() == 'completed').toList();
    // Include both cancelled projects and rejected projects in cancelled tab
    final cancelledProjects = _projects.where((p) => 
      p.status.toLowerCase() == 'cancelled' || p.mdGmApprovalStatus == 'rejected'
    ).toList();
    
    // Initialize search controllers for each tab if not exists
    for (int i = 0; i < 4; i++) {
      if (!_searchControllers.containsKey(i)) {
        _searchControllers[i] = TextEditingController();
        _searchControllers[i]!.addListener(() => setState(() {}));
      }
    }

    return Column(
      children: [
        // Create Project Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey[200]!,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildCreateProjectButton(),
        ),
        // Project Subtabs
        Container(
          color: Colors.white,
          child: _projectSubTabController != null && _projectSubTabController!.length == 4
              ? TabBar(
                  controller: _projectSubTabController,
                  labelColor: Colors.blue[700],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue[700],
                  indicatorWeight: 3,
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  tabs: const [
                    Tab(text: 'Received'),
                    Tab(text: 'Ongoing'),
                    Tab(text: 'Completed'),
                    Tab(text: 'Cancelled'),
                  ],
                )
              : const SizedBox(height: 48),
        ),
        // Projects List with Subtabs
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProjects,
            child: _isLoadingProjects || _projectSubTabController == null || _projectSubTabController!.length != 4
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _projectSubTabController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _buildProjectListWithSearch(
                        _filterAndSortProjects(pendingProjects, 0),
                        'No received projects',
                        'Newly received projects will appear here',
                        isReceivedTab: true,
                        tabIndex: 0,
                      ),
                      _buildProjectListWithSearch(
                        _filterAndSortProjects(ongoingProjects, 1),
                        'No ongoing projects',
                        'Projects in progress will appear here',
                        tabIndex: 1,
                      ),
                      _buildProjectListWithSearch(
                        _filterAndSortProjects(completedProjects, 2),
                        'No completed projects',
                        'Completed projects will appear here',
                        tabIndex: 2,
                      ),
                      _buildProjectListWithSearch(
                        _filterAndSortProjects(cancelledProjects, 3),
                        'No cancelled projects',
                        'Cancelled projects will appear here',
                        isCancelledTab: true,
                        tabIndex: 3,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }


  Future<void> _showStatusDialog(Project project) async {
    await StatusUpdateDialog.show(context, project, () {
      _loadProjects();
    });
  }


  Future<void> _showAssignUsersDialog(Project project) async {
    await AssignUsersDialog.show(context, project, () {
      _loadProjects();
    });
  }


    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _viewProjectDetails(project),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: EdgeInsets.only(bottom: isReceivedTab ? 4 : 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: project.status == 'in_progress'
                        ? Colors.grey[200]!
                        : project.status == 'completed'
                            ? Colors.grey[200]!
                            : project.status == 'cancelled'
                                ? Colors.grey[200]!
                                : Colors.grey[200]!,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.grey[200]!,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spacing for priority label
                const SizedBox(height: 20),
                // Show "recreated from" message if this project was recreated
                if (_recreatedFromProjects.containsKey(project.id)) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recreated from "${_recreatedFromProjects[project.id]}"',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Show MD/GM rejection status if rejected (always show, even after recreation)
                if (project.mdGmApprovalStatus == 'rejected') ...[
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
                        // Only show "Recreate Project" button if project hasn't been recreated yet
                        // Ensure we're comparing the same type (int)
                        if (!_recreatedProjectIds.contains(project.id is int ? project.id : int.tryParse(project.id.toString()) ?? 0)) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _recreateProject(project),
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: const Text('Recreate Project'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                // Top row: project name + status aligned with edit/delete icons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Project name and status on left
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              project.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Attachment, Edit & Delete buttons aligned with title
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _showDocumentsDialog(project),
                          icon: const Icon(Icons.attach_file, size: 18),
                          color: Colors.teal[700],
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: 'Documents',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.teal[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        // Status icon button (only for ongoing projects)
                        if (isOngoing) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _showStatusDialog(project),
                            icon: const Icon(Icons.account_tree, size: 18),
                            color: Colors.blue[700],
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip: 'View/Update Status',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue[50],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _editProject(project),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: Colors.orange[700],
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: 'Edit Project',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.orange[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _deleteProject(project),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red[700],
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          tooltip: 'Delete Project',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Description row with Cancel and Start buttons (for pending projects) or Cancel button (for ongoing projects)
                if (project.description != null || isPending || isOngoing) ...[
                  SizedBox(height: isReceivedTab ? 4 : 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Description section
                      if (project.description != null)
                        Expanded(
                          child: Text(
                            project.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ),
                      // Spacer to push buttons to the right when there's no description
                      if (project.description == null && !isPending && isOngoing)
                        const Spacer(),
                      // Cancel and Start buttons (for pending projects)
                      if (isPending) ...[
                        if (project.description != null)
                          const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HoverableStartButton(
                              canStart: _canStartProject(project),
                              onPressed: () => _startProject(project),
                            ),
                            const SizedBox(width: 4),
                            _HoverableCancelButton(
                              onPressed: () => _cancelProject(project),
                            ),
                          ],
                        ),
                      ],
                      // Cancel and Complete buttons for ongoing projects (parallel with description) - MUST appear before contact button
                      if (isOngoing && !isPending) ...[
                        if (project.description != null)
                          const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HoverableCompleteButton(
                              onPressed: () => _completeProject(project),
                            ),
                            const SizedBox(width: 4),
                            _HoverableCancelButton(
                              onPressed: () => _cancelProject(project),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
                // Date row
                SizedBox(height: isReceivedTab ? 4 : 8),
                if (project.startDate != null || project.endDate != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (project.startDate != null) ...[
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(project.startDate!),
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500, height: 1.2),
                        ),
                      ],
                      if (project.startDate != null && project.endDate != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey[400]),
                        ),
                      ],
                      if (project.endDate != null) ...[
                        Icon(Icons.event, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(project.endDate!),
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500, height: 1.2),
                        ),
                      ],
                    ],
                  ),
            // Assign Users button (for pending projects)
            if (isPending) ...[
              SizedBox(height: isReceivedTab ? 4 : 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAssignUsersDialog(project),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text(
                    'Assign Users',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
            // Cancel button for ongoing projects (before contact button)
            // Note: Cancel button is now in the description row above, so this section is removed
            // Contact Assigned Users Button (for ongoing projects)
            if (!isPending && project.status.toLowerCase() == 'in_progress') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showContactAssignedUsers(project),
                  icon: const Icon(Icons.contact_mail, size: 18),
                  label: const Text(
                    'Contact Assigned Users',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
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
        // Status ribbon at top-right corner
        Positioned(
          top: 4,
          right: 8,
          child: _buildStatusRibbon(project),
        ),
      ],
    );
  }
  
}
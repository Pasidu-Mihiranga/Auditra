import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../models/attendance_model.dart';
import '../models/project_model.dart';
import '../models/valuation_model.dart';
import 'login_screen.dart';
import 'generic_dashboard.dart';
import 'create_project_screen.dart';

// Helper class to hold upload dialog state
class _UploadDialogState {
  int? selectedUserId;
  String? selectedUserName;
  String? selectedFile;
  String? selectedFileName;
  bool isUploading = false;
}

class CoordinatorDashboard extends StatefulWidget {
  const CoordinatorDashboard({super.key});

  @override
  State<CoordinatorDashboard> createState() => _CoordinatorDashboardState();
}

class _CoordinatorDashboardState extends State<CoordinatorDashboard> with TickerProviderStateMixin {
  // Responsive helper methods
  double _getResponsiveWidth(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }
  
  double _getResponsiveHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }
  
  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    // Scale font size based on screen width (base on 360px width)
    final scaleFactor = width / 360;
    return baseSize * scaleFactor.clamp(0.8, 1.3);
  }
  
  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Scale padding based on screen width
    if (width < 360) return 12.0;
    if (width < 400) return 14.0;
    if (width < 500) return 16.0;
    return 20.0;
  }
  
  double _getResponsiveIconSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 18.0;
    if (width < 400) return 20.0;
    return 24.0;
  }
  
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
  final Map<int, TextEditingController> _searchControllers = {};
  final Map<int, String> _sortOptions = {}; // 'date_asc', 'date_desc', 'title_asc', 'title_desc', 'priority'
  late TabController _tabController;
  TabController? _projectSubTabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
    _projectSubTabController?.dispose();
    // Dispose search controllers
    for (var controller in _searchControllers.values) {
      controller.dispose();
    }
    _searchControllers.clear();
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
    }
  }

  Future<void> _loadRecreatedProjectIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recreatedIdsJson = prefs.getString('recreated_project_ids');
      if (recreatedIdsJson != null) {
        final List<dynamic> idsList = jsonDecode(recreatedIdsJson);
        _recreatedProjectIds = idsList.map((id) => id as int).toSet();
      }
      
      final recreatedFromJson = prefs.getString('recreated_from_projects');
      if (recreatedFromJson != null) {
        final Map<String, dynamic> map = jsonDecode(recreatedFromJson);
        _recreatedFromProjects = map.map((key, value) => MapEntry(int.parse(key), value as String));
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading recreated project IDs: $e');
    }
  }

  Future<void> _saveRecreatedProjectIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recreated_project_ids', jsonEncode(_recreatedProjectIds.toList()));
      await prefs.setString('recreated_from_projects', jsonEncode(
        _recreatedFromProjects.map((key, value) => MapEntry(key.toString(), value))
      ));
    } catch (e) {
      print('Error saving recreated project IDs: $e');
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
              backgroundColor: Colors.green,
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
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const CreateProjectScreen(),
      ),
    );

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

    // Navigate to create project screen
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const CreateProjectScreen(),
      ),
    );

    if (result == true) {
      // Mark this project as recreated
      _recreatedProjectIds.add(rejectedProject.id);
      
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
        }
        _pendingRecreationOriginalTitle = null;
      }
      
      // Save recreated project IDs to persistent storage
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
    final titleController = TextEditingController(text: project.title);
    final descriptionController = TextEditingController(text: project.description ?? '');
    DateTime? startDate = project.startDate;
    DateTime? endDate = project.endDate;
    String priority = (project.priority ?? 'medium').toLowerCase();
    bool isUpdating = false;
    bool showAdvancedOptions = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
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
                        child: const Icon(Icons.edit, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Project',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: isUpdating ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Information Card
                        _buildSectionCard(
                          context,
                          title: 'Basic Information',
                          icon: Icons.info_outline,
                          child: Column(
                            children: [
                              TextField(
                                controller: titleController,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: 'Project Title *',
                                  hintText: 'Enter project title',
                                  prefixIcon: const Icon(Icons.title),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: descriptionController,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'Enter project description',
                                  prefixIcon: const Icon(Icons.description),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Priority Card
                        _buildSectionCard(
                          context,
                          title: 'Priority',
                          icon: Icons.flag_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildPriorityChip(
                                      context,
                                      label: 'High',
                                      value: 'high',
                                      selectedValue: priority,
                                      color: Colors.red,
                                      icon: Icons.priority_high,
                                      onTap: () => setDialogState(() => priority = 'high'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildPriorityChip(
                                      context,
                                      label: 'Medium',
                                      value: 'medium',
                                      selectedValue: priority,
                                      color: Colors.orange,
                                      icon: Icons.remove_circle_outline,
                                      onTap: () => setDialogState(() => priority = 'medium'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildPriorityChip(
                                      context,
                                      label: 'Low',
                                      value: 'low',
                                      selectedValue: priority,
                                      color: Colors.green,
                                      icon: Icons.arrow_downward,
                                      onTap: () => setDialogState(() => priority = 'low'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Dates Card
                        _buildSectionCard(
                          context,
                          title: 'Project Timeline',
                          icon: Icons.calendar_today,
                          child: Column(
                            children: [
                              _buildDatePickerField(
                                context,
                                label: 'Start Date',
                                icon: Icons.play_circle_outline,
                                date: startDate,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: startDate ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: Colors.orange[600]!,
                                            onPrimary: Colors.white,
                                            surface: Colors.white,
                                            onSurface: Colors.black87,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setDialogState(() => startDate = picked);
                                  }
                                },
                                onClear: () => setDialogState(() => startDate = null),
                              ),
                              const SizedBox(height: 16),
                              _buildDatePickerField(
                                context,
                                label: 'End Date',
                                icon: Icons.event_available,
                                date: endDate,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: endDate ?? (startDate ?? DateTime.now()),
                                    firstDate: startDate ?? DateTime(2000),
                                    lastDate: DateTime(2100),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: Colors.orange[600]!,
                                            onPrimary: Colors.white,
                                            surface: Colors.white,
                                            onSurface: Colors.black87,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setDialogState(() => endDate = picked);
                                  }
                                },
                                onClear: () => setDialogState(() => endDate = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Advanced Options (Expandable)
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ExpansionTile(
                            leading: Icon(Icons.tune, color: Colors.orange[600]!),
                            title: const Text(
                              'Additional Options',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text('View project metadata'),
                            initiallyExpanded: showAdvancedOptions,
                            onExpansionChanged: (expanded) {
                              setDialogState(() => showAdvancedOptions = expanded);
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow('Project ID', '#${project.id}'),
                                    const SizedBox(height: 12),
                                    _buildInfoRow('Created', DateFormat('MMM dd, yyyy • hh:mm a').format(project.createdAt)),
                                    const SizedBox(height: 12),
                                    _buildInfoRow('Last Updated', DateFormat('MMM dd, yyyy • hh:mm a').format(project.updatedAt)),
                                    const SizedBox(height: 12),
                                    _buildInfoRow('Coordinator', project.coordinatorName ?? project.coordinatorUsername),
                                    if (project.assignedFieldOfficerName != null) ...[
                                      const SizedBox(height: 12),
                                      _buildInfoRow('Field Officer', project.assignedFieldOfficerName!),
                                    ],
                                    if (project.assignedClientName != null) ...[
                                      const SizedBox(height: 12),
                                      _buildInfoRow('Client', project.assignedClientName!),
                                    ],
                                    if (project.assignedAgentName != null) ...[
                                      const SizedBox(height: 12),
                                      _buildInfoRow('Agent', project.assignedAgentName!),
                                    ],
                                    const SizedBox(height: 12),
                                    _buildInfoRow('Documents', '${project.documentsCount} file(s)'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                          onPressed: isUpdating ? null : () => Navigator.of(context).pop(),
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
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isUpdating
                              ? null
                              : () async {
                                  if (titleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter a project title'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isUpdating = true);

                                  // Update project details
                                  final result = await ApiService.updateProject(
                                    projectId: project.id,
                                    title: titleController.text.trim(),
                                    description: descriptionController.text.trim().isEmpty
                                        ? null
                                        : descriptionController.text.trim(),
                                    startDate: startDate,
                                    endDate: endDate,
                                    priority: priority,
                                  );

                                  if (mounted) {
                                    if (result['success']) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white),
                                              SizedBox(width: 8),
                                              Text('Project updated successfully!'),
                                            ],
                                          ),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                      await _loadProjects();
                                    } else {
                                      setDialogState(() => isUpdating = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.error, color: Colors.white),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(result['message'] ?? 'Failed to update project'),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save, size: 20),
                                    SizedBox(width: 8),
                                    Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.orange[600]!, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(BuildContext context, {
    required String label,
    required String value,
    required String selectedValue,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[200]! : Colors.grey[100]!,
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerField(BuildContext context, {
    required String label,
    required IconData icon,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange[600]!),
            const SizedBox(width: 12),
            Expanded(
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
                    date != null
                        ? DateFormat('MMM dd, yyyy').format(date)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 16,
                      color: date != null ? Colors.black87 : Colors.grey[400],
                      fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (date != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                color: Colors.grey[600],
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 8),
            Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isWarning ? Colors.orange[700] : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteProject(Project project) async {
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
                  color: Colors.red[500]!,
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
                              color: Colors.red[400]!,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Delete Project',
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
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Are you sure?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You are about to delete "${project.title}". This action cannot be undone.',
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
                          backgroundColor: Colors.red[600],
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
                            Icon(Icons.delete, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

    if (confirm != true) return;

    final result = await ApiService.deleteProject(project.id);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete project'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to check if all required users are assigned
  bool _canStartProject(Project project) {
    // Field officer and client are always required
    if (project.assignedFieldOfficerName == null || project.assignedClientName == null) {
      return false;
    }
    
    // Agent is required only if hasAgent is true
    if (project.hasAgent && project.assignedAgentName == null) {
      return false;
    }
    
    return true;
  }

  Future<void> _startProject(Project project) async {
    // Check if all required users are assigned
    if (!_canStartProject(project)) {
      // Work out which user types are missing
      final List<String> missing = [];

      if (project.assignedFieldOfficerName == null) {
        missing.add('Field Officer');
      }
      if (project.assignedClientName == null) {
        missing.add('Client');
      }
      if (project.hasAgent && project.assignedAgentName == null) {
        missing.add('Agent');
      }

      String message;
      if (missing.length == 1) {
        // Single missing type – show specific message
        message = 'Please assign ${missing.first} before starting this project.';
      } else {
        // Multiple missing types – keep it generic
        message = 'Please assign all required users before starting this project.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final result = await ApiService.updateProjectStatus(
      projectId: project.id,
      status: 'in_progress',
    );

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to start project'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelProject(Project project) async {
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
                  color: Colors.red[500]!,
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
                              color: Colors.red[400]!,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cancel_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Cancel Project',
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
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: Colors.red[300],
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
                      'You are about to cancel "${project.title}". This action will mark the project as cancelled.',
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
                        child: const Text('No, Keep It', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
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
                            Icon(Icons.cancel, size: 20),
                            SizedBox(width: 8),
                            Text('Cancel Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

    if (confirm != true) return;

    final result = await ApiService.updateProjectStatus(
      projectId: project.id,
      status: 'cancelled',
    );

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project cancelled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to cancel project'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal[500]!,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                              color: Colors.teal[400]!,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Complete Project',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 56,
                          color: Colors.teal[300],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Mark as Completed?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'You are about to mark "${project.title}" as completed. This action will finalize the project.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 18),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Complete Project',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );

    if (confirm != true) return;

    final result = await ApiService.updateProjectStatus(
      projectId: project.id,
      status: 'completed',
    );

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to complete project'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Workflow stages
  static const List<Map<String, dynamic>> workflowStages = [
    {
      'id': 'field_officer_receives',
      'label': 'Field Officer Receives Assignment',
      'icon': Icons.person_outline,
      'order': 1,
    },
    {
      'id': 'performs_field_work',
      'label': 'Performs Field Work',
      'icon': Icons.work_outline,
      'order': 2,
    },
    {
      'id': 'submit_draft_report',
      'label': 'Submit Draft Report',
      'icon': Icons.description_outlined,
      'order': 3,
    },
    {
      'id': 'accessor_reviews',
      'label': 'Accessor Reviews Report',
      'icon': Icons.rate_review_outlined,
      'order': 4,
    },
    {
      'id': 'senior_valuer_reviews',
      'label': 'Senior Valuer Reviews Report',
      'icon': Icons.verified_user_outlined,
      'order': 5,
    },
    {
      'id': 'mg_gm_approves',
      'label': 'MG/GM Approves Report',
      'icon': Icons.approval_outlined,
      'order': 6,
    },
  ];

  Future<void> _showStatusDialog(Project project) async {
    // Check if all stages are completed
    final projectCurrentStageIndex = project.workflowStage != null 
        ? workflowStages.indexWhere((s) => s['id'] == project.workflowStage)
        : -1;
    final allStagesCompleted = projectCurrentStageIndex == workflowStages.length - 1;
    
    // If all stages are completed, don't select anything initially
    String? selectedWorkflowStage = allStagesCompleted ? null : project.workflowStage;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue[400]!,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_tree, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Project Workflow',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Project title
                          Text(
                            project.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Current status
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Project Status: ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Chip(
                                  label: Text(project.statusDisplay),
                                  backgroundColor: _getProjectStatusColor(project.status),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Workflow tree title
                          const Text(
                            'Workflow Stages:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Workflow tree
                          Builder(
                            builder: (context) {
                              // Calculate if all stages are completed
                              final projectCurrentStageIndex = project.workflowStage != null 
                                  ? workflowStages.indexWhere((s) => s['id'] == project.workflowStage)
                                  : -1;
                              final allStagesCompleted = projectCurrentStageIndex == workflowStages.length - 1;
                              
                              // Calculate if selected stage is a completed (past) stage
                              final selectedStageIndex = selectedWorkflowStage != null
                                  ? workflowStages.indexWhere((s) => s['id'] == selectedWorkflowStage)
                                  : -1;
                              final isSelectedStageCompleted = projectCurrentStageIndex > selectedStageIndex && selectedStageIndex != -1;
                              
                              return Column(
                                children: [
                                  ...workflowStages.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final stage = entry.value;
                                    final isSelected = selectedWorkflowStage == stage['id'];
                                    // A stage is completed if:
                                    // 1. The project has moved past it (projectCurrentStageIndex > index), OR
                                    // 2. It's the final stage and the project is currently at it (all stages completed)
                                    final isCompleted = projectCurrentStageIndex > index || 
                                        (projectCurrentStageIndex == index && projectCurrentStageIndex == workflowStages.length - 1);
                                    final isCurrent = project.workflowStage == stage['id'];
                                    // Check if this is the final stage and all stages are completed
                                    final isFinalStageCompleted = index == workflowStages.length - 1 && allStagesCompleted;
                                    
                                    return Column(
                                      children: [
                                        _buildWorkflowStage(
                                          context,
                                          stage: stage,
                                          index: index + 1,
                                          isSelected: isSelected,
                                          isCompleted: isCompleted,
                                          isCurrent: isCurrent,
                                          isFinalStageCompleted: isFinalStageCompleted,
                                          allStagesCompleted: allStagesCompleted,
                                          onTap: () {
                                            setDialogState(() {
                                              // If all stages are completed and final stage is selected, deselect it
                                              if (allStagesCompleted && isFinalStageCompleted && isSelected) {
                                                selectedWorkflowStage = null;
                                              } else {
                                                selectedWorkflowStage = stage['id'];
                                              }
                                            });
                                          },
                                        ),
                                        if (index < workflowStages.length - 1)
                                          Container(
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            width: 2,
                                            height: 30,
                                            color: isCompleted ? Colors.blue[400] : Colors.grey[300],
                                          ),
                                      ],
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Builder(
                    builder: (context) {
                      final projectCurrentStageIndex = project.workflowStage != null 
                          ? workflowStages.indexWhere((s) => s['id'] == project.workflowStage)
                          : -1;
                      final allStagesCompleted = projectCurrentStageIndex == workflowStages.length - 1;
                      
                      final selectedStageIndex = selectedWorkflowStage != null
                          ? workflowStages.indexWhere((s) => s['id'] == selectedWorkflowStage)
                          : -1;
                      final isSelectedStageCompleted = projectCurrentStageIndex > selectedStageIndex && selectedStageIndex != -1;
                      final isButtonEnabled = selectedWorkflowStage != null && !isSelectedStageCompleted;
                      
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          // Only show spacing and button if not all stages are completed
                          if (!allStagesCompleted) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isButtonEnabled
                                    ? () async {
                                        Navigator.of(context).pop();
                                        await _updateWorkflowStage(project, selectedWorkflowStage);
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.save, size: 18),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Update Workflow',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowStage(
    BuildContext context, {
    required Map<String, dynamic> stage,
    required int index,
    required bool isSelected,
    required bool isCompleted,
    required bool isCurrent,
    required bool isFinalStageCompleted,
    required bool allStagesCompleted,
    required VoidCallback onTap,
  }) {
    Color stageColor;
    IconData stageIcon;
    
    // When all stages are completed OR this is the final completed stage, show original icons (no checkmarks)
    if (allStagesCompleted || isFinalStageCompleted) {
      stageColor = Colors.blue[600]!;
      stageIcon = stage['icon'] as IconData;
    } else if (isCompleted) {
      // Show checkmark for completed stages when not all stages are completed
      stageColor = Colors.blue[600]!;
      stageIcon = Icons.check_circle;
    } else if (isCurrent) {
      stageColor = Colors.blue[600]!;
      stageIcon = Icons.radio_button_checked;
    } else {
      stageColor = Colors.grey[400]!;
      stageIcon = stage['icon'] as IconData;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? stageColor.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? stageColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Stage number and icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent ? stageColor : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                stageIcon,
                color: isCompleted || isCurrent ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Stage label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Stage $index',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCompleted || isCurrent ? stageColor : Colors.grey[600],
                        ),
                      ),
                      // Show "Current" tag only if not completed
                      if (isCurrent && !isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: stageColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      // Show "Completed" tag if completed (this takes priority over "Current")
                      if (isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage['label'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isCompleted || isCurrent ? Colors.black87 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator - hide when all stages are completed
            if (isSelected && !allStagesCompleted)
              Icon(
                Icons.check_circle,
                color: stageColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context, {
    required String label,
    required String value,
    required String selectedValue,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.grey[50],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateWorkflowStage(Project project, String? workflowStage) async {
    final result = await ApiService.updateProjectWorkflowStage(
      projectId: project.id,
      workflowStage: workflowStage,
    );

    if (mounted) {
      if (result['success']) {
        // Check if the updated stage is the last stage (all stages completed)
        final lastStageId = workflowStages.last['id'];
        final allStagesCompleted = workflowStage == lastStageId;
        
        if (allStagesCompleted) {
          // Show completion message dialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.blue[600],
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      'All Workflow Stages Completed!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Message
                    Text(
                      'All workflow stages have been completed successfully.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // OK button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'OK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          // Show regular success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Workflow stage updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadProjects();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update workflow stage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignFieldOfficer(Project project) async {
    final officersResult = await ApiService.getAvailableFieldOfficers();
    
    if (!officersResult['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(officersResult['message'] ?? 'Failed to load field officers')),
      );
      return;
    }

    final officers = (officersResult['data']['field_officers'] as List<dynamic>)
        .map((o) => FieldOfficer.fromJson(o))
        .toList();

    if (officers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No field officers available')),
      );
      return;
    }

    final selectedOfficer = await showDialog<FieldOfficer>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.lightBlue[500]!,
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
                              color: Colors.lightBlue[400]!,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_outline, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Assign Field Officer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.lightBlue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.lightBlue[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap a field officer to assign. Higher project count means they are busier.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.lightBlue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...officers.map((officer) {
                        final initials = (officer.fullName.isNotEmpty
                                ? officer.fullName.trim().split(' ').map((p) => p[0]).take(2).join()
                                : officer.username.substring(0, 1))
                            .toUpperCase();
                        final isAssigned = officer.id == project.assignedFieldOfficerId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isAssigned ? 4 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isAssigned ? Colors.green[300]! : Colors.grey[200]!,
                              width: isAssigned ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(officer),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: isAssigned ? Colors.green[600] : Colors.lightBlue[400],
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          officer.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '@${officer.username}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.work_outline, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${officer.assignedProjectsCount} assigned ${officer.assignedProjectsCount == 1 ? 'project' : 'projects'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isAssigned)
                                    Chip(
                                      label: const Text(
                                        'Current',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: Colors.green[50],
                                      labelStyle: TextStyle(color: Colors.green[700]),
                                    )
                                  else
                                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedOfficer != null) {
      final assignResult = await ApiService.assignFieldOfficer(
        projectId: project.id,
        fieldOfficerId: selectedOfficer.id,
      );

      if (mounted) {
        if (assignResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Field officer assigned successfully!')),
          );
          await _loadProjects();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(assignResult['message'] ?? 'Failed to assign field officer')),
          );
        }
      }
    }
  }

  Future<void> _assignClient(Project project) async {
    final clientsResult = await ApiService.getAvailableClients();
    
    if (!clientsResult['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(clientsResult['message'] ?? 'Failed to load clients')),
      );
      return;
    }

    final clients = (clientsResult['data']['clients'] as List<dynamic>)
        .map((c) => Client.fromJson(c))
        .toList();

    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clients available')),
      );
      return;
    }

    final selectedClient = await showDialog<Client>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.cyan[500]!,
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
                              color: Colors.cyan[400]!,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Assign Client',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.cyan[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.cyan[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.cyan[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Select the client who owns this project.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.cyan[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...clients.map((client) {
                        final initials = (client.fullName.isNotEmpty
                                ? client.fullName.trim().split(' ').map((p) => p[0]).take(2).join()
                                : client.username.substring(0, 1))
                            .toUpperCase();
                        final isAssigned = client.id == project.assignedClientId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isAssigned ? 4 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isAssigned ? Colors.green[300]! : Colors.grey[200]!,
                              width: isAssigned ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(client),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: isAssigned ? Colors.green[600] : Colors.cyan[400],
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          client.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '@${client.username}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isAssigned)
                                    Chip(
                                      label: const Text(
                                        'Current',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: Colors.green[50],
                                      labelStyle: TextStyle(color: Colors.green[700]),
                                    )
                                  else
                                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedClient != null) {
      final assignResult = await ApiService.assignClient(
        projectId: project.id,
        clientId: selectedClient.id,
      );

      if (mounted) {
        if (assignResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Client assigned successfully!')),
          );
          await _loadProjects();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(assignResult['message'] ?? 'Failed to assign client')),
          );
        }
      }
    }
  }

  Future<void> _assignAgent(Project project) async {
    final agentsResult = await ApiService.getAvailableAgents();
    
    if (!agentsResult['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(agentsResult['message'] ?? 'Failed to load agents')),
      );
      return;
    }

    final agents = (agentsResult['data']['agents'] as List<dynamic>)
        .map((a) => Agent.fromJson(a))
        .toList();

    if (agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No agents available')),
      );
      return;
    }

    final selectedAgent = await showDialog<Agent>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[600]!,
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
                      child: const Icon(Icons.badge_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Assign Agent',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap an agent to assign. Project count shows how many engagements they handle.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...agents.map((agent) {
                        final initials = (agent.fullName.isNotEmpty
                                ? agent.fullName.trim().split(' ').map((p) => p[0]).take(2).join()
                                : agent.username.substring(0, 1))
                            .toUpperCase();
                        final isAssigned = agent.id == project.assignedAgentId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isAssigned ? 4 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isAssigned ? Colors.green[300]! : Colors.grey[200]!,
                              width: isAssigned ? 2 : 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(agent),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: isAssigned ? Colors.green[600] : Colors.orange[400],
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          agent.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '@${agent.username}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.handshake_outlined, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${agent.assignedProjectsCount} engagement(s)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isAssigned)
                                    Chip(
                                      label: const Text(
                                        'Current',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: Colors.green[50],
                                      labelStyle: TextStyle(color: Colors.green[700]),
                                    )
                                  else
                                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedAgent != null) {
      final assignResult = await ApiService.assignAgent(
        projectId: project.id,
        agentId: selectedAgent.id,
      );

      if (mounted) {
        if (assignResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agent assigned successfully!')),
          );
          await _loadProjects();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(assignResult['message'] ?? 'Failed to assign agent')),
          );
        }
      }
    }
  }

  Future<void> _showAssignUsersDialog(Project project) async {
    // Get the current project from the list (may be updated after assignment)
    final currentProject = _projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project,
    );
    
    // Check if agent info exists
    final hasAgentInfo = currentProject.agentInfo != null || currentProject.hasAgent;
    final tabCount = hasAgentInfo ? 5 : 4;
    final TabController tabController = TabController(length: tabCount, vsync: this);
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Get the current project from the list (may be updated after assignment)
          final currentProject = _projects.firstWhere(
            (p) => p.id == project.id,
            orElse: () => project,
          );
          return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
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
                        child: const Icon(Icons.person_add, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Assign Users to Project',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Tabs
                Container(
                  color: Colors.blue[50],
                  child: TabBar(
                    controller: tabController,
                    isScrollable: true,
                    labelColor: Colors.blue[700],
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: Colors.blue[700],
                    tabs: [
                      const Tab(text: 'Field Officer'),
                      const Tab(text: 'Client'),
                      if (hasAgentInfo) const Tab(text: 'Agent'),
                      const Tab(text: 'Accessor'),
                      const Tab(text: 'Senior Valuer'),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      _buildUserTypeTab(
                        context,
                        'field_officer',
                        project,
                        Colors.lightBlue,
                        Icons.person_outline,
                        () => ApiService.getAvailableFieldOfficers(),
                        (data) => (data['field_officers'] as List<dynamic>)
                            .map((o) => FieldOfficer.fromJson(o))
                            .toList(),
                        (id) => currentProject.assignedFieldOfficerId == id,
                        (id) => ApiService.assignFieldOfficer(projectId: currentProject.id, fieldOfficerId: id),
                        'Field Officer',
                        setDialogState,
                        showProjectCount: true,
                      ),
                      _buildClientAgentTab(
                        context,
                        'client',
                        project,
                        Colors.cyan,
                        Icons.business_outlined,
                        (id) => ApiService.assignClient(projectId: currentProject.id, clientId: id),
                        'Client',
                        setDialogState,
                      ),
                      if (hasAgentInfo)
                        _buildClientAgentTab(
                          context,
                          'agent',
                          project,
                          Colors.orange,
                          Icons.badge_outlined,
                          (id) => ApiService.assignAgent(projectId: currentProject.id, agentId: id),
                          'Agent',
                          setDialogState,
                        ),
                      _buildUserTypeTab(
                        context,
                        'accessor',
                        project,
                        Colors.purple,
                        Icons.assessment_outlined,
                        () => ApiService.getAvailableAccessors(),
                        (data) => (data['accessors'] as List<dynamic>)
                            .map((a) => Accessor.fromJson(a))
                            .toList(),
                        (id) => currentProject.assignedAccessorId == id,
                        (id) => ApiService.assignAccessor(projectId: currentProject.id, accessorId: id),
                        'Accessor',
                        setDialogState,
                        showProjectCount: true,
                      ),
                      _buildUserTypeTab(
                        context,
                        'senior_valuer',
                        project,
                        Colors.teal,
                        Icons.verified_user_outlined,
                        () => ApiService.getAvailableSeniorValuers(),
                        (data) => (data['senior_valuers'] as List<dynamic>)
                            .map((v) => SeniorValuer.fromJson(v))
                            .toList(),
                        (id) => currentProject.assignedSeniorValuerId == id,
                        (id) => ApiService.assignSeniorValuer(projectId: currentProject.id, seniorValuerId: id),
                        'Senior Valuer',
                        setDialogState,
                        showProjectCount: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
    
    tabController.dispose();
    await _loadProjects();
    
    // Check assigned users after dialog closes
    if (mounted) {
      // Get updated project
      final updatedProject = _projects.firstWhere(
        (p) => p.id == project.id,
        orElse: () => project,
      );
      
      // Check all users (including Senior Valuer and Accessor)
      final List<String> allMissingRoles = [];
      
      if (updatedProject.assignedFieldOfficerName == null) {
        allMissingRoles.add('Field Officer');
      }
      if (updatedProject.assignedClientName == null) {
        allMissingRoles.add('Client');
      }
      if (updatedProject.hasAgent && updatedProject.assignedAgentName == null) {
        allMissingRoles.add('Agent');
      }
      if (updatedProject.assignedAccessorName == null) {
        allMissingRoles.add('Accessor');
      }
      if (updatedProject.assignedSeniorValuerName == null) {
        allMissingRoles.add('Senior Valuer');
      }
      
      // Show appropriate message
      if (allMissingRoles.isEmpty) {
        // All users assigned (including Senior Valuer and Accessor) - show success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All relevant users have been assigned successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Some users missing - show all missing roles
        final missingText = allMissingRoles.length == 1
            ? 'Missing user role: ${allMissingRoles.first}'
            : 'Missing user roles: ${allMissingRoles.join(', ')}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(missingText),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showUserAssignedProjects(
    BuildContext context,
    int userId,
    String userName,
    String roleType,
    Future<Map<String, dynamic>> Function(int) assignUser,
    String userTypeName,
    Project currentProject,
  ) async {
    // Fetch user's assigned projects
    final projectsResult = await ApiService.getUserAssignedProjects(
      userId: userId,
      roleType: roleType,
    );

    if (!projectsResult['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(projectsResult['message'] ?? 'Failed to load assigned projects')),
        );
      }
      return;
    }

    final projectsData = projectsResult['data']['projects'] as List<dynamic>;
    final userData = projectsResult['data']['user'];

    // Always show dialog with assigned projects (or "No projects assigned" message)
    final selectedProject = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
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
                      child: const Icon(Icons.assignment, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData['full_name'] ?? userData['username'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Assigned Projects',
                            style: TextStyle(
                                            color: Colors.white,
                              fontSize: 14,
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
              // Projects List
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (projectsData.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No projects assigned',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This user has no assigned projects yet.',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...projectsData.map((project) {
                          final assignedDate = DateTime.parse(project['assigned_date']);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          project['title'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Assigned: ${DateFormat('MMM dd, yyyy').format(assignedDate)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Chip(
                                          label: Text(
                                            project['status_display'],
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          backgroundColor: project['status'] == 'in_progress'
                                              ? Colors.blue[50]
                                              : project['status'] == 'completed'
                                                  ? Colors.teal[50]
                                                  : Colors.grey[200],
                                          labelStyle: TextStyle(
                                            color: project['status'] == 'in_progress'
                                                ? Colors.blue[500]
                                                : project['status'] == 'completed'
                                                    ? Colors.teal[700]
                                                    : Colors.grey[700],
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Informational only – no selection from project list
                                  const SizedBox(width: 12),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // This dialog is informational only; selection and assignment happen from the user list.
  }

  Widget _buildUserTypeTab<T>(
    BuildContext context,
    String userType,
    Project project,
    MaterialColor color,
    IconData icon,
    Future<Map<String, dynamic>> Function() fetchUsers,
    List<T> Function(Map<String, dynamic>) parseUsers,
    bool Function(int) isAssigned,
    Future<Map<String, dynamic>> Function(int) assignUser,
    String userTypeName,
    StateSetter setDialogState, {
    bool showProjectCount = false,
  }) {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!['success']) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  snapshot.data?['message'] ?? 'Failed to load $userTypeName',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final users = parseUsers(snapshot.data!['data']);

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No $userTypeName available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...users.map((user) {
                final fullName = _getFullName(user);
                final username = _getUsername(user);
                final userId = _getUserId(user);
                final assignedProjectsCount = _getAssignedProjectsCount(user);
                final initials = (fullName.isNotEmpty
                        ? fullName.trim().split(' ').map((p) => p[0]).take(2).join()
                        : username.substring(0, 1))
                    .toUpperCase();
                // Get the current project from the list (may be updated after assignment)
                final currentProject = _projects.firstWhere(
                  (p) => p.id == project.id,
                  orElse: () => project,
                );
                // Use currentProject instead of project for assignment check
                final isUserAssigned = userType == 'field_officer'
                    ? currentProject.assignedFieldOfficerId == userId
                    : userType == 'client'
                        ? currentProject.assignedClientId == userId
                        : userType == 'agent'
                            ? currentProject.assignedAgentId == userId
                            : userType == 'accessor'
                                ? currentProject.assignedAccessorId == userId
                                : userType == 'senior_valuer'
                                    ? currentProject.assignedSeniorValuerId == userId
                                    : isAssigned(userId);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isUserAssigned ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isUserAssigned ? Colors.green[300]! : Colors.grey[200]!,
                      width: isUserAssigned ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    // Tap on the card itself does nothing; actions are on Select/More buttons
                    onTap: null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: isUserAssigned ? Colors.green[600] : color[400],
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@$username',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (showProjectCount && assignedProjectsCount != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.work_outline, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '$assignedProjectsCount assigned ${assignedProjectsCount == 1 ? 'project' : 'projects'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: isUserAssigned
                                      ? Chip(
                                          label: const Text(
                                            'Current',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          backgroundColor: Colors.green[50],
                                          labelStyle: TextStyle(color: Colors.green[700]),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (showProjectCount &&
                                                (userType == 'field_officer' ||
                                                    userType == 'accessor' ||
                                                    userType == 'senior_valuer')) ...[
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  // Show assigned projects for this user
                                                  await _showUserAssignedProjects(
                                                    context,
                                                    userId,
                                                    fullName,
                                                    userType,
                                                    assignUser,
                                                    userTypeName,
                                                    project,
                                                  );
                                                },
                                                icon: const Icon(Icons.info_outline, size: 16),
                                                label: const Text(
                                                  'Details',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                                  backgroundColor: Colors.blue[50],
                                                  foregroundColor: Colors.blue[700],
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            ElevatedButton.icon(
                                              onPressed: () async {
                                                // Confirm assignment from user list
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (dialogContext) => AlertDialog(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    title: const Text('Confirm Assignment'),
                                                    content: Text(
                                                      'Assign $userTypeName "$fullName" to project "${currentProject.title}"?',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                                        child: const Text('Cancel'),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.blue[600],
                                                          foregroundColor: Colors.white,
                                                        ),
                                                        child: const Text('OK'),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  final result = await assignUser(userId);
                                                  if (mounted) {
                                                    if (result['success']) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '$userTypeName assigned successfully!',
                                                          ),
                                                        ),
                                                      );
                                                      // Reload projects to update the state
                                                      await _loadProjects();
                                                      // Trigger dialog rebuild to show "Current" instead of "Select"
                                                      setDialogState(() {});
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            result['message'] ??
                                                                'Failed to assign $userTypeName',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                }
                                              },
                                              icon: const Icon(Icons.check, size: 16),
                                              label: const Text(
                                                'Select',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue[600],
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
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
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientAgentTab(
    BuildContext context,
    String userType,
    Project project,
    MaterialColor color,
    IconData icon,
    Future<Map<String, dynamic>> Function(int) assignUser,
    String userTypeName,
    StateSetter setDialogState,
  ) {
    // Get the current project from the list (may be updated after assignment)
    final currentProject = _projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project,
    );

    final info = userType == 'client' ? currentProject.clientInfo : currentProject.agentInfo;
    final isAssigned = userType == 'client'
        ? currentProject.assignedClientId != null
        : currentProject.assignedAgentId != null;

    if (info == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No $userTypeName information available',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Please add $userTypeName information when creating the project',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final name = info['name'] ?? 'N/A';
    final email = info['email'] ?? 'N/A';
    final phone = info['phone'] ?? 'N/A';
    final address = info['address'] ?? 'N/A';
    final company = info['company'] ?? (userType == 'agent' ? (info['license_number'] ?? 'N/A') : 'N/A');

    final initials = name != 'N/A' && name.isNotEmpty
        ? name.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase()
        : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: isAssigned ? 4 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isAssigned ? Colors.green[300]! : Colors.grey[200]!,
                width: isAssigned ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: isAssigned ? Colors.green[600] : color[400],
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (email != 'N/A')
                              Row(
                                children: [
                                  Icon(Icons.email_outlined, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            if (phone != 'N/A' && email != 'N/A') const SizedBox(height: 4),
                            if (phone != 'N/A')
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      phone,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (address != 'N/A') ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (company != 'N/A') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          userType == 'agent' ? Icons.verified_outlined : Icons.business_outlined,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            userType == 'agent' ? 'License: $company' : 'Company: $company',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (isAssigned)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: const Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: Colors.green[50],
                        labelStyle: TextStyle(color: Colors.green[700]),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                            onPressed: () async {
                              // Find and assign the user account matching the email from client/agent info
                              final infoEmail = email.toLowerCase().trim();
                              
                              if (userType == 'client') {
                                // Get available clients and find the one matching the email
                                final clientsResult = await ApiService.getAvailableClients();
                                if (!clientsResult['success']) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          clientsResult['message'] ?? 'Failed to load clients',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                final clients = (clientsResult['data']['clients'] as List<dynamic>)
                                    .map((c) => Client.fromJson(c))
                                    .toList();

                                if (clients.isEmpty) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No clients available')),
                                    );
                                  }
                                  return;
                                }

                                // Find client matching the email
                                final matchingClient = clients.firstWhere(
                                  (c) => c.email.toLowerCase().trim() == infoEmail,
                                  orElse: () => clients.first, // Fallback to first if no match
                                );

                                // Show confirmation dialog
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (dialogContext) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text('Confirm Assignment'),
                                    content: Text(
                                      'Assign $userTypeName "${matchingClient.fullName}" to project "${currentProject.title}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[600],
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  final result = await assignUser(matchingClient.id);
                                  if (mounted) {
                                    if (result['success']) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$userTypeName assigned successfully!')),
                                      );
                                      await _loadProjects();
                                      setDialogState(() {});
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            result['message'] ?? 'Failed to assign $userTypeName',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              } else {
                                // Agent assignment
                                final agentsResult = await ApiService.getAvailableAgents();
                                if (!agentsResult['success']) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          agentsResult['message'] ?? 'Failed to load agents',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                final agents = (agentsResult['data']['agents'] as List<dynamic>)
                                    .map((a) => Agent.fromJson(a))
                                    .toList();

                                if (agents.isEmpty) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No agents available')),
                                    );
                                  }
                                  return;
                                }

                                // Find agent matching the email
                                final matchingAgent = agents.firstWhere(
                                  (a) => a.email.toLowerCase().trim() == infoEmail,
                                  orElse: () => agents.first, // Fallback to first if no match
                                );

                                // Show confirmation dialog
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (dialogContext) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text('Confirm Assignment'),
                                    content: Text(
                                      'Assign $userTypeName "${matchingAgent.fullName}" to project "${currentProject.title}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[600],
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  final result = await assignUser(matchingAgent.id);
                                  if (mounted) {
                                    if (result['success']) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$userTypeName assigned successfully!')),
                                      );
                                      await _loadProjects();
                                      setDialogState(() {});
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            result['message'] ?? 'Failed to assign $userTypeName',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.person_add, size: 18),
                            label: Text(
                              'Assign $userTypeName',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    // Get the current project from the list (may be updated after upload/delete)
    final currentProject = _projects.firstWhere(
      (p) => p.id == project.id,
      orElse: () => project,
    );

    // State variables that persist across rebuilds - using a class to hold state
    final uploadState = _UploadDialogState();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Get the current project from the list (may be updated after upload/delete)
          final currentProject = _projects.firstWhere(
            (p) => p.id == project.id,
            orElse: () => project,
          );
          
          // Get assigned users for this project
          final assignedUsers = <Map<String, dynamic>>[];
          
          if (currentProject.assignedFieldOfficerId != null) {
            assignedUsers.add({
              'id': currentProject.assignedFieldOfficerId!,
              'name': currentProject.assignedFieldOfficerName ?? currentProject.assignedFieldOfficerUsername ?? 'Field Officer',
              'role': 'Field Officer',
              'username': currentProject.assignedFieldOfficerUsername ?? '',
            });
          }
          
          if (currentProject.assignedClientId != null) {
            assignedUsers.add({
              'id': currentProject.assignedClientId!,
              'name': currentProject.assignedClientName ?? currentProject.assignedClientUsername ?? 'Client',
              'role': 'Client',
              'username': currentProject.assignedClientUsername ?? '',
            });
          }
          
          if (currentProject.assignedAgentId != null) {
            assignedUsers.add({
              'id': currentProject.assignedAgentId!,
              'name': currentProject.assignedAgentName ?? currentProject.assignedAgentUsername ?? 'Agent',
              'role': 'Agent',
              'username': currentProject.assignedAgentUsername ?? '',
            });
          }
          
          if (currentProject.assignedAccessorId != null) {
            assignedUsers.add({
              'id': currentProject.assignedAccessorId!,
              'name': currentProject.assignedAccessorName ?? currentProject.assignedAccessorUsername ?? 'Accessor',
              'role': 'Accessor',
              'username': currentProject.assignedAccessorUsername ?? '',
            });
          }
          
          if (currentProject.assignedSeniorValuerId != null) {
            assignedUsers.add({
              'id': currentProject.assignedSeniorValuerId!,
              'name': currentProject.assignedSeniorValuerName ?? currentProject.assignedSeniorValuerUsername ?? 'Senior Valuer',
              'role': 'Senior Valuer',
              'username': currentProject.assignedSeniorValuerUsername ?? '',
            });
          }

          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          final isSmallScreen = screenWidth < 360;
          
          return Dialog(
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
                    padding: EdgeInsets.all(_getResponsivePadding(context)),
                    decoration: BoxDecoration(
                      color: Colors.teal[500]!,
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
                            color: Colors.teal[400]!,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.attach_file, color: Colors.white, size: _getResponsiveIconSize(context)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Project Documents',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _getResponsiveFontSize(context, 20),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentProject.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _getResponsiveFontSize(context, 12),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                      padding: EdgeInsets.all(_getResponsivePadding(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Upload Form Section
                          if (assignedUsers.isNotEmpty) ...[
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(_getResponsivePadding(context) * 0.8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.upload_file, color: Colors.teal[700], size: _getResponsiveIconSize(context)),
                                        SizedBox(width: _getResponsivePadding(context) * 0.4),
                                        Text(
                                          'Upload New Document',
                                          style: TextStyle(
                                            fontSize: _getResponsiveFontSize(context, 14),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: _getResponsivePadding(context) * 0.8),
                                    // Assigned Users List
                                    Text(
                                      'Select Assigned User:',
                                      style: TextStyle(
                                        fontSize: _getResponsiveFontSize(context, 12),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: _getResponsivePadding(context) * 0.4),
                                    ...assignedUsers.map((user) {
                                      final nameStr = user['name'].toString();
                                      final usernameStr = user['username'].toString();
                                      final initials = nameStr.isNotEmpty
                                          ? nameStr.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').where((c) => c.isNotEmpty).take(2).join().toUpperCase()
                                          : usernameStr.isNotEmpty ? usernameStr.substring(0, 1).toUpperCase() : '?';
                                      final isSelected = uploadState.selectedUserId == user['id'];
                                      
                                      return Card(
                                        margin: EdgeInsets.only(bottom: _getResponsivePadding(context) * 0.4),
                                        elevation: isSelected ? 4 : 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: isSelected ? Colors.teal[600]! : Colors.grey[300]!,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            // Just select the user, don't open file picker automatically
                                            setDialogState(() {
                                              uploadState.selectedUserId = user['id'] as int;
                                              uploadState.selectedUserName = nameStr;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: EdgeInsets.all(_getResponsivePadding(context) * 0.6),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: _getResponsiveIconSize(context) * 0.8,
                                                  backgroundColor: isSelected ? Colors.teal[400] : Colors.grey[300],
                                                  child: Text(
                                                    initials,
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.white : Colors.grey[700],
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: _getResponsiveFontSize(context, 10),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: _getResponsivePadding(context) * 0.6),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        nameStr,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: _getResponsiveFontSize(context, 12),
                                                          color: isSelected ? Colors.teal[700] : Colors.black87,
                                                        ),
                                                      ),
                                                      Text(
                                                        user['role'],
                                                        style: TextStyle(
                                                          color: Colors.grey[600],
                                                          fontSize: _getResponsiveFontSize(context, 10),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(Icons.check_circle, color: Colors.teal[600], size: _getResponsiveIconSize(context)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    SizedBox(height: _getResponsivePadding(context)),
                                    // Show "Select File" button if user is selected but no file selected yet
                                    if (uploadState.selectedUserId != null && uploadState.selectedFile == null) ...[
                                      Container(
                                        padding: EdgeInsets.all(_getResponsivePadding(context) * 0.8),
                                        decoration: BoxDecoration(
                                          color: Colors.teal[50],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.teal[200]!, width: 2),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.teal[700], size: _getResponsiveIconSize(context)),
                                                SizedBox(width: _getResponsivePadding(context) * 0.4),
                                                Flexible(
                                                  child: Text(
                                                    'Selected: ${uploadState.selectedUserName ?? 'Unknown'}',
                                                    style: TextStyle(
                                                      fontSize: _getResponsiveFontSize(context, 12),
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.teal[800],
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: _getResponsivePadding(context) * 0.8),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  try {
                                                    final result = await FilePicker.platform.pickFiles(
                                                      type: FileType.any,
                                                      allowMultiple: false,
                                                    );
                                                    
                                                    if (result != null && result.files.isNotEmpty) {
                                                      try {
                                                        final files = result.files;
                                                        if (files.isEmpty) {
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text('No file selected'),
                                                                backgroundColor: Colors.red,
                                                              ),
                                                            );
                                                          }
                                                          return;
                                                        }
                                                        
                                                        final file = files.first;
                                                        // Safely access file properties - these can be null on some platforms
                                                        String? filePath;
                                                        String? fileName;
                                                        
                                                        try {
                                                          filePath = file.path;
                                                        } catch (e) {
                                                          filePath = null;
                                                        }
                                                        
                                                        try {
                                                          fileName = file.name;
                                                        } catch (e) {
                                                          fileName = null;
                                                        }
                                                        
                                                        if (filePath != null && filePath.isNotEmpty) {
                                                          setDialogState(() {
                                                            uploadState.selectedFile = filePath;
                                                            uploadState.selectedFileName = (fileName != null && fileName.isNotEmpty) ? fileName : 'document';
                                                          });
                                                        } else {
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text('Failed to get file path. Please try selecting the file again.'),
                                                                backgroundColor: Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      } catch (fileError) {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text('Error processing file: $fileError'),
                                                              backgroundColor: Colors.red,
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    }
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Error selecting file: $e'),
                                                          backgroundColor: Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                                icon: Icon(Icons.upload_file, size: _getResponsiveIconSize(context) * 0.9),
                                                label: Text(
                                                  'Select File',
                                                  style: TextStyle(fontSize: _getResponsiveFontSize(context, 14), fontWeight: FontWeight.w600),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.teal[600],
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(vertical: _getResponsivePadding(context) * 0.8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  elevation: 2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    // Show selected file info and upload button
                                    if (uploadState.selectedFile != null) ...[
                                      Card(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        color: Colors.green[50],
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Selected File:',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      uploadState.selectedFileName ?? 'Unknown file',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.green[900],
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.close, color: Colors.grey[600]),
                                                onPressed: () {
                                                  setDialogState(() {
                                                    uploadState.selectedFile = null;
                                                    uploadState.selectedFileName = null;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Upload Button - Prominently displayed after file selection
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Icon(Icons.upload, color: Colors.green[700], size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Ready to Upload',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: Colors.green[600]!,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey[300]!,
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: (uploadState.isUploading || uploadState.selectedFile == null || uploadState.selectedFileName == null) 
                                              ? null 
                                              : () async {
                                              setDialogState(() => uploadState.isUploading = true);
                                              
                                              try {
                                                // Validate required fields before upload
                                                final selectedFilePath = uploadState.selectedFile;
                                                final selectedFileName = uploadState.selectedFileName;
                                                
                                                if (selectedFilePath == null || selectedFilePath.isEmpty) {
                                                  setDialogState(() => uploadState.isUploading = false);
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Please select a file to upload'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                  return;
                                                }
                                                
                                                final uploadResult = await ApiService.uploadProjectDocument(
                                                  projectId: currentProject.id,
                                                  filePath: selectedFilePath,
                                                  fileName: selectedFileName ?? 'document',
                                                  assignedToId: uploadState.selectedUserId,
                                                );
                                                
                                                if (mounted) {
                                                  if (uploadResult['success']) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Document uploaded successfully${uploadState.selectedUserName != null ? ' for ${uploadState.selectedUserName}' : ''}!'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                    await _loadProjects();
                                                    setDialogState(() {
                                                      uploadState.selectedUserId = null;
                                                      uploadState.selectedUserName = null;
                                                      uploadState.selectedFile = null;
                                                      uploadState.selectedFileName = null;
                                                      uploadState.isUploading = false;
                                                    });
                                                  } else {
                                                    setDialogState(() => uploadState.isUploading = false);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Row(
                                                          children: [
                                                            const Icon(Icons.error, color: Colors.white, size: 20),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                uploadResult['message'] ?? 'Failed to upload document',
                                                                style: const TextStyle(fontSize: 14),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        backgroundColor: Colors.red,
                                                        duration: const Duration(seconds: 4),
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                setDialogState(() => uploadState.isUploading = false);
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Row(
                                                        children: [
                                                          const Icon(Icons.error, color: Colors.white, size: 20),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'Upload error: ${e.toString()}',
                                                              style: const TextStyle(fontSize: 14),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      backgroundColor: Colors.red,
                                                      duration: const Duration(seconds: 4),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            icon: uploadState.isUploading 
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  )
                                                : const Icon(Icons.cloud_upload, size: 20),
                                            label: Text(
                                              uploadState.isUploading ? 'Uploading...' : 'Upload',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 18),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (assignedUsers.isEmpty) ...[
                            // No assigned users message
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.orange[700], size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'No assigned users found. Please assign users to the project first.',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          // Documents List
                          if (currentProject.documents.isNotEmpty) ...[
                            const Text(
                              'Uploaded Documents',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...currentProject.documents.map((doc) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.teal[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.insert_drive_file,
                                      color: Colors.teal[700],
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    doc.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      if (doc.assignedToName != null) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Receiver: ${doc.assignedToName}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Sent: ${DateFormat('MMM dd, yyyy • hh:mm a').format(doc.uploadedAt)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (dialogContext) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          title: const Text('Delete Document'),
                                          content: Text(
                                            'Are you sure you want to delete "${doc.name}"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(dialogContext).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.of(dialogContext).pop(true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red[600],
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        final deleteResult = await ApiService.deleteProjectDocument(doc.id);
                                        if (mounted) {
                                          if (deleteResult['success']) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Document deleted successfully'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            await _loadProjects();
                                            setDialogState(() {});
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  deleteResult['message'] ?? 'Failed to delete document',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                  onTap: doc.fileUrl != null
                                      ? () {
                                          // Open file URL if available
                                          // You can implement file viewing logic here
                                        }
                                      : null,
                                ),
                              );
                            }),
                          ],
                          if (currentProject.documents.isEmpty && assignedUsers.isNotEmpty) ...[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No documents',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 18),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload documents to attach them to this project',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Action Buttons
                  Container(
                    padding: EdgeInsets.all(_getResponsivePadding(context)),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(isSmallScreen ? 16 : 20),
                        bottomRight: Radius.circular(isSmallScreen ? 16 : 20),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: _getResponsivePadding(context) * 0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Close', style: TextStyle(fontSize: _getResponsiveFontSize(context, 14))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _uploadDocument(Project project) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final filePathNullable = file.path;
        if (filePathNullable == null || filePathNullable.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to get file path'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        final filePath = filePathNullable; // Now guaranteed non-null
        final fileName = (file.name != null && file.name.isNotEmpty) ? file.name : 'document';

        final uploadResult = await ApiService.uploadProjectDocument(
          projectId: project.id,
          filePath: filePath,
          fileName: fileName,
        );

        if (mounted) {
          if (uploadResult['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document uploaded successfully!')),
            );
            await _loadProjects();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(uploadResult['message'] ?? 'Failed to upload document')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _uploadDocumentWithUserSelection(Project project, StateSetter setDialogState) async {
    // Get assigned users for this project
    final assignedUsers = <Map<String, dynamic>>[];
    
    if (project.assignedFieldOfficerId != null) {
      assignedUsers.add({
        'id': project.assignedFieldOfficerId!,
        'name': project.assignedFieldOfficerName ?? project.assignedFieldOfficerUsername ?? 'Field Officer',
        'role': 'Field Officer',
        'username': project.assignedFieldOfficerUsername ?? '',
      });
    }
    
    if (project.assignedClientId != null) {
      assignedUsers.add({
        'id': project.assignedClientId!,
        'name': project.assignedClientName ?? project.assignedClientUsername ?? 'Client',
        'role': 'Client',
        'username': project.assignedClientUsername ?? '',
      });
    }
    
    if (project.assignedAgentId != null) {
      assignedUsers.add({
        'id': project.assignedAgentId!,
        'name': project.assignedAgentName ?? project.assignedAgentUsername ?? 'Agent',
        'role': 'Agent',
        'username': project.assignedAgentUsername ?? '',
      });
    }
    
    if (project.assignedAccessorId != null) {
      assignedUsers.add({
        'id': project.assignedAccessorId!,
        'name': project.assignedAccessorName ?? project.assignedAccessorUsername ?? 'Accessor',
        'role': 'Accessor',
        'username': project.assignedAccessorUsername ?? '',
      });
    }
    
    if (project.assignedSeniorValuerId != null) {
      assignedUsers.add({
        'id': project.assignedSeniorValuerId!,
        'name': project.assignedSeniorValuerName ?? project.assignedSeniorValuerUsername ?? 'Senior Valuer',
        'role': 'Senior Valuer',
        'username': project.assignedSeniorValuerUsername ?? '',
      });
    }
    
    // If no assigned users, show message and return
    if (assignedUsers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No assigned users found. Please assign users to the project first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Show dialog to select assigned user
    final selectedUser = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.teal[500]!,
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
                              color: Colors.teal[400]!,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Select Assigned User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              // User List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: assignedUsers.length,
                  itemBuilder: (context, index) {
                    final user = assignedUsers[index];
                    final nameStr = user['name'].toString();
                    final usernameStr = user['username'].toString();
                    final initials = nameStr.isNotEmpty
                        ? nameStr.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').where((c) => c.isNotEmpty).take(2).join().toUpperCase()
                        : usernameStr.isNotEmpty ? usernameStr.substring(0, 1).toUpperCase() : '?';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => Navigator.of(dialogContext).pop(user),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.teal[400],
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nameStr,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user['role'],
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (usernameStr.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '@$usernameStr',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    if (selectedUser == null) {
      return; // User cancelled
    }
    
    // Now pick the file
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final filePathNullable = file.path;
        if (filePathNullable == null || filePathNullable.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to get file path'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        final filePath = filePathNullable; // Now guaranteed non-null
        final fileName = (file.name != null && file.name.isNotEmpty) ? file.name : 'document';

        final uploadResult = await ApiService.uploadProjectDocument(
          projectId: project.id,
          filePath: filePath,
          fileName: fileName,
          assignedToId: selectedUser['id'] as int,
        );

        if (mounted) {
          if (uploadResult['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Document uploaded successfully for ${selectedUser['name']}!'),
                backgroundColor: Colors.green,
              ),
            );
            await _loadProjects();
            setDialogState(() {});
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  uploadResult['message'] ?? 'Failed to upload document',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewProjectDetails(Project project) async {
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
      barrierDismissible: false,
      builder: (dialogContext) {
        return DefaultTabController(
          length: 2,
          child: Builder(
            builder: (context) {
              final tabController = DefaultTabController.of(context);
              return StatefulBuilder(
                builder: (context, setState) {
                  // Add listener for tab changes
                  tabController.addListener(() {
                    if (mounted) {
                      setState(() {});
                    }
                  });
                  return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20)),
              child: Container(
                width: screenWidth * (isSmallScreen ? 0.95 : 0.9),
                constraints: BoxConstraints(
                  maxHeight: screenHeight * (isSmallScreen ? 0.9 : 0.85),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with solid color
                    Container(
                      padding: EdgeInsets.all(_getResponsivePadding(context)),
                      decoration: BoxDecoration(
                        color: Colors.blue[600]!,
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
                            child: Icon(
                              Icons.folder_open,
                              color: Colors.white,
                              size: _getResponsiveIconSize(context),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  finalProject.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _getResponsiveFontSize(context, 20),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getProjectStatusColor(finalProject.status),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        finalProject.statusDisplay,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    // Tab Bar with white background
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: TabBar(
                        controller: tabController,
                        indicator: BoxDecoration(
                          color: Colors.blue[50]!.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.blue[700],
                        unselectedLabelColor: Colors.grey[600],
                        labelStyle: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                        tabAlignment: TabAlignment.fill,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: tabController.index == 0 
                                        ? Colors.blue[50]!.withOpacity(0.5)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: tabController.index == 0
                                          ? Colors.blue[700]!
                                          : Colors.grey[600]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 11,
                                    color: tabController.index == 0
                                        ? Colors.blue[700]
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'Details',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: tabController.index == 1 
                                        ? Colors.blue[50]!.withOpacity(0.5)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: tabController.index == 1
                                          ? Colors.blue[700]!
                                          : Colors.grey[600]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.assessment_outlined,
                                    size: 11,
                                    color: tabController.index == 1
                                        ? Colors.blue[700]
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'Reports',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                // Tab Content
                Flexible(
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      // Details Tab
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description Card
                            if (finalProject.description != null) ...[
                              _buildModernInfoCard(
                                icon: Icons.description,
                                label: 'Description',
                                value: finalProject.description!,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Priority Card
                            _buildModernInfoCard(
                              icon: Icons.flag,
                              label: 'Priority',
                              value: _formatPriorityLabel(finalProject.priority ?? 'medium'),
                              color: _getPriorityColor(finalProject.priority ?? 'medium'),
                            ),
                            const SizedBox(height: 12),
                            // Coordinator Card
                            _buildModernInfoCard(
                              icon: Icons.person,
                              label: 'Coordinator',
                              value: finalProject.coordinatorName ?? finalProject.coordinatorUsername ?? 'Not assigned',
                              color: Colors.blue,
                            ),
                            // Dates
                            if (finalProject.startDate != null || finalProject.endDate != null) ...[
                              const SizedBox(height: 12),
                              _buildModernInfoCard(
                                icon: Icons.calendar_today,
                                label: 'Project Dates',
                                value: _buildDatesText(finalProject),
                                color: Colors.blue,
                              ),
                            ],
                            // Assigned Users
                            const SizedBox(height: 12),
                            _buildModernInfoCard(
                              icon: Icons.people_outline,
                              label: 'Assigned Users',
                              value: _buildAssignedUsersText(finalProject),
                              color: Colors.blue,
                            ),
                            // Documents
                            if (finalProject.documents.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.folder_outlined, color: Colors.blue[700], size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Documents (${finalProject.documents.length})',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ...finalProject.documents.map((doc) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.insert_drive_file, color: Colors.grey, size: 20),
                                          ),
                                          title: Text(
                                            doc.name,
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                          subtitle: Text(
                                            doc.fileSizeFormatted,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20),
                                            color: Colors.red[700],
                                            onPressed: () async {
                                              final deleteResult = await ApiService.deleteProjectDocument(doc.id);
                                              if (deleteResult['success']) {
                                                Navigator.of(dialogContext).pop();
                                                await _loadProjects();
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Document deleted'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Valuation Reports Tab
                      finalProject.valuations.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No valuation reports yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Field officers will generate reports here',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
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
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                await _generatePdfReport(valuation, finalProject);
                                              },
                                              icon: const Icon(Icons.article, size: 20),
                                              label: const Text('View PDF Report'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange[700],
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
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
        );
                },
              );
            },
          ),
          );
        },
      );
  }
  
  String _buildDatesText(Project project) {
    final parts = <String>[];
    if (project.startDate != null) {
      parts.add('Start: ${DateFormat('MMM dd, yyyy').format(project.startDate!)}');
    }
    if (project.endDate != null) {
      parts.add('End: ${DateFormat('MMM dd, yyyy').format(project.endDate!)}');
    }
    return parts.join('\n');
  }
  
  String _buildAssignedUsersText(Project project) {
    final parts = <String>[];
    if (project.assignedFieldOfficerName != null) {
      parts.add('Field Officer: ${project.assignedFieldOfficerName}');
    } else {
      parts.add('Field Officer: Not assigned');
    }
    if (project.assignedClientName != null) {
      parts.add('Client: ${project.assignedClientName}');
    } else {
      parts.add('Client: Not assigned');
    }
    if (project.hasAgent && project.assignedAgentName != null) {
      parts.add('Agent: ${project.assignedAgentName}');
    }
    return parts.join('\n');
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
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _generatePdfReport(Valuation valuation, Project project) async {
    try {
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
            backgroundColor: Colors.green,
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
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
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

  bool _isAfter12PM() {
    final now = DateTime.now();
    return now.hour >= 12;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_username != null || _roleDisplay != null)
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
                                ? Colors.white
                                : Colors.black87,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _username!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    if (_username != null && _roleDisplay != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Container(
                          width: 1,
                          height: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]!
                              : Colors.grey[400]!,
                        ),
                      ),
                    if (_roleDisplay != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[200]!
                              : Colors.grey[200]!,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[400]!
                                : Colors.grey[400]!,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey[300]!,
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
                                  ? Colors.white
                                  : Colors.blue[700]!,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _roleDisplay!,
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.access_time), text: 'Attendance'),
            Tab(icon: Icon(Icons.folder), text: 'Projects'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAttendanceTab(),
          _buildProjectsTab(),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return GenericDashboard(
      role: 'coordinator',
      roleDisplay: _roleDisplay ?? 'Coordinator',
      isEmbedded: true,
    );
  }

  List<Project> _filterAndSortProjects(List<Project> projects, int tabIndex) {
    // Get search query for this tab
    final searchQuery = _searchControllers[tabIndex]?.text.toLowerCase().trim() ?? '';
    
    // Filter by search query
    var filtered = projects.where((p) {
      if (searchQuery.isEmpty) return true;
      return p.title.toLowerCase().contains(searchQuery) ||
          (p.description?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();
    
    // Get sort option for this tab (default to date_asc)
    final sortOption = _sortOptions[tabIndex] ?? 'date_asc';
    
    // Sort projects
    switch (sortOption) {
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

  Widget _buildProjectListWithSearch(List<Project> projects, String emptyTitle, String emptySubtitle, {bool isReceivedTab = false, bool isCancelledTab = false, required int tabIndex}) {
    return Column(
      children: [
        // Search and Sort Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  controller: _searchControllers[tabIndex],
                  decoration: InputDecoration(
                    hintText: 'Search projects...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchControllers[tabIndex]?.text.isNotEmpty == true
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchControllers[tabIndex]?.clear();
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
                      value: _sortOptions[tabIndex] ?? 'date_asc',
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
                          _sortOptions[tabIndex] = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Project list
        Expanded(
          child: projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        emptyTitle,
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        emptySubtitle,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: isReceivedTab ? 6 : 12),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _buildProjectCard(project, isReceivedTab: isReceivedTab, isCancelledTab: isCancelledTab);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProjectList(List<Project> projects, String emptyTitle, String emptySubtitle, {bool isReceivedTab = false, bool isCancelledTab = false}) {
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isReceivedTab ? 6 : 12),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _buildProjectCard(project, isReceivedTab: isReceivedTab, isCancelledTab: isCancelledTab);
      },
    );
  }

  Widget _buildProjectCard(Project project, {bool isReceivedTab = false, bool isCancelledTab = false}) {
    final isPending = project.status.toLowerCase() == 'pending';
    final isOngoing = project.status.toLowerCase() == 'in_progress';
    final priority = project.priority ?? 'medium';

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
                        if (!_recreatedProjectIds.contains(project.id)) ...[
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
  
  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch email client for $email')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening email: $e')),
        );
      }
    }
  }

  Future<void> _showContactAssignedUsers(Project project) async {
    final List<Map<String, String>> contacts = [];
    
    if (project.assignedFieldOfficerName != null) {
      contacts.add({
        'role': 'Field Officer',
        'name': project.assignedFieldOfficerName!,
        'email': project.assignedFieldOfficerEmail ?? 'N/A',
        'username': project.assignedFieldOfficerUsername ?? 'N/A',
      });
    }
    
    if (project.assignedClientName != null) {
      contacts.add({
        'role': 'Client',
        'name': project.assignedClientName!,
        'email': project.assignedClientEmail ?? 'N/A',
        'username': project.assignedClientUsername ?? 'N/A',
      });
    }
    
    if (project.assignedAgentName != null) {
      contacts.add({
        'role': 'Agent',
        'name': project.assignedAgentName!,
        'email': project.assignedAgentEmail ?? 'N/A',
        'username': project.assignedAgentUsername ?? 'N/A',
      });
    }
    
    if (project.assignedAccessorName != null) {
      contacts.add({
        'role': 'Accessor',
        'name': project.assignedAccessorName!,
        'email': project.assignedAccessorEmail ?? 'N/A',
        'username': project.assignedAccessorUsername ?? 'N/A',
      });
    }
    
    if (project.assignedSeniorValuerName != null) {
      contacts.add({
        'role': 'Senior Valuer',
        'name': project.assignedSeniorValuerName!,
        'email': project.assignedSeniorValuerEmail ?? 'N/A',
        'username': project.assignedSeniorValuerUsername ?? 'N/A',
      });
    }
    
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assigned users to contact')),
      );
      return;
    }
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.lightBlue[500]!,
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
                              color: Colors.lightBlue[400]!,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.contact_mail, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Contact Assigned Users',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: contacts.map((contact) {
                      final roleColor = contact['role'] == 'Field Officer'
                          ? Colors.lightBlue[700]
                          : contact['role'] == 'Client'
                              ? Colors.cyan[700]
                              : contact['role'] == 'Agent'
                                  ? Colors.orange[700]
                                  : contact['role'] == 'Accessor'
                                      ? Colors.purple[700]
                                      : Colors.teal[700]; // Senior Valuer
                      final roleIcon = contact['role'] == 'Field Officer'
                          ? Icons.person
                          : contact['role'] == 'Client'
                              ? Icons.business
                              : contact['role'] == 'Agent'
                                  ? Icons.badge
                                  : contact['role'] == 'Accessor'
                                      ? Icons.assessment
                                      : Icons.verified_user; // Senior Valuer

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            if (contact['email'] != null && contact['email'] != 'N/A') {
                              _launchEmail(contact['email']!);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Email address not available'),
                                ),
                              );
                            }
                          },
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
                                        color: Colors.blue[100]!,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(roleIcon, color: roleColor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      contact['role']!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: roleColor,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey[400],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  contact['name']!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.email, size: 18, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        contact['email']!,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 18, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      '@${contact['username']!}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[600]!;
      case 'in_progress':
        return Colors.blue[400]!;
      case 'completed':
        return Colors.green[600]!;
      case 'cancelled':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  // Copy attendance UI methods from generic dashboard
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
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildAnimatedCountdown(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _buildAttendanceButton(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Chip(
                        label: Text(_todayAttendance!.statusDisplay),
                        backgroundColor: _getAttendanceStatusColor(_todayAttendance!.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildAnimatedCountdown(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _buildLeaveEarlyButton(),
                        ),
                      ],
                    ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Status:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Chip(
                        label: Text(_todayAttendance!.statusDisplay),
                        backgroundColor: _getAttendanceStatusColor(_todayAttendance!.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_todayAttendance!.checkIn != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Check-in:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(DateFormat('hh:mm a').format(_todayAttendance!.checkIn!)),
                      ],
                    ),
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
        color: Colors.grey[200]!,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!),
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
          final color = _getAttendanceStatusColor(dayData.status);
          
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

  Color _getAttendanceStatusColor(String status) {
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

    // Fully rounded pill-shaped label
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildStatusRibbon(Project project) {
    final isPending = project.status == 'pending';
    final color = isPending
        ? Colors.amber[600]!
        : project.status == 'in_progress'
            ? Colors.blue[400]!
            : project.status == 'completed'
                ? Colors.teal[600]!
                : project.status == 'cancelled'
                    ? Colors.red[600]!
                    : _getStatusColor(project.status);
    final label = project.status == 'cancelled' ? 'Cancel' : project.statusDisplay;

    // Fully rounded pill-shaped label
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Color _getProjectStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber[600]!;
      case 'in_progress':
        return Colors.blue[400]!;
      case 'completed':
        return Colors.green[600]!;
      case 'cancelled':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildCreateProjectButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            width: double.infinity,
            // Let the button grow with text size instead of a fixed height
            constraints: BoxConstraints(
              minHeight: isSmallScreen ? 60 : 72,
            ),
            decoration: BoxDecoration(
              color: _isCreatingProject
                  ? Colors.green[500]!
                  : Colors.green[600]!,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey[200]!,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.grey[200]!,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isCreatingProject ? null : _createProject,
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.grey[300]!,
                highlightColor: Colors.grey[200]!,
                child: Stack(
                  children: [
                    // Pulsing background effect (only when not loading)
                    if (!_isCreatingProject)
                      _PulsingButtonBackground(color: Colors.green),
                    // Button content
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16.0 : 24.0,
                        vertical: isSmallScreen ? 12.0 : 16.0,
                      ),
                      child: _isCreatingProject
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Flexible(
                                  child: Text(
                                    'Creating Project...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[400]!,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey[400]!,
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.create_new_folder,
                                    color: Colors.white,
                                    size: isSmallScreen ? 24 : 28,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 12 : 16),
                                Flexible(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Create New Project',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 16 : 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (!isSmallScreen)
                                        Text(
                                          'Start a new project',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
            ),
          ),
        );
      },
    );
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
              color: isAfter5PM
                  ? Colors.red[400]!
                  : isNearEnd
                      ? Colors.orange[400]!
                      : Colors.blue[400]!,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey[300]!,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                if (!isAfter5PM)
                  _PulsingContainer(
                    color: isNearEnd ? Colors.orange : Colors.blue,
                  ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RotatingIcon(
                        icon: Icons.timer,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
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
                                            color: Colors.white,
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
        color: Colors.green[500]!,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!,
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
                          color: Colors.grey[200]!,
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
        color: Colors.orange[500]!,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
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
                  await _loadTodayAttendance();
                }
              }
            }
          },
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
                              color: Colors.grey[200]!,
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
            color: Colors.grey[200]!,
          ),
        );
      },
    );
  }
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
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey[200]!,
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

class _HoverableStartButton extends StatefulWidget {
  final bool canStart;
  final VoidCallback onPressed;

  const _HoverableStartButton({
    required this.canStart,
    required this.onPressed,
  });

  @override
  State<_HoverableStartButton> createState() => _HoverableStartButtonState();
}

class _HoverableStartButtonState extends State<_HoverableStartButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Always use green theme for start button
    final backgroundColor = _isHovered ? Colors.green[700]! : Colors.green[600]!;
    final foregroundColor = Colors.white;
    final iconColor = Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ElevatedButton(
        // Always allow press; assignment validation and message
        // are handled inside _startProject / _canStartProject.
        onPressed: widget.onPressed,
        child: Text(
          'Start',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: foregroundColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor,
          disabledForegroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          fixedSize: const Size(70, 28),
          elevation: _isHovered ? 3 : 2,
          shadowColor: Colors.grey[400]!,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
    );
  }
}

class _HoverableCancelButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _HoverableCancelButton({
    required this.onPressed,
  });

  @override
  State<_HoverableCancelButton> createState() => _HoverableCancelButtonState();
}

class _HoverableCancelButtonState extends State<_HoverableCancelButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Red theme for cancel button
    final backgroundColor = _isHovered ? Colors.red[700]! : Colors.red[600]!;
    final foregroundColor = Colors.white;
    final iconColor = Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        child: Text(
          'Cancel',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: foregroundColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          fixedSize: const Size(60, 24),
          elevation: _isHovered ? 3 : 2,
          shadowColor: Colors.grey[400]!,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
    );
  }
}

class _HoverableCompleteButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _HoverableCompleteButton({
    required this.onPressed,
  });

  @override
  State<_HoverableCompleteButton> createState() => _HoverableCompleteButtonState();
}

class _HoverableCompleteButtonState extends State<_HoverableCompleteButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Teal/green theme for complete button
    final backgroundColor = _isHovered ? Colors.teal[700]! : Colors.teal[600]!;
    final foregroundColor = Colors.white;
    final iconColor = Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        child: Text(
          'Complete',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: foregroundColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          fixedSize: const Size(60, 24),
          elevation: _isHovered ? 3 : 2,
          shadowColor: Colors.grey[400]!,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
    );
  }
}


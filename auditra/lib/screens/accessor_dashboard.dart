import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../models/project_model.dart';
import '../models/valuation_model.dart';
import 'login_screen.dart';
import 'generic_dashboard.dart';

class AccessorDashboard extends StatefulWidget {
  const AccessorDashboard({super.key});

  @override
  State<AccessorDashboard> createState() => _AccessorDashboardState();
}

class _AccessorDashboardState extends State<AccessorDashboard> with TickerProviderStateMixin {
  String? _username;
  String? _roleDisplay;
  
  // Project state
  List<Project> _projects = [];
  bool _isLoadingProjects = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadUserInfo();
    _loadProjects();
  }

  @override
  void dispose() {
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

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
    });
    final result = await ApiService.getProjects();
    
    if (mounted) {
      setState(() {
        _isLoadingProjects = false;
        if (result['success']) {
          try {
            final data = result['data'] as List<dynamic>;
            _projects = data.map((p) => Project.fromJson(p)).toList();
          } catch (e) {
            print('Error parsing projects: $e');
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
                  color: Colors.purple[500]!,
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
                        color: Colors.purple[400]!,
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
                      color: Colors.purple[300],
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
                          backgroundColor: Colors.purple[600],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Accessor Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
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
                    if (_username != null && _roleDisplay != null)
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
                    if (_roleDisplay != null)
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
                                    Colors.purple.withOpacity(0.15),
                                    Colors.purple.withOpacity(0.1),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.3)
                                : Colors.purple.withOpacity(0.3),
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
                                  : Colors.purple[700],
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
                                    : Colors.purple[900],
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
          GenericDashboard(
            role: 'accessor',
            roleDisplay: _roleDisplay ?? 'Accessor',
            isEmbedded: true,
          ),
          _buildProjectsTab(),
        ],
      ),
    );
  }

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
                      Icon(Icons.assessment, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${project.valuationsCount} reports',
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
      builder: (context) => DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return StatefulBuilder(
              builder: (context, setState) {
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
                        // Header
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.purple[600]!,
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
                                  color: Colors.purple[400]!,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.folder_open, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      finalProject.title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 18 : 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        finalProject.statusDisplay,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                        // Tab Bar
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: TabBar(
                            controller: tabController,
                            indicator: BoxDecoration(
                              color: Colors.purple[50]!.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: Colors.purple[700],
                            unselectedLabelColor: Colors.grey[600],
                            tabAlignment: TabAlignment.fill,
                            tabs: const [
                              Tab(text: 'Details'),
                              Tab(text: 'Reports'),
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
                                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (finalProject.description != null) ...[
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
                                                  Icon(Icons.description, color: Colors.purple[700], size: 20),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'Description',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                finalProject.description!,
                                                style: TextStyle(color: Colors.grey[800], fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    _buildModernInfoCard(
                                      icon: Icons.flag,
                                      label: 'Priority',
                                      value: _formatPriorityLabel(finalProject.priority ?? 'medium'),
                                      color: _getPriorityColor(finalProject.priority ?? 'medium'),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildModernInfoCard(
                                      icon: Icons.person,
                                      label: 'Coordinator',
                                      value: finalProject.coordinatorName ?? finalProject.coordinatorUsername,
                                      color: Colors.blue,
                                    ),
                                    if (finalProject.assignedFieldOfficerName != null) ...[
                                      const SizedBox(height: 12),
                                      _buildModernInfoCard(
                                        icon: Icons.person_outline,
                                        label: 'Field Officer',
                                        value: finalProject.assignedFieldOfficerName ?? finalProject.assignedFieldOfficerUsername ?? 'N/A',
                                        color: Colors.green,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Reports Tab
                              SingleChildScrollView(
                                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                            decoration: BoxDecoration(
                                              color: Colors.purple[50],
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
                                                    color: Colors.purple[100],
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(Icons.assessment, color: Colors.purple[700], size: 20),
                                                ),
                                                const SizedBox(width: 12),
                                                const Expanded(
                                                  child: Text(
                                                    'Valuation Reports',
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
                                                    color: Colors.purple[700],
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
                                                      'No reports available',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.grey[600],
                                                        fontWeight: FontWeight.w500,
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
                                                children: finalProject.valuations
                                                    .where((v) => v.status != 'draft') // Only show submitted/reviewed reports
                                                    .map((valuation) => Padding(
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
                                                                  // PDF Download Button
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
                                                        ))
                                                    .toList(),
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
                      ],
                    ),
                  ),
                );
              },
            );
          },
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
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error generating PDF: $e');
    }
  }
}


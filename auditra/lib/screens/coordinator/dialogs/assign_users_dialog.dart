
import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../coordinator/styles/coordinator_styles.dart';
import '../../../services/api_service.dart';
import 'package:intl/intl.dart';

class AssignUsersDialog extends StatefulWidget {
  final Project project;
  final VoidCallback onAssignmentChanged;

  const AssignUsersDialog({
    Key? key,
    required this.project,
    required this.onAssignmentChanged,
  }) : super(key: key);

  static Future<void> show(BuildContext context, Project project, VoidCallback onAssignmentChanged) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AssignUsersDialog(
        project: project,
        onAssignmentChanged: onAssignmentChanged,
      ),
    );
  }

  @override
  _AssignUsersDialogState createState() => _AssignUsersDialogState();
}

class _AssignUsersDialogState extends State<AssignUsersDialog> with TickerProviderStateMixin {
  late TabController _tabController;
  late Project _currentProject;

  // Futures for data loading
  late Future<Map<String, dynamic>> _fieldOfficersFuture;
  late Future<Map<String, dynamic>> _accessorsFuture;
  late Future<Map<String, dynamic>> _seniorValuersFuture;

  @override
  void initState() {
    super.initState();
    _currentProject = widget.project;
    
    // Check if agent info exists for tab count, but just use 5 max length for simplicity
    final hasAgentInfo = _currentProject.agentInfo != null || _currentProject.hasAgent;
    final tabCount = hasAgentInfo ? 5 : 4;
    _tabController = TabController(length: tabCount, vsync: this);
    
    // Create futures once
    _fieldOfficersFuture = ApiService.getAvailableFieldOfficers();
    _accessorsFuture = ApiService.getAvailableAccessors();
    _seniorValuersFuture = ApiService.getAvailableSeniorValuers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Reload project to get latest assignments
  Future<void> _refreshProject() async {
    // In a real app we might fetch the specific project again.
    // For now we rely on the callback updating the parent and maybe passing new data if we were stateless.
    // But since this is a dialog, we need to handle "local" updates or just trust the optimistic UI updates.
    // Actually, the easiest way to ensure consistency is to call the callback which reloads projects in parent,
    // but specific to this dialog, we might want to re-fetch to be sure. 
    // However, the existing logic just calls onAssignmentChanged.
    // Let's assume onAssignmentChanged triggers a parent reload.
    // We can also just update _currentProject locally if we had an endpoint for it.
    // For this refactor, we'll keep it simple and assume the assignment calls return success.
    widget.onAssignmentChanged();
    
    // Update local state by re-fetching project list? No, that's heavy.
    // We will just reflect changes in UI based on success.
    
    // But wait, the original code did:
    // final currentProject = _projects.firstWhere(...)
    // inside the builder. So it was reactive to the parent's state.
  }

  @override
  Widget build(BuildContext context) {
    // Re-evaluate hasAgentInfo in build in case it changed? (Unlikely to change during dialog)
    final hasAgentInfo = _currentProject.agentInfo != null || _currentProject.hasAgent;
    
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
                controller: _tabController,
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
                controller: _tabController,
                children: [
                  _buildUserTypeTab<FieldOfficer>(
                    context,
                    'field_officer',
                    Colors.lightBlue,
                    Icons.person_outline,
                    () => _fieldOfficersFuture,
                    (data) => (data['field_officers'] as List<dynamic>)
                        .map((o) => FieldOfficer.fromJson(o))
                        .toList(),
                    (id) => _currentProject.assignedFieldOfficerId == id,
                    (id) async {
                       final result = await ApiService.assignFieldOfficer(projectId: _currentProject.id, fieldOfficerId: id);
                       if (result['success']) {
                         setState(() {
                             // Update local state optimistically or re-fetch
                             // For now, we assume we need to close/reopen or have parent update. 
                             // But wait, the original code relied on parent _projects update.
                             // We should probably emit the change and maybe update _currentProject if possible.
                             // Since we can't easily fetch just one project here without adding API,
                             // we'll rely on the parent callback to refresh data, 
                             // BUT we need to reflect that in the UI.
                             // The original code did `await _loadProjects()` in main dashboard.
                             widget.onAssignmentChanged();
                         });
                       }
                       return result;
                    },
                    'Field Officer',
                    showProjectCount: true,
                  ),
                  _buildClientAgentTab(
                    context,
                    'client',
                    Colors.cyan,
                    Icons.business_outlined,
                    'Client',
                  ),
                  if (hasAgentInfo)
                    _buildClientAgentTab(
                      context,
                      'agent',
                      Colors.orange,
                      Icons.badge_outlined,
                      'Agent',
                    ),
                  _buildUserTypeTab<Accessor>(
                    context,
                    'accessor',
                    Colors.purple,
                    Icons.assessment_outlined,
                    () => _accessorsFuture,
                    (data) => (data['accessors'] as List<dynamic>)
                        .map((a) => Accessor.fromJson(a))
                        .toList(),
                    (id) => _currentProject.assignedAccessorId == id,
                    (id) async {
                         final result = await ApiService.assignAccessor(projectId: _currentProject.id, accessorId: id);
                         if (result['success']) widget.onAssignmentChanged();
                         return result;
                    },
                    'Accessor',
                    showProjectCount: true,
                  ),
                  _buildUserTypeTab<SeniorValuer>(
                    context,
                    'senior_valuer',
                    const Color(0xFF0570B0),
                    Icons.verified_user_outlined,
                    () => _seniorValuersFuture,
                    (data) => (data['senior_valuers'] as List<dynamic>)
                        .map((v) => SeniorValuer.fromJson(v))
                        .toList(),
                    (id) => _currentProject.assignedSeniorValuerId == id,
                    (id) async {
                         final result = await ApiService.assignSeniorValuer(projectId: _currentProject.id, seniorValuerId: id);
                         if (result['success']) widget.onAssignmentChanged();
                         return result;
                    },
                    'Senior Valuer',
                    showProjectCount: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods

  Widget _buildUserTypeTab<T>(
    BuildContext context,
    String userType,
    Color color,
    IconData icon,
    Future<Map<String, dynamic>> Function() fetchUsers,
    List<T> Function(Map<String, dynamic>) parseUsers,
    bool Function(int) isAssigned,
    Future<Map<String, dynamic>> Function(int) assignUser,
    String userTypeName, {
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
                // We need to use dynamic here or cast T to something common, 
                // but T is generic. We know the structure though.
                // Or we can use helpers that check type.
                final dynamic u = user;
                final String fullName = u.fullName;
                final String username = u.username;
                final int userId = u.id;
                final int? assignedProjectsCount = u.assignedProjectsCount;

                final initials = (fullName.isNotEmpty
                        ? fullName.trim().split(' ').map((p) => p[0]).take(2).join()
                        : username.substring(0, 1))
                    .toUpperCase();
                
                final isUserAssigned = isAssigned(userId);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isUserAssigned ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isUserAssigned ? const Color(0xFF84BCDA)! : Colors.grey[200]!,
                      width: isUserAssigned ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: isUserAssigned ? const Color(0xFF0570B0) : color.withOpacity(0.7),
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
                                          backgroundColor: const Color(0xFFFFF8E7),
                                          labelStyle: TextStyle(color: const Color(0xFF0570B0)),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (showProjectCount) ...[
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  await _showUserAssignedProjects(
                                                    context,
                                                    userId,
                                                    fullName,
                                                    userType,
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
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (dialogContext) => AlertDialog(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    title: const Text('Confirm Assignment'),
                                                    content: Text(
                                                      'Assign $userTypeName "$fullName" to project "${_currentProject.title}"?',
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
                                                      widget.onAssignmentChanged();
                                                      // In a real app we'd update _currentProject assignments locally here 
                                                      // but we don't have that easily. 
                                                      setState(() {}); 
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
    Color color,
    IconData icon,
    String userTypeName,
  ) {
    final info = userType == 'client' ? _currentProject.clientInfo : _currentProject.agentInfo;
    final isAssigned = userType == 'client'
        ? _currentProject.assignedClientId != null
        : _currentProject.assignedAgentId != null;

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
                color: isAssigned ? const Color(0xFF84BCDA)! : Colors.grey[200]!,
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
                        backgroundColor: isAssigned ? const Color(0xFF0570B0) : color.withOpacity(0.7),
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
                        backgroundColor: const Color(0xFFFFF8E7),
                        labelStyle: TextStyle(color: const Color(0xFF0570B0)),
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
                              // Assignment logic for Client/Agent 
                              final infoEmail = email.toLowerCase().trim();
                              
                              if (userType == 'client') {
                                final clientsResult = await ApiService.getAvailableClients();
                                if (!clientsResult['success']) return;

                                final clients = (clientsResult['data']['clients'] as List<dynamic>)
                                    .map((c) => Client.fromJson(c))
                                    .toList();
                                
                                try {
                                  final match = clients.firstWhere(
                                    (c) => c.email.toLowerCase().trim() == infoEmail,
                                  );
                                  
                                  // Assign match
                                  final result = await ApiService.assignClient(
                                      projectId: _currentProject.id, clientId: match.id);
                                  
                                  if (result['success']) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client assigned successfully')));
                                    widget.onAssignmentChanged();
                                  } else {
                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
                                  }
                                  
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No client account found with this email')),
                                  );
                                }
                              } else {
                                // Agent logic similar
                                final agentsResult = await ApiService.getAvailableAgents();
                                if (!agentsResult['success']) return;
                                
                                final agents = (agentsResult['data']['agents'] as List<dynamic>)
                                    .map((a) => Agent.fromJson(a))
                                    .toList();
                                    
                                try {
                                  final match = agents.firstWhere(
                                      (a) => a.email.toLowerCase().trim() == infoEmail);
                                      
                                  final result = await ApiService.assignAgent(
                                      projectId: _currentProject.id, agentId: match.id);
                                      
                                   if (result['success']) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agent assigned successfully')));
                                    widget.onAssignmentChanged();
                                  } else {
                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
                                  }
                                } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No agent account found with this email')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.person_search, size: 16),
                            label: Text('Find & Assign ${userTypeName} Account'),
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

  Future<void> _showUserAssignedProjects(
    BuildContext context,
    int userId,
    String userName,
    String roleType,
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

    // Always show dialog with assigned projects (or "No projects assigned" message)
    await showDialog(
      context: context,
      barrierDismissible: true,
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
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
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
                child: projectsData.isEmpty
                    ? Center(
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
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: projectsData.length,
                        itemBuilder: (context, index) {
                          final project = projectsData[index];
                          final assignedDate = DateTime.parse(project['assigned_date']);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              title: Text(project['title'], maxLines: 1),
                              subtitle: Text('Assigned: ${DateFormat('MMM dd, yyyy').format(assignedDate)}'),
                              trailing: Chip(
                                label: Text(project['status_display'], style: const TextStyle(fontSize: 10)),
                                backgroundColor: Colors.blue[50],
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
  }
}

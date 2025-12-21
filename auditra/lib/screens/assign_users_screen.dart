import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/project_model.dart';

class AssignUsersScreen extends StatefulWidget {
  final Project project;
  final Function()? onUsersAssigned;
  
  const AssignUsersScreen({
    super.key,
    required this.project,
    this.onUsersAssigned,
  });

  @override
  State<AssignUsersScreen> createState() => _AssignUsersScreenState();
}

class _AssignUsersScreenState extends State<AssignUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Project? currentProject;

  @override
  void initState() {
    super.initState();
    currentProject = widget.project;
    final hasAgentInfo = currentProject!.agentInfo != null || currentProject!.hasAgent;
    final tabCount = hasAgentInfo ? 5 : 4;
    _tabController = TabController(length: tabCount, vsync: this);
    _refreshProject();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshProject() async {
    final projectResult = await ApiService.getProject(widget.project.id);
    if (projectResult['success'] && projectResult['data'] != null) {
      setState(() {
        currentProject = Project.fromJson(projectResult['data']);
      });
    }
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

  Future<void> _showUserAssignedProjects(
    BuildContext context,
    int userId,
    String userName,
    String roleType,
    Future<Map<String, dynamic>> Function(int) assignUser,
    String userTypeName,
  ) async {
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

    await showDialog<Map<String, dynamic>>(
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
                              fontSize: 18,
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
                                    fontSize: 14,
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
                                            fontSize: 14,
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
  }

  Widget _buildUserTypeTab<T>(
    String userType,
    MaterialColor color,
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
                final fullName = _getFullName(user);
                final username = _getUsername(user);
                final userId = _getUserId(user);
                final assignedProjectsCount = _getAssignedProjectsCount(user);
                final initials = (fullName.isNotEmpty
                        ? fullName.trim().split(' ').map((p) => p[0]).take(2).join()
                        : username.substring(0, 1))
                    .toUpperCase();
                
                final isUserAssigned = userType == 'field_officer'
                    ? currentProject!.assignedFieldOfficerId == userId
                    : userType == 'accessor'
                        ? currentProject!.assignedAccessorId == userId
                        : userType == 'senior_valuer'
                            ? currentProject!.assignedSeniorValuerId == userId
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
                                fontSize: 16,
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
                                    fontSize: 14,
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
                                                  await _showUserAssignedProjects(
                                                    context,
                                                    userId,
                                                    fullName,
                                                    userType,
                                                    assignUser,
                                                    userTypeName,
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
                                                      'Assign $userTypeName "$fullName" to project "${currentProject!.title}"?',
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
                                                          backgroundColor: Colors.green,
                                                        ),
                                                      );
                                                      await _refreshProject();
                                                      if (widget.onUsersAssigned != null) {
                                                        widget.onUsersAssigned!();
                                                      }
                                                      setState(() {});
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            result['message'] ??
                                                                'Failed to assign $userTypeName',
                                                          ),
                                                          backgroundColor: Colors.red,
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
    String userType,
    MaterialColor color,
    IconData icon,
    Future<Map<String, dynamic>> Function(int) assignUser,
    String userTypeName,
  ) {
    final info = userType == 'client' ? currentProject!.clientInfo : currentProject!.agentInfo;
    final isAssigned = userType == 'client'
        ? currentProject!.assignedClientId != null
        : currentProject!.assignedAgentId != null;

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
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
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
                          final infoEmail = email.toLowerCase().trim();
                          
                          if (userType == 'client') {
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

                            final matchingClient = clients.firstWhere(
                              (c) => c.email.toLowerCase().trim() == infoEmail,
                              orElse: () => clients.first,
                            );

                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text('Confirm Assignment'),
                                content: Text(
                                  'Assign $userTypeName "${matchingClient.fullName}" to project "${currentProject!.title}"?',
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
                                    SnackBar(
                                      content: Text(
                                        '$userTypeName assigned successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  await _refreshProject();
                                  if (widget.onUsersAssigned != null) {
                                    widget.onUsersAssigned!();
                                  }
                                  setState(() {});
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result['message'] ?? 'Failed to assign $userTypeName',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          } else if (userType == 'agent') {
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

                            final matchingAgent = agents.firstWhere(
                              (a) => a.email.toLowerCase().trim() == infoEmail,
                              orElse: () => agents.first,
                            );

                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text('Confirm Assignment'),
                                content: Text(
                                  'Assign $userTypeName "${matchingAgent.fullName}" to project "${currentProject!.title}"?',
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
                                    SnackBar(
                                      content: Text(
                                        '$userTypeName assigned successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  await _refreshProject();
                                  if (widget.onUsersAssigned != null) {
                                    widget.onUsersAssigned!();
                                  }
                                  setState(() {});
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result['message'] ?? 'Failed to assign $userTypeName',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.person_add, size: 18),
                        label: Text('Assign $userTypeName'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    final hasAgentInfo = currentProject!.agentInfo != null || currentProject!.hasAgent;
    
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[500]!, Colors.blue[500]!.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[400]!,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assign Users',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentProject?.title ?? widget.project.title,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
                _buildUserTypeTab(
                  'field_officer',
                  Colors.lightBlue,
                  Icons.person_outline,
                  () => ApiService.getAvailableFieldOfficers(),
                  (data) => (data['field_officers'] as List<dynamic>)
                      .map((o) => FieldOfficer.fromJson(o))
                      .toList(),
                  (id) => currentProject!.assignedFieldOfficerId == id,
                  (id) => ApiService.assignFieldOfficer(projectId: currentProject!.id, fieldOfficerId: id),
                  'Field Officer',
                  showProjectCount: true,
                ),
                _buildClientAgentTab(
                  'client',
                  Colors.cyan,
                  Icons.business_outlined,
                  (id) => ApiService.assignClient(projectId: currentProject!.id, clientId: id),
                  'Client',
                ),
                if (hasAgentInfo)
                  _buildClientAgentTab(
                    'agent',
                    Colors.orange,
                    Icons.badge_outlined,
                    (id) => ApiService.assignAgent(projectId: currentProject!.id, agentId: id),
                    'Agent',
                  ),
                _buildUserTypeTab(
                  'accessor',
                  Colors.purple,
                  Icons.assessment_outlined,
                  () => ApiService.getAvailableAccessors(),
                  (data) => (data['accessors'] as List<dynamic>)
                      .map((a) => Accessor.fromJson(a))
                      .toList(),
                  (id) => currentProject!.assignedAccessorId == id,
                  (id) => ApiService.assignAccessor(projectId: currentProject!.id, accessorId: id),
                  'Accessor',
                  showProjectCount: true,
                ),
                _buildUserTypeTab(
                  'senior_valuer',
                  Colors.teal,
                  Icons.verified_user_outlined,
                  () => ApiService.getAvailableSeniorValuers(),
                  (data) => (data['senior_valuers'] as List<dynamic>)
                      .map((v) => SeniorValuer.fromJson(v))
                      .toList(),
                  (id) => currentProject!.assignedSeniorValuerId == id,
                  (id) => ApiService.assignSeniorValuer(projectId: currentProject!.id, seniorValuerId: id),
                  'Senior Valuer',
                  showProjectCount: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


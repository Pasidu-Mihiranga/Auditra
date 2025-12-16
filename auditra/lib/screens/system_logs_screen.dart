import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/dark_mode_toggle.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _filterAction = 'all';
  String _filterSeverity = 'all';
  String _searchQuery = '';

  final List<String> _actionTypes = [
    'all',
    'login',
    'logout',
    'register',
    'role_assigned',
    'role_changed',
    'attendance_marked',
    'leave_requested',
    'leave_approved',
    'leave_rejected',
    'payment_generated',
    'payment_uploaded',
    'project_created',
    'project_updated',
    'valuation_created',
    'biometric_enabled',
    'biometric_disabled',
    'user_updated',
    'user_deleted',
    'other',
  ];

  final List<String> _severityTypes = [
    'all',
    'info',
    'warning',
    'error',
    'success',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    final result = await ApiService.getSystemLogs(
      action: _filterAction != 'all' ? _filterAction : null,
      severity: _filterSeverity != 'all' ? _filterSeverity : null,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _logs = List<Map<String, dynamic>>.from(result['data']);
        } else {
          _logs = [];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to load system logs'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'success':
        return Colors.green;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'register':
        return Icons.person_add;
      case 'role_assigned':
      case 'role_changed':
        return Icons.badge;
      case 'attendance_marked':
        return Icons.access_time;
      case 'leave_requested':
      case 'leave_approved':
      case 'leave_rejected':
        return Icons.event_busy;
      case 'payment_generated':
      case 'payment_uploaded':
        return Icons.payment;
      case 'project_created':
      case 'project_updated':
        return Icons.folder;
      case 'valuation_created':
        return Icons.assessment;
      case 'biometric_enabled':
      case 'biometric_disabled':
        return Icons.fingerprint;
      case 'user_updated':
        return Icons.edit;
      case 'user_deleted':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_searchQuery.isEmpty) {
      return _logs;
    }
    final query = _searchQuery.toLowerCase();
    return _logs.where((log) {
      final message = (log['message'] ?? '').toString().toLowerCase();
      final user = (log['user_username'] ?? '').toString().toLowerCase();
      final action = (log['action_display'] ?? '').toString().toLowerCase();
      return message.contains(query) || 
             user.contains(query) || 
             action.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Logs'),
        centerTitle: true,
        actions: [
          const DarkModeToggle(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Filter chips
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterAction,
                        decoration: InputDecoration(
                          labelText: 'Action',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.white,
                        ),
                        items: _actionTypes.map((action) {
                          return DropdownMenuItem(
                            value: action,
                            child: Text(
                              action == 'all' 
                                  ? 'All Actions' 
                                  : action.replaceAll('_', ' ').toUpperCase(),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _filterAction = value;
                            });
                            _loadLogs();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterSeverity,
                        decoration: InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.white,
                        ),
                        items: _severityTypes.map((severity) {
                          return DropdownMenuItem(
                            value: severity,
                            child: Text(
                              severity == 'all' 
                                  ? 'All Severities' 
                                  : severity.toUpperCase(),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _filterSeverity = value;
                            });
                            _loadLogs();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Logs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No logs found matching your search'
                                  : 'No system logs available',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];
                          final severity = log['severity'] as String? ?? 'info';
                          final action = log['action'] as String? ?? 'other';
                          final createdAt = log['created_at'] as String?;
                          final dateTime = createdAt != null
                              ? DateTime.tryParse(createdAt)
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _getSeverityColor(severity).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _getSeverityColor(severity).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getActionIcon(action),
                                          color: _getSeverityColor(severity),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              log['action_display'] as String? ?? 'Unknown Action',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              log['message'] as String? ?? 'No message',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getSeverityColor(severity),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          severity.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(color: Colors.grey[300]),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        log['user_full_name'] as String? ?? 
                                        log['user_username'] as String? ?? 
                                        'System',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const Spacer(),
                                      if (dateTime != null) ...[
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('MMM dd, yyyy HH:mm:ss').format(dateTime),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (log['ip_address'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.computer,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'IP: ${log['ip_address']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


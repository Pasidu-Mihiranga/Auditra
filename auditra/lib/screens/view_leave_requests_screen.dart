import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ViewLeaveRequestsScreen extends StatefulWidget {
  final bool showAppBar;
  
  const ViewLeaveRequestsScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<ViewLeaveRequestsScreen> createState() => _ViewLeaveRequestsScreenState();
}

class _ViewLeaveRequestsScreenState extends State<ViewLeaveRequestsScreen> {
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, pending, approved, rejected
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadLeaveRequests();
  }

  Future<void> _loadUserRole() async {
    final result = await ApiService.getMyRole();
    if (result['success'] && mounted) {
      setState(() {
        _currentUserRole = result['data']['role'];
      });
    }
  }

  Future<void> _loadLeaveRequests() async {
    setState(() => _isLoading = true);
    
    final result = await ApiService.getAllLeaveRequests();
    
    if (!mounted) return;
    
    setState(() => _isLoading = false);
    
    if (result['success']) {
      final data = result['data'] as List<dynamic>;
      setState(() {
        _leaveRequests = data.map((item) {
          return {
            'id': item['id'],
            'employee_name': item['employee_name'] ?? 'Unknown',
            'employee_id': item['employee_id'] ?? '',
            'employee_role': item['employee_role'] ?? '',
            'leave_type': item['leave_type_display'] ?? item['leave_type'] ?? 'Unknown',
            'start_date': DateTime.parse(item['start_date']),
            'end_date': DateTime.parse(item['end_date']),
            'days': item['days'] ?? 0,
            'reason': item['reason'] ?? '',
            'status': item['status'] ?? 'pending',
            'submitted_at': DateTime.parse(item['submitted_at']),
            'reviewed_at': item['reviewed_at'] != null ? DateTime.parse(item['reviewed_at']) : null,
          };
        }).toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to load leave requests'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_filterStatus == 'all') return _leaveRequests;
    return _leaveRequests.where((req) => req['status'] == _filterStatus).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Future<void> _updateLeaveStatus(int requestId, String newStatus) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                newStatus == 'approved' ? Icons.check_circle : Icons.cancel,
                color: newStatus == 'approved' ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  newStatus == 'approved' ? 'Approve Leave Request' : 'Reject Leave Request',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            newStatus == 'approved'
                ? 'Are you sure you want to approve this leave request?'
                : 'Are you sure you want to reject this leave request?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(newStatus == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );
    
    if (confirmed != true || !mounted) return;
    
    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final result = await ApiService.updateLeaveRequestStatus(
      requestId: requestId,
      status: newStatus,
    );
    
    // Close loading indicator
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    if (!mounted) return;
    
    if (result['success']) {
      // Reload the list to get updated data
      await _loadLeaveRequests();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus == 'approved' ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result['message'] ?? 'Leave request ${_getStatusLabel(newStatus).toLowerCase()} successfully',
                  ),
                ),
              ],
            ),
            backgroundColor: _getStatusColor(newStatus),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result['message'] ?? 'Failed to update leave request'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('All', 'all'),
                    _buildFilterChip('Pending', 'pending'),
                    _buildFilterChip('Approved', 'approved'),
                    _buildFilterChip('Rejected', 'rejected'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Leave requests list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredRequests.isEmpty
                  ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _currentUserRole == 'admin'
                                  ? 'No HR staff leave requests found'
                                  : 'No leave requests found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            if (_currentUserRole == 'admin') ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                child: Text(
                                  'Only leave requests from HR staff are shown here',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                  : RefreshIndicator(
                      onRefresh: _loadLeaveRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRequests.length,
                        itemBuilder: (context, index) {
                          final request = _filteredRequests[index];
                          return _buildLeaveRequestCard(request);
                        },
                      ),
                    ),
        ),
      ],
    );
    
    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_currentUserRole == 'admin' 
            ? 'HR Staff Leave Requests' 
            : 'View Leave Requests'),
          centerTitle: true,
        ),
        body: body,
      );
    }
    
    return body;
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterStatus = value);
        }
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[900],
    );
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String;
    final statusColor = _getStatusColor(status);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            Icons.person,
            color: statusColor,
          ),
        ),
        title: Text(
          request['employee_name'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${request['leave_type']} • ${request['days']} day(s)'),
            if (_currentUserRole == 'admin' && request['employee_role'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'HR Staff',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Employee ID', request['employee_id'] as String),
                if (_currentUserRole == 'admin' && request['employee_role'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('Role', 'HR Staff'),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Date Range',
                  '${DateFormat('MMM dd, yyyy').format(request['start_date'] as DateTime)} - ${DateFormat('MMM dd, yyyy').format(request['end_date'] as DateTime)}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Reason', request['reason'] as String),
                const SizedBox(height: 16),
                if (status == 'pending')
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateLeaveStatus(request['id'] as int, 'approved'),
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text('Approve Leave Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateLeaveStatus(request['id'] as int, 'rejected'),
                          icon: const Icon(Icons.cancel, size: 20),
                          label: const Text('Reject Leave Request'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}


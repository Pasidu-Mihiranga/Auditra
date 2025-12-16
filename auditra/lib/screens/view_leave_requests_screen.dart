import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/dark_mode_toggle.dart';

class ViewLeaveRequestsScreen extends StatefulWidget {
  const ViewLeaveRequestsScreen({super.key});

  @override
  State<ViewLeaveRequestsScreen> createState() => _ViewLeaveRequestsScreenState();
}

class _ViewLeaveRequestsScreenState extends State<ViewLeaveRequestsScreen> {
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, pending, approved, rejected

  @override
  void initState() {
    super.initState();
    _loadLeaveRequests();
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
            'leave_type': item['leave_type_display'] ?? item['leave_type'] ?? 'Unknown',
            'start_date': DateTime.parse(item['start_date']),
            'end_date': DateTime.parse(item['end_date']),
            'days': item['days'] ?? 0,
            'reason': item['reason'] ?? '',
            'status': item['status'] ?? 'pending',
            'submitted_at': DateTime.parse(item['submitted_at']),
            'reviewed_at': item['reviewed_at'] != null ? DateTime.parse(item['reviewed_at']) : null,
            'notes': item['notes'],
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
    final result = await ApiService.updateLeaveRequestStatus(
      requestId: requestId,
      status: newStatus,
    );
    
    if (!mounted) return;
    
    if (result['success']) {
      // Reload the list to get updated data
      await _loadLeaveRequests();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Leave request ${_getStatusLabel(newStatus).toLowerCase()} successfully'),
          backgroundColor: _getStatusColor(newStatus),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to update leave request'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Leave Requests'),
        centerTitle: true,
        actions: [
          const DarkModeToggle(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaveRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
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
                              'No leave requests found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
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
      ),
    );
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
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Date Range',
                  '${DateFormat('MMM dd, yyyy').format(request['start_date'] as DateTime)} - ${DateFormat('MMM dd, yyyy').format(request['end_date'] as DateTime)}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Reason', request['reason'] as String),
                const SizedBox(height: 16),
                if (status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateLeaveStatus(request['id'] as int, 'approved'),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateLeaveStatus(request['id'] as int, 'rejected'),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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


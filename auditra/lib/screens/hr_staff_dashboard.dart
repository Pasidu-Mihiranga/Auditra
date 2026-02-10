import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'generic_dashboard.dart';
import 'view_leave_requests_screen.dart';
import 'payment_slips_screen.dart';

class HRStaffDashboard extends StatefulWidget {
  const HRStaffDashboard({super.key});

  @override
  State<HRStaffDashboard> createState() => _HRStaffDashboardState();
}

class _HRStaffDashboardState extends State<HRStaffDashboard> with TickerProviderStateMixin {
  String? _roleDisplay;
  bool _isLoading = true;
  TabController? _mainTabController;
  TabController? _viewSubTabController;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _viewSubTabController = TabController(length: 3, vsync: this); // Added Payments subtab
    _loadUserInfo();
  }

  @override
  void dispose() {
    _mainTabController?.dispose();
    _viewSubTabController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final roleResult = await ApiService.getMyRole();
    if (mounted) {
      setState(() {
        if (roleResult['success']) {
          _roleDisplay = roleResult['data']['role_display'];
        }
        _isLoading = false;
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
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Confirm logout',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Are you sure you want to logout?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
                        ),
                        child: const Text('Logout', style: TextStyle(fontSize: 16)),
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _mainTabController == null || _viewSubTabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HR Staff Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (_roleDisplay != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _roleDisplay!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
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
          controller: _mainTabController!,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profile'),
            Tab(icon: Icon(Icons.manage_accounts), text: 'HR Management'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _mainTabController!,
        children: [
          // Profile tab - Use GenericDashboard
          GenericDashboard(
            role: 'hr_staff',
            roleDisplay: _roleDisplay ?? 'HR Staff',
            isEmbedded: true,
          ),
          // View tab with subtabs
          _buildViewTab(),
        ],
      ),
    );
  }

  /// Build Management tab with subtabs (View Attendance, View Leave, and Payments)
  Widget _buildViewTab() {
    if (_viewSubTabController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        // Subtabs for Management
        TabBar(
          controller: _viewSubTabController!,
          tabs: [
            Tab(
              icon: Icon(Icons.calendar_today, color: Colors.blue[600]),
              text: 'View Attendance',
            ),
            Tab(
              icon: Icon(Icons.event_note, color: Colors.orange[600]),
              text: 'View Leave',
            ),
            Tab(
              icon: Icon(Icons.payment, color: Colors.green[600]),
              text: 'Payments',
            ),
          ],
        ),
        // Subtab content
        Expanded(
          child: TabBarView(
            controller: _viewSubTabController!,
            children: [
              _buildViewAttendanceSubtab(),
              _buildViewLeaveSubtab(),
              _buildViewPaymentsSubtab(),
            ],
          ),
        ),
      ],
    );
  }

  /// View Attendance subtab - Shows weekly attendance summary
  Widget _buildViewAttendanceSubtab() {
    return GenericDashboard(
      role: 'hr_staff',
      roleDisplay: _roleDisplay ?? 'HR Staff',
      isEmbedded: true,
      showOnlyWeeklyAttendance: true,
    );
  }

  /// View Leave subtab - Shows leave requests with accept/reject functionality
  Widget _buildViewLeaveSubtab() {
    return const ViewLeaveRequestsScreen(
      showAppBar: false, // No AppBar when embedded as subtab
    );
  }

  /// View Payments subtab - Shows payment slips with create, update, upload, and view functionality
  Widget _buildViewPaymentsSubtab() {
    return PaymentSlipsScreen(
      role: 'hr_staff',
      showAppBar: false, // No AppBar when embedded as subtab
    );
  }
}


import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../models/payment_slip_model.dart';
import 'login_screen.dart';
import 'payment_slips_screen.dart';
import 'view_leave_requests_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<UserModel> _users = [];
  List<RoleOption> _roles = [];
  bool _isLoading = true;
  String? _username;
  String? _roleDisplay;
  
  // Leave summary state
  List<Map<String, dynamic>> _monthlyLeaveSummary = [];
  bool _isLoadingLeaveSummary = false;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  // Attendance summary weekly state
  List<Map<String, dynamic>> _weeklyAttendanceSummary = [];
  bool _isLoadingAttendanceSummary = false;
  DateTime _selectedWeekStart = _getWeekStart(DateTime.now());
  String _attendanceSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadMonthlyLeaveSummary();
    _loadWeeklyAttendanceSummary();
  }
  
  // Helper function to get the start of the week (Monday)
  static DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final username = await ApiService.getUsername();
    final roleResult = await ApiService.getMyRole();
    final usersResult = await ApiService.getAllUsers();
    final rolesResult = await ApiService.getRoles();

    if (!mounted) return;

    setState(() {
      _username = username;
      if (roleResult['success']) {
        _roleDisplay = roleResult['data']['role_display'];
      }
      if (usersResult['success']) {
        _users = (usersResult['data'] as List)
            .map((user) => UserModel.fromJson(user))
            .toList();
      }
      if (rolesResult['success']) {
        _roles = (rolesResult['data']['roles'] as List)
            .map((role) => RoleOption.fromJson(role))
            .toList();
      }
      _isLoading = false;
    });
  }

  Future<void> _loadMonthlyLeaveSummary() async {
    setState(() => _isLoadingLeaveSummary = true);
    
    final result = await ApiService.getMonthlyLeaveSummary(
      month: _selectedMonth,
      year: _selectedYear,
    );
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingLeaveSummary = false;
      if (result['success']) {
        _monthlyLeaveSummary = (result['data'] as List<dynamic>)
            .map((item) => item as Map<String, dynamic>)
            .toList();
      }
    });
  }

  Future<void> _loadWeeklyAttendanceSummary() async {
    setState(() => _isLoadingAttendanceSummary = true);
    
    final result = await ApiService.getWeeklyAttendanceSummary(
      weekStart: _selectedWeekStart,
    );
    
    if (!mounted) return;
    
    setState(() {
      _isLoadingAttendanceSummary = false;
      if (result['success']) {
        _weeklyAttendanceSummary = (result['data'] as List<dynamic>)
            .map((item) => item as Map<String, dynamic>)
            .toList();
      }
    });
  }

  Future<void> _selectWeek() async {
    final now = DateTime.now();
    final initialDate = _selectedWeekStart;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select Week Start (Monday)',
    );
    
    if (picked != null) {
      setState(() {
        _selectedWeekStart = _getWeekStart(picked);
      });
      await _loadWeeklyAttendanceSummary();
    }
  }

  Future<void> _selectMonthYear() async {
    final now = DateTime.now();
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    int? selectedMonth = _selectedMonth;
    int? selectedYear = _selectedYear;
    
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Month & Year'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: const InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(12, (index) {
                  final month = index + 1;
                  return DropdownMenuItem(
                    value: month,
                    child: Text(monthNames[index]),
                  );
                }),
                onChanged: (value) {
                  setDialogState(() => selectedMonth = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(5, (index) {
                  final year = now.year - 2 + index;
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }),
                onChanged: (value) {
                  setDialogState(() => selectedYear = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'month': selectedMonth!,
                'year': selectedYear!,
              }),
              child: const Text('View'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedMonth = result['month']!;
        _selectedYear = result['year']!;
      });
      await _loadMonthlyLeaveSummary();
    }
  }

  Future<void> _assignRole(UserModel user) async {
    String? selectedRole = user.role != 'unassigned' ? user.role : null;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign Role to ${user.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Role: ${user.roleDisplay}'),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Select New Role',
                  border: OutlineInputBorder(),
                ),
                items: _roles
                    .where((role) => role.value != 'admin') // Exclude admin role
                    .map((role) {
                  return DropdownMenuItem(
                    value: role.value,
                    child: Text(role.label),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedRole = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRole == null
                  ? null
                  : () => Navigator.pop(context, selectedRole),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      // Show loading indicator
      setState(() => _isLoading = true);
      
      final assignResult = await ApiService.assignRole(
        userId: user.id,
        role: result,
      );

      if (!mounted) return;

      if (assignResult['success']) {
        // Reload users to reflect changes
        await _loadData();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Role assigned successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(assignResult['message']),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _createPaymentSlips() async {
    // Automatically generate payment slips for current month/year for all employees
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Payment Slips'),
        content: Text(
          'This will automatically generate payment slips for all employees (Coordinator, Field Officer, Senior Valuer, Assessor, MD/GM, HR Staff, and General Employee) for ${_getMonthName(currentMonth)} $currentYear.\n\nExisting payment slips for this month will be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final generateResult = await ApiService.generatePaymentSlips(
      month: currentMonth,
      year: currentYear,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (generateResult['success']) {
      final data = generateResult['data'];
      final generated = data['generated_count'] ?? 0;
      final updated = data['updated_count'] ?? 0;
      final total = data['total_count'] ?? 0;
      
      String message;
      if (total > 0) {
        if (generated > 0 && updated > 0) {
          message = 'Payment slips created successfully!\n$generated created, $updated updated\n(Total: $total employees)';
        } else if (updated > 0) {
          message = 'Payment slips updated successfully for $updated employees';
        } else {
          message = 'Payment slips created successfully for $generated employees';
        }
      } else {
        message = data['message'] ?? 'No payment slips generated. All eligible employees may already have payment slips for this month/year.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: total > 0 ? Colors.green : Colors.orange,
          duration: Duration(seconds: total > 0 ? 4 : 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(generateResult['message'] ?? 'Failed to create payment slips'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }

  Future<void> _uploadPaymentSlips() async {
    // Upload/publish payment slips for employees to view
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Payment Slips'),
        content: Text(
          'This will make payment slips visible to all employees for ${_getMonthName(currentMonth)} $currentYear.\n\nEmployees will be able to view their own payment slips after this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final uploadResult = await ApiService.uploadPaymentSlips(
      month: currentMonth,
      year: currentYear,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (uploadResult['success']) {
      final data = uploadResult['data'];
      final uploaded = data['uploaded_count'] ?? 0;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment slips uploaded successfully for $uploaded employees!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadResult['message'] ?? 'Failed to upload payment slips'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _uploadAllPayments() async {
    try {
      // Get current month and year
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      // Show dialog to select month/year
      final monthYearResult = await showDialog<Map<String, int>>(
        context: context,
        builder: (context) {
          int selectedMonth = currentMonth;
          int selectedYear = currentYear;
          
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('Upload All Overtime Hours'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select month and year for overtime hours upload:'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedMonth,
                          isExpanded: true,
                          items: List.generate(12, (index) {
                            final month = index + 1;
                            return DropdownMenuItem(
                              value: month,
                              child: Text(_getMonthName(month)),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedMonth = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedYear,
                          isExpanded: true,
                          items: List.generate(5, (index) {
                            final year = currentYear - 2 + index;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedYear = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {
                    'month': selectedMonth,
                    'year': selectedYear,
                  }),
                  child: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (monthYearResult == null) return;

      final month = monthYearResult['month']!;
      final year = monthYearResult['year']!;

      // Show loading to fetch payment slips
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch all payment slips for the selected month/year
      final slipsResult = await ApiService.getAllPaymentSlips(month: month, year: year);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (!slipsResult['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(slipsResult['message'] ?? 'Failed to load payment slips'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final slipsData = slipsResult['data'] as List<dynamic>;
      if (slipsData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No payment slips found for the selected month/year'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show dialog to input overtime hours for each payment slip
      final overtimeData = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (context) {
          final controllers = <int, TextEditingController>{};
          final slips = slipsData.map((json) => PaymentSlip.fromJson(json)).toList();
          
          for (var slip in slips) {
            controllers[slip.id] = TextEditingController(
              text: slip.overtimeHours.toStringAsFixed(2),
            );
          }

          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text('Upload Overtime Hours - ${_getMonthName(month)} $year'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enter overtime hours for each employee:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...slips.map((slip) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: controllers[slip.id],
                          decoration: InputDecoration(
                            labelText: '${slip.userFullName} (${slip.roleDisplay})',
                            border: const OutlineInputBorder(),
                            hintText: 'Overtime hours',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (var controller in controllers.values) {
                      controller.dispose();
                    }
                    Navigator.pop(context, null);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final data = <Map<String, dynamic>>[];
                    for (var slip in slips) {
                      final controller = controllers[slip.id]!;
                      final overtimeHours = double.tryParse(controller.text.replaceAll(',', ''));
                      if (overtimeHours != null && overtimeHours >= 0) {
                        data.add({
                          'slip_id': slip.id,
                          'overtime_hours': overtimeHours,
                        });
                      }
                    }
                    
                    for (var controller in controllers.values) {
                      controller.dispose();
                    }
                    
                    Navigator.pop(context, data);
                  },
                  child: const Text('Upload All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (overtimeData == null || overtimeData.isEmpty) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Upload all overtime hours
      final uploadResult = await ApiService.uploadAllOvertimeHours(
        month: month,
        year: year,
        overtimeData: overtimeData,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (uploadResult['success']) {
        final updatedCount = uploadResult['updated_count'] ?? 0;
        final errors = uploadResult['errors'] as List<dynamic>?;
        
        String message = 'Successfully uploaded overtime hours for $updatedCount payment slip(s)!';
        if (errors != null && errors.isNotEmpty) {
          message += '\n\nErrors: ${errors.length}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadResult['message'] ?? 'Failed to upload overtime hours'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading overtime hours: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  Future<void> _generatePaymentSlips() async {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          int selectedMonth = currentMonth;
          int selectedYear = currentYear;

          return AlertDialog(
            title: const Text('Generate Payment Slips'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select month and year for payment slip generation:'),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  value: selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    final monthNames = [
                      'January', 'February', 'March', 'April', 'May', 'June',
                      'July', 'August', 'September', 'October', 'November', 'December'
                    ];
                    return DropdownMenuItem(
                      value: month,
                      child: Text(monthNames[index]),
                    );
                  }),
                  onChanged: (value) {
                    setDialogState(() => selectedMonth = value!);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(5, (index) {
                    final year = currentYear - 2 + index;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }),
                  onChanged: (value) {
                    setDialogState(() => selectedYear = value!);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, {
                  'month': selectedMonth,
                  'year': selectedYear,
                }),
                child: const Text('Generate'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final generateResult = await ApiService.generatePaymentSlips(
        month: result['month'],
        year: result['year'],
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (generateResult['success']) {
        final data = generateResult['data'];
        final generated = data['generated_count'] ?? 0;
        final updated = data['updated_count'] ?? 0;
        final total = data['total_count'] ?? 0;
        
        String message;
        if (total > 0) {
          if (generated > 0 && updated > 0) {
            message = 'Payment slips: $generated created, $updated updated (Total: $total users)';
          } else if (updated > 0) {
            message = 'Payment slips updated successfully for $updated users';
          } else {
            message = 'Payment slips generated successfully for $generated users';
          }
        } else {
          message = data['message'] ?? 'No payment slips generated. All eligible users may already have payment slips for this month/year.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: total > 0 ? Colors.green : Colors.orange,
            duration: Duration(seconds: total > 0 ? 3 : 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(generateResult['message'] ?? 'Failed to generate payment slips'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
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
              'Admin Dashboard',
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
                              size: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.blue[700],
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
            icon: const Icon(Icons.edit_calendar, color: Colors.purple),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ViewLeaveRequestsScreen(),
                ),
              );
            },
            tooltip: 'View Leave Requests',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.admin_panel_settings,
                                size: 30, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, $_username!',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Administrator',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Statistics
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Users',
                          _users.length.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Unassigned',
                          _users
                              .where((u) => u.role == 'unassigned')
                              .length
                              .toString(),
                          Icons.person_add_disabled,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Payment Slip Generation
                  Card(
                    elevation: 4,
                    color: Colors.green[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.green[300]!, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payment, color: Colors.green[700], size: 28),
                              const SizedBox(width: 12),
                              const Text(
                                'Payment Management',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Generate payment slips for all employees at the end of each month.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _createPaymentSlips,
                                  icon: const Icon(Icons.add_circle, size: 20),
                                  label: const Text(
                                    'Create Payment Slips',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _uploadPaymentSlips,
                                  icon: const Icon(Icons.upload_file, size: 18),
                                  label: const Text(
                                    'Upload Payment Slips',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    minimumSize: const Size(0, 40),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const PaymentSlipsScreen(role: 'admin'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.receipt_long, size: 20),
                                  label: const Text(
                                    'View Payment Slips',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
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
                  ),
                  const SizedBox(height: 24),

                  // Monthly Leave Summary
                  _buildMonthlyLeaveSummarySection(),
                  const SizedBox(height: 24),

                  // Weekly Attendance Summary
                  _buildWeeklyAttendanceSummarySection(),
                  const SizedBox(height: 24),

                  // User List
                  const Text(
                    'User Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_users.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No users found'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: user.isUnassigned
                                  ? Colors.grey
                                  : user.isAdmin
                                      ? Colors.blue
                                      : Colors.green,
                              child: Text(
                                user.username[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              user.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('@${user.username}'),
                                Text(user.email),
                                Chip(
                                  label: Text(user.roleDisplay),
                                  backgroundColor: user.isUnassigned
                                      ? Colors.grey[200]
                                      : user.isAdmin
                                          ? Colors.blue[100]
                                          : Colors.green[100],
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _assignRole(user),
                              icon: const Icon(Icons.person_add, size: 18),
                              label: const Text('Assign Role'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyLeaveSummarySection() {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_note, color: Colors.purple[700], size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Monthly Leave Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectMonthYear,
                  tooltip: 'Select Month & Year',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadMonthlyLeaveSummary,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${monthNames[_selectedMonth - 1]} $_selectedYear',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingLeaveSummary)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_monthlyLeaveSummary.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No leave records for this month',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Emp ID',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[900],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Employee Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[900],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Leave Taken',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Employee rows
                  ..._monthlyLeaveSummary.map((employee) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              employee['employee_id'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              employee['employee_name'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${employee['leave_taken'] as int} day(s)',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyAttendanceSummarySection() {
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    final weekRange = '${_selectedWeekStart.day}/${_selectedWeekStart.month}/${_selectedWeekStart.year} - ${weekEnd.day}/${weekEnd.month}/${weekEnd.year}';
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.teal[700], size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Attendance Summary Weekly',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _selectWeek,
                  tooltip: 'Select Week',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadWeeklyAttendanceSummary,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Week: $weekRange',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by Employee ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _attendanceSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _attendanceSearchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _attendanceSearchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_isLoadingAttendanceSummary)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_weeklyAttendanceSummary.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No attendance records for this week',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Builder(
                builder: (context) {
                  // Filter employees based on search query
                  final filteredEmployees = _attendanceSearchQuery.isEmpty
                      ? _weeklyAttendanceSummary
                      : _weeklyAttendanceSummary.where((employee) {
                          final employeeNumber = (employee['employee_number'] as String? ?? '').toString();
                          return employeeNumber.toLowerCase().contains(_attendanceSearchQuery.toLowerCase());
                        }).toList();
                  
                  if (filteredEmployees.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No employees found with employee ID: $_attendanceSearchQuery',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.teal[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  'Employee Name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Employee ID',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  'Absent Days',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  'Half Days',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Attendance %',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Overtime Hours',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[900],
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Employee rows
                        ...filteredEmployees.map((employee) {
                      final attendancePercentage = (employee['attendance_percentage'] as num?)?.toDouble() ?? 0.0;
                      Color percentageColor;
                      if (attendancePercentage >= 90) {
                        percentageColor = Colors.green[700]!;
                      } else if (attendancePercentage >= 80) {
                        percentageColor = Colors.orange[700]!;
                      } else {
                        percentageColor = Colors.red[700]!;
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                employee['employee_name'] as String? ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: Text(
                                employee['employee_number'] as String? ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '${employee['absent_days'] ?? 0}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '${employee['half_days'] ?? 0}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: Text(
                                '${attendancePercentage.toStringAsFixed(1)}%',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: percentageColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: Text(
                                '${(employee['overtime_hours'] as num?)?.toStringAsFixed(1) ?? '0.0'} hrs',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}


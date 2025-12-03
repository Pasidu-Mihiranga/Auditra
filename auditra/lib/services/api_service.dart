import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your computer's IP address when testing on physical device
  // For emulator, use 10.0.2.2 (Android) or localhost (iOS)
  // For physical device, use your computer's IP address (e.g., 'http://192.168.1.100:8000/api')
  // For Chrome/web, use localhost
  static const String baseUrl = 'http://10.0.2.2:8000/api'; // Using 10.0.2.2 for Android emulator

  // Register new user
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      print('🔵 Registering user: $username');
      print('🔵 API URL: $baseUrl/auth/register/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'password2': password,
          'first_name': firstName ?? '',
          'last_name': lastName ?? '',
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your connection.');
        },
      );
      
      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      // Parse JSON response
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        print('❌ Failed to parse JSON: $e');
        return {'success': false, 'message': 'Invalid response from server'};
      }

      if (response.statusCode == 201) {
        // Save tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access'] ?? '');
        await prefs.setString('refresh_token', data['refresh'] ?? '');
        if (data['user'] != null) {
          await prefs.setString('user_id', data['user']['id'].toString());
          await prefs.setString('username', data['user']['username'] ?? '');
        }
        
        return {'success': true, 'data': data};
      } else {
        // Extract error message from response
        String errorMessage = 'Registration failed';
        
        // Handle field-specific errors
        if (data.containsKey('username')) {
          if (data['username'] is List) {
            errorMessage = 'Username: ${(data['username'] as List).first}';
          } else {
            errorMessage = 'Username: ${data['username']}';
          }
        } else if (data.containsKey('email')) {
          if (data['email'] is List) {
            errorMessage = 'Email: ${(data['email'] as List).first}';
          } else {
            errorMessage = 'Email: ${data['email']}';
          }
        } else if (data.containsKey('password')) {
          if (data['password'] is List) {
            errorMessage = 'Password: ${(data['password'] as List).first}';
          } else {
            errorMessage = 'Password: ${data['password']}';
          }
        } else if (data.containsKey('error')) {
          errorMessage = data['error'].toString();
        } else if (data.containsKey('message')) {
          errorMessage = data['message'].toString();
        } else if (data.containsKey('non_field_errors')) {
          if (data['non_field_errors'] is List) {
            errorMessage = (data['non_field_errors'] as List).first.toString();
          } else {
            errorMessage = data['non_field_errors'].toString();
          }
        } else {
          // Get first error from any field
          for (var key in data.keys) {
            if (data[key] is List && (data[key] as List).isNotEmpty) {
              errorMessage = '$key: ${(data[key] as List).first}';
              break;
            } else if (data[key] is String) {
              errorMessage = '$key: ${data[key]}';
              break;
            }
          }
        }
        
        print('❌ Registration error: $errorMessage');
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      // Handle different types of errors
      String errorMessage = 'Connection error';
      if (e.toString().contains('Failed host lookup') || e.toString().contains('Network is unreachable')) {
        errorMessage = 'Cannot connect to server. Make sure the backend is running at http://10.0.2.2:8000';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = 'Connection refused. Is the backend server running?';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        return {'success': false, 'message': 'Server returned HTML. Endpoint /api/auth/login/ may not exist or backend has an error (404/500).'};
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        return {'success': false, 'message': 'Invalid JSON response. Server may have returned an error page.'};
      }

      if (response.statusCode == 200) {
        // Save tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        await prefs.setString('refresh_token', data['refresh']);
        await prefs.setString('user_id', data['user']['id'].toString());
        await prefs.setString('username', data['user']['username']);
        
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      String errorMsg = 'Connection error';
      if (e.toString().contains('FormatException') && e.toString().contains('<!DOCTYPE')) {
        errorMsg = 'Server returned HTML error page. Check if /api/auth/login/ endpoint exists and backend is running.';
      } else if (e.toString().contains('Connection refused')) {
        errorMsg = 'Connection refused. Is the backend server running?';
      } else {
        errorMsg = 'Connection error: ${e.toString()}';
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        return {'success': false, 'message': 'Server returned HTML instead of JSON. Endpoint may not exist (404).'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        String errorMsg = 'Failed to load profile (Status: ${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMsg = errorData['message'];
          }
        } catch (_) {}
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorMsg = 'Connection error: $e';
      if (e.toString().contains('FormatException') && e.toString().contains('<!DOCTYPE')) {
        errorMsg = 'Server returned HTML error page. Check if the API endpoint exists and backend is running correctly.';
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }

  // Get username
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  // Get user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  // Get user's role information
  static Future<Map<String, dynamic>> getMyRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/my-role/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        return {'success': false, 'message': 'Server returned HTML instead of JSON. Endpoint /api/auth/my-role/ may not exist (404).'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Store role locally
        await prefs.setString('user_role', data['role'] ?? 'unassigned');
        await prefs.setString('user_role_display', data['role_display'] ?? 'Unassigned');
        return {'success': true, 'data': data};
      } else {
        String errorMsg = 'Failed to load role (Status: ${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMsg = errorData['message'];
          }
        } catch (_) {}
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorMsg = 'Connection error: $e';
      if (e.toString().contains('FormatException') && e.toString().contains('<!DOCTYPE')) {
        errorMsg = 'Server returned HTML error page. Check if /api/auth/my-role/ endpoint exists.';
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  // Get all available roles
  static Future<Map<String, dynamic>> getRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/roles/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        return {'success': false, 'message': 'Server returned HTML instead of JSON. Endpoint /api/auth/roles/ may not exist (404).'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        String errorMsg = 'Failed to load roles (Status: ${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMsg = errorData['message'];
          }
        } catch (_) {}
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorMsg = 'Connection error: $e';
      if (e.toString().contains('FormatException') && e.toString().contains('<!DOCTYPE')) {
        errorMsg = 'Server returned HTML error page. Check if /api/auth/roles/ endpoint exists.';
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  // Assign role to user (Admin only)
  static Future<Map<String, dynamic>> assignRole({
    required int userId,
    required String role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/assign-role/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'role': role,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to assign role'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get all users (Admin only)
  static Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/users/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        return {'success': false, 'message': 'Server returned HTML. Endpoint /api/auth/users/ may not exist (404).'};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load users'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ========== ATTENDANCE ENDPOINTS ==========

  // Mark attendance (check-in)
  static Future<Map<String, dynamic>> markAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/mark/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check if response is HTML (error page)
      final responseBody = response.body.trim();
      if (responseBody.isEmpty) {
        return {'success': false, 'message': 'Empty response from server. Backend may have crashed or endpoint does not exist.'};
      }
      if (responseBody.startsWith('<!DOCTYPE') || 
          responseBody.startsWith('<html') || 
          responseBody.startsWith('<!doctype') ||
          responseBody.toLowerCase().contains('<!doctype') ||
          responseBody.toLowerCase().contains('<html')) {
        return {'success': false, 'message': 'Server returned HTML error page instead of JSON.\n\nThis means the backend endpoint /api/attendance/mark/ may not exist or the backend has an error.\n\nPlease check:\n1. Backend is running (python manage.py runserver)\n2. Backend terminal for error messages\n3. URL in browser: http://127.0.0.1:8000/api/attendance/mark/'};
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        return {'success': false, 'message': 'Invalid JSON response. Server may have returned an error page.'};
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        String errorMsg = 'Failed to mark attendance';
        if (data.containsKey('error')) {
          errorMsg = data['error'].toString();
        } else if (data.containsKey('message')) {
          errorMsg = data['message'].toString();
        } else if (data.containsKey('detail')) {
          errorMsg = data['detail'].toString();
        }
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorStr = e.toString();
      String errorMsg = 'Connection error';
      
      // Detect HTML response errors
      if (errorStr.contains('FormatException') || errorStr.contains('<!DOCTYPE') || errorStr.contains('<html')) {
        errorMsg = 'Server returned HTML error page instead of JSON. This means:\n'
            '1. Backend endpoint may not exist (404 error)\n'
            '2. Backend has a server error (500 error)\n'
            '3. Backend is not running properly\n\n'
            'Check your backend terminal for errors. Make sure backend is running: python manage.py runserver';
      } else if (errorStr.contains('Connection refused')) {
        errorMsg = 'Connection refused. Backend server is not running. Start it with: python manage.py runserver';
      } else if (errorStr.contains('Failed host lookup') || errorStr.contains('Network is unreachable')) {
        errorMsg = 'Cannot connect to server. Check API URL: $baseUrl\nMake sure backend is running on your computer.';
      } else if (errorStr.contains('TimeoutException')) {
        errorMsg = 'Request timed out. Backend may be slow or not responding.';
      } else {
        errorMsg = 'Error: ${errorStr.length > 150 ? errorStr.substring(0, 150) + "..." : errorStr}';
      }
      
      print('❌ markAttendance error: $errorStr');
      return {'success': false, 'message': errorMsg};
    }
  }

  // Leave early (check-out before 5 PM)
  static Future<Map<String, dynamic>> leaveEarly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/leave-early/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to mark early leave'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Regular check-out at 5 PM
  static Future<Map<String, dynamic>> checkOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/checkout/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to check out'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Start overtime
  static Future<Map<String, dynamic>> startOvertime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/overtime/start/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to start overtime'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // End overtime
  static Future<Map<String, dynamic>> endOvertime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/overtime/end/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to end overtime'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get today's attendance
  static Future<Map<String, dynamic>> getTodayAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/attendance/today/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        return {'success': false, 'message': 'Server returned HTML. Endpoint /api/attendance/today/ may not exist (404).'};
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        return {'success': false, 'message': 'Invalid JSON response. Server may have returned an error page.'};
      }

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load attendance (Status: ${response.statusCode})'};
      }
    } catch (e) {
      String errorMsg = 'Connection error: $e';
      if (e.toString().contains('FormatException') && e.toString().contains('<!DOCTYPE')) {
        errorMsg = 'Server returned HTML error page. Check if /api/attendance/today/ endpoint exists.';
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  // Get attendance summary
  static Future<Map<String, dynamic>> getAttendanceSummary({String period = 'daily'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/attendance/summary/?period=$period'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        return {'success': false, 'message': 'Server returned HTML. Endpoint /api/attendance/summary/ may not exist (404).'};
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        return {'success': false, 'message': 'Invalid JSON response: ${response.body.substring(0, 100)}...'};
      }

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load summary (Status: ${response.statusCode})'};
      }
    } catch (e) {
      String errorMsg = 'Connection error: $e';
      if (e.toString().contains('FormatException') && e.toString().contains('<!DOCTYPE')) {
        errorMsg = 'Server returned HTML error page. Check if /api/attendance/summary/ endpoint exists.';
      }
      return {'success': false, 'message': errorMsg};
    }
  }

  // ========== PROJECT ENDPOINTS ==========

  // Get all projects
  static Future<Map<String, dynamic>> getProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/projects/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load projects'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create project
  static Future<Map<String, dynamic>> createProject({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = {
        'title': title,
        if (description != null) 'description': description,
        if (startDate != null) 'start_date': startDate.toIso8601String().split('T')[0],
        if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
      };

      final response = await http.post(
        Uri.parse('$baseUrl/projects/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? data.toString()};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get available field officers
  static Future<Map<String, dynamic>> getAvailableFieldOfficers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/projects/field-officers/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to load field officers'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Assign field officer to project
  static Future<Map<String, dynamic>> assignFieldOfficer({
    required int projectId,
    required int fieldOfficerId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/projects/$projectId/assign-field-officer/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'field_officer_id': fieldOfficerId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to assign field officer'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Upload document to project
  static Future<Map<String, dynamic>> uploadProjectDocument({
    required int projectId,
    required String filePath,
    required String fileName,
    String? description,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/projects/documents/'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      request.fields['project'] = projectId.toString();
      request.fields['name'] = fileName;
      if (description != null) {
        request.fields['description'] = description;
      }

      final file = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(file);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to upload document'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete project document
  static Future<Map<String, dynamic>> deleteProjectDocument(int documentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/projects/documents/$documentId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? 'Failed to delete document'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get project detail
  static Future<Map<String, dynamic>> getProject(int projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/projects/$projectId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load project'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Valuation API methods
  static Future<Map<String, dynamic>> getValuations({int? projectId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      String url = '$baseUrl/valuations/';
      if (projectId != null) {
        url += '?project=$projectId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Failed to load valuations'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getValuation(int valuationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/valuations/$valuationId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Failed to load valuation'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createValuation(Map<String, dynamic> valuationData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/valuations/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(valuationData),
      );

      final responseBody = response.body;
      Map<String, dynamic> data;
      
      try {
        data = jsonDecode(responseBody);
      } catch (e) {
        return {'success': false, 'message': 'Invalid response from server: $responseBody'};
      }

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        // Try to extract detailed error messages
        String errorMessage = 'Failed to create valuation';
        
        // Check for errors dictionary (Django REST Framework format)
        if (data.containsKey('errors')) {
          final errors = data['errors'];
          if (errors is Map) {
            final fieldErrors = <String>[];
            errors.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                fieldErrors.add('$key: ${value.join(", ")}');
              } else if (value is String && value.isNotEmpty) {
                fieldErrors.add('$key: $value');
              }
            });
            if (fieldErrors.isNotEmpty) {
              errorMessage = fieldErrors.join('\n');
            }
          }
        } else if (data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
        } else if (data.containsKey('message')) {
          errorMessage = data['message'].toString();
        } else if (data.containsKey('error')) {
          errorMessage = data['error'].toString();
        } else if (data.containsKey('non_field_errors')) {
          errorMessage = data['non_field_errors'].toString();
        } else {
          // Check for field-specific errors (direct in response)
          final fieldErrors = <String>[];
          data.forEach((key, value) {
            if (key != 'success' && value != null) {
              if (value is List && value.isNotEmpty) {
                fieldErrors.add('$key: ${value.join(", ")}');
              } else if (value is String && value.isNotEmpty) {
                fieldErrors.add('$key: $value');
              }
            }
          });
          if (fieldErrors.isNotEmpty) {
            errorMessage = fieldErrors.join('\n');
          } else {
            errorMessage = 'Status ${response.statusCode}: ${responseBody}';
          }
        }
        
        // Log full response for debugging
        print('Valuation creation error response: $responseBody');
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateValuation(int valuationId, Map<String, dynamic> valuationData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/valuations/$valuationId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(valuationData),
      );

      final responseBody = response.body;
      Map<String, dynamic> data;
      
      try {
        data = jsonDecode(responseBody);
      } catch (e) {
        return {'success': false, 'message': 'Invalid response from server: $responseBody'};
      }

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        // Try to extract detailed error messages
        String errorMessage = 'Failed to update valuation';
        if (data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
        } else if (data.containsKey('message')) {
          errorMessage = data['message'].toString();
        } else if (data.containsKey('error')) {
          errorMessage = data['error'].toString();
        } else if (data.containsKey('non_field_errors')) {
          errorMessage = data['non_field_errors'].toString();
        } else {
          // Check for field-specific errors
          final fieldErrors = <String>[];
          data.forEach((key, value) {
            if (value is List && value.isNotEmpty) {
              fieldErrors.add('$key: ${value.join(", ")}');
            } else if (value is String && value.isNotEmpty) {
              fieldErrors.add('$key: $value');
            }
          });
          if (fieldErrors.isNotEmpty) {
            errorMessage = fieldErrors.join('\n');
          } else {
            errorMessage = 'Status ${response.statusCode}: ${responseBody}';
          }
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> submitValuation(int valuationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/valuations/$valuationId/submit/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? data['detail'] ?? 'Failed to submit valuation'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadValuationPhoto(int valuationId, String photoPath, {String? caption}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/valuations/$valuationId/photos/'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['valuation'] = valuationId.toString();
      if (caption != null && caption.isNotEmpty) {
        request.fields['caption'] = caption;
      }

      final file = await http.MultipartFile.fromPath('photo', photoPath);
      request.files.add(file);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? data['message'] ?? 'Failed to upload photo'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteValuationPhoto(int photoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/valuations/photos/$photoId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['detail'] ?? 'Failed to delete photo'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ========== PAYMENT SLIP ENDPOINTS ==========

  // Generate payment slips for all users (Admin only)
  static Future<Map<String, dynamic>> generatePaymentSlips({int? month, int? year}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = <String, dynamic>{};
      if (month != null) body['month'] = month;
      if (year != null) body['year'] = year;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/payment-slips/generate/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to generate payment slips'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get current user's payment slips
  static Future<Map<String, dynamic>> getMyPaymentSlips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/payment-slips/my/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // DRF ListAPIView returns a list directly, or wrapped in 'results' for pagination
        if (data is List) {
          return {'success': true, 'data': data};
        } else if (data is Map && data.containsKey('results')) {
          return {'success': true, 'data': data['results']};
        } else {
          return {'success': true, 'data': []};
        }
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['detail'] ?? errorData['message'] ?? 'Failed to load payment slips'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get all payment slips (Admin only)
  static Future<Map<String, dynamic>> getAllPaymentSlips({int? month, int? year, int? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final queryParams = <String>[];
      if (month != null) queryParams.add('month=$month');
      if (year != null) queryParams.add('year=$year');
      if (userId != null) queryParams.add('user_id=$userId');

      String url = '$baseUrl/auth/payment-slips/';
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load payment slips'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get payment slip detail
  static Future<Map<String, dynamic>> getPaymentSlipDetail(int slipId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/payment-slips/$slipId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load payment slip'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}


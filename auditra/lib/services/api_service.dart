import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_db_service.dart';
import 'offline_storage_service.dart';
import 'network_service.dart';
import '../models/project_model.dart';

// Helper function to safely parse JSON response and handle HTML errors
Map<String, dynamic>? _safeParseJsonResponse(http.Response response) {
  // Check if response is HTML (error page) before parsing JSON
  String contentType = response.headers['content-type'] ?? '';
  String bodyTrimmed = response.body.trim();
  
  if (bodyTrimmed.startsWith('<!DOCTYPE') || 
      bodyTrimmed.startsWith('<html') ||
      (!contentType.contains('application/json') && response.body.isNotEmpty && !bodyTrimmed.startsWith('{'))) {
    return null; // Indicates HTML response
  }

  // Try to parse JSON response
  try {
    if (response.body.isEmpty) {
      return {};
    } else {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
  } catch (e) {
    // If parsing fails, check if it's HTML
    if (bodyTrimmed.startsWith('<!DOCTYPE') || bodyTrimmed.startsWith('<html')) {
      return null; // Indicates HTML response
    }
    rethrow; // Re-throw if it's a different parsing error
  }
}

// Helper function to get user-friendly error message for HTML responses
String _getHtmlErrorMessage(http.Response response) {
  if (response.statusCode != 200 && response.statusCode != 201) {
    return 'Server error (Status ${response.statusCode}). Please check if the backend server is running correctly.';
  } else {
    return 'Server returned HTML instead of JSON. Please check backend configuration.';
  }
}

class ApiService {
  // Production API URL - Update this to your VPS IP or domain
  // For local development, use: 'http://10.0.2.2:8000/api' (Android emulator)
  // For production VPS, use: 'http://152.42.240.220/api'
  static const String baseUrl = 'http://152.42.240.220/api';

  /// Check if offline mode should be used (only for field officers)
  static Future<bool> _shouldUseOfflineMode() async {
    return await OfflineDBService.isOfflineModeEnabled();
  }

  // Register new user
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
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
      );

      // Check if response is HTML (error page) before parsing JSON
      final data = _safeParseJsonResponse(response);
      if (data == null) {
        // HTML response received
        return {
          'success': false,
          'message': _getHtmlErrorMessage(response)
        };
      }

      if (response.statusCode == 201) {
        // Save tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        await prefs.setString('refresh_token', data['refresh']);
        await prefs.setString('user_id', data['user']['id'].toString());
        await prefs.setString('username', data['user']['username']);
        
        return {'success': true, 'data': data};
      } else {
        // Extract error message from response
        String errorMsg = 'Registration failed';
        if (data is Map<String, dynamic>) {
          errorMsg = data['username']?.join(', ') ?? 
                     data['email']?.join(', ') ?? 
                     data['password']?.join(', ') ??
                     data['detail'] ?? 
                     data['error'] ?? 
                     data['message'] ?? 
                     errorMsg;
        }
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
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

      // Check if response is HTML (error page) before parsing JSON
      final data = _safeParseJsonResponse(response);
      if (data == null) {
        // HTML response received
        return {
          'success': false,
          'message': _getHtmlErrorMessage(response)
        };
      }

      if (response.statusCode == 200) {
        // Save tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        await prefs.setString('refresh_token', data['refresh']);
        await prefs.setString('user_id', data['user']['id'].toString());
        await prefs.setString('username', data['user']['username']);
        
        // Include password_change_required flag in response
        return {
          'success': true, 
          'data': data,
          'password_change_required': data['password_change_required'] ?? false
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? data['error'] ?? data['message'] ?? 'Login failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Change password (one-time for clients/agents)
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password2': newPassword,
        }),
      );

      // Check if response is HTML (error page) before parsing JSON
      final data = _safeParseJsonResponse(response);
      if (data == null) {
        // HTML response received
        return {
          'success': false,
          'message': _getHtmlErrorMessage(response)
        };
      }

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password changed successfully'
        };
      } else {
        // Extract error message from response
        String errorMsg = 'Password change failed';
        if (data is Map<String, dynamic>) {
          errorMsg = data['error'] ?? 
                     data['detail'] ?? 
                     data['message'] ?? 
                     data['old_password']?.join(', ') ??
                     data['new_password']?.join(', ') ??
                     errorMsg;
        }
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Check if user exists by email
  static Future<Map<String, dynamic>> checkUserByEmail({
    required String email,
    required String roleType, // 'client' or 'agent'
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final url = '$baseUrl/auth/check-user-by-email/';
      print('DEBUG API: Calling URL: $url');
      print('DEBUG API: Email: $email, RoleType: $roleType');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'role_type': roleType,
        }),
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw Exception('Request timeout - please check your internet connection');
        },
      );
      
      print('DEBUG API: Response status: ${response.statusCode}');
      print('DEBUG API: Response body: ${response.body}');

      final data = _safeParseJsonResponse(response);
      if (data == null) {
        return {
          'success': false,
          'message': _getHtmlErrorMessage(response)
        };
      }

      if (response.statusCode == 200) {
        return {
          'success': true,
          'exists': data['exists'] ?? false,
          'message': data['message'] ?? data['error'] ?? '',
          'user_id': data['user_id'],
          'username': data['username'],
          'name': data['name'],
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? data['detail'] ?? 'Failed to check user'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create client account
  static Future<Map<String, dynamic>> createClientAccount({
    required String email,
    required String name,
    String? phone,
    String? address,
    String? company,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final url = '$baseUrl/auth/create-client-account/';
      final body = {
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (address != null && address.isNotEmpty) 'address': address.trim(),
        if (company != null && company.isNotEmpty) 'company': company.trim(),
      };
      
      print('DEBUG API: Creating client account');
      print('DEBUG API: URL: $url');
      print('DEBUG API: Body: $body');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - please check your internet connection');
        },
      );
      
      print('DEBUG API: Response status: ${response.statusCode}');
      print('DEBUG API: Response body: ${response.body}');

      final data = _safeParseJsonResponse(response);
      if (data == null) {
        return {
          'success': false,
          'message': _getHtmlErrorMessage(response)
        };
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Check if response has 'success' field or just return success
        if (data.containsKey('success') && data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Client account created successfully',
            'user': data['user'],
          };
        } else if (data.containsKey('error')) {
          return {
            'success': false,
            'message': data['error'] ?? 'Failed to create client account'
          };
        } else {
          // Assume success if status is 201/200
          return {
            'success': true,
            'message': data['message'] ?? 'Client account created successfully',
            'user': data['user'],
          };
        }
      } else if (response.statusCode == 400) {
        // Handle 400 Bad Request - might be "already exists" which is actually OK
        if (data.containsKey('error') && data['error'].toString().toLowerCase().contains('already exists')) {
          return {
            'success': true, // Treat as success since client exists
            'message': data['error'] ?? 'Client already exists',
            'user_id': data.containsKey('user_id') ? data['user_id'] : null,
            'already_exists': true,
          };
        } else {
          return {
            'success': false,
            'message': data['error'] ?? data['detail'] ?? data['message'] ?? 'Failed to create client account'
          };
        }
      } else {
        return {
          'success': false,
          'message': data['error'] ?? data['detail'] ?? data['message'] ?? 'Failed to create client account (Status: ${response.statusCode})'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create agent account
  static Future<Map<String, dynamic>> createAgentAccount({
    required String email,
    required String name,
    String? phone,
    String? address,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/create-agent-account/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'name': name.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          if (address != null && address.isNotEmpty) 'address': address.trim(),
        }),
      );

      final data = _safeParseJsonResponse(response);
      if (data == null) {
        return {
          'success': false,
          'message': _getHtmlErrorMessage(response)
        };
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Agent account created successfully',
          'user': data['user'],
        };
      } else if (response.statusCode == 400) {
        // Handle 400 Bad Request - might be "already exists" which is actually OK
        if (data.containsKey('error') && data['error'].toString().toLowerCase().contains('already exists')) {
          return {
            'success': true, // Treat as success since agent exists
            'message': data['error'] ?? 'Agent already exists',
            'user_id': data.containsKey('user_id') ? data['user_id'] : null,
            'already_exists': true,
          };
        } else {
          return {
            'success': false,
            'message': data['error'] ?? data['detail'] ?? data['message'] ?? 'Failed to create agent account'
          };
        }
      } else {
        return {
          'success': false,
          'message': data['error'] ?? data['detail'] ?? data['message'] ?? 'Failed to create agent account (Status: ${response.statusCode})'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load profile'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Refresh access token
  static Future<Map<String, dynamic>> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        return {'success': false, 'message': 'No refresh token available'};
      }

      // Use the auth refresh endpoint
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Save new access token
        final newAccessToken = data['access'] ?? data['access_token'];
        if (newAccessToken != null) {
          await prefs.setString('access_token', newAccessToken);
          // If a new refresh token is provided, save it too
          if (data['refresh'] != null) {
            await prefs.setString('refresh_token', data['refresh']);
          }
          return {'success': true, 'access_token': newAccessToken};
        }
        return {'success': false, 'message': 'Invalid token response'};
      } else {
        // Refresh token expired, clear all tokens
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
        await prefs.remove('user_id');
        await prefs.remove('username');
        return {'success': false, 'message': 'Refresh token expired. Please login again.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Token refresh error: $e'};
    }
  }

  // Check if error is a token expiration error
  static bool _isTokenError(Map<String, dynamic>? data) {
    if (data == null) return false;
    
    final errorCode = data['code']?.toString().toLowerCase() ?? '';
    final errorDetail = data['detail']?.toString().toLowerCase() ?? '';
    final messages = data['messages'];
    
    return errorCode.contains('token') || 
           errorDetail.contains('token') ||
           (messages is Map && messages.toString().toLowerCase().contains('token'));
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Store role locally
        await prefs.setString('user_role', data['role'] ?? 'unassigned');
        await prefs.setString('user_role_display', data['role_display'] ?? 'Unassigned');
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load role'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load roles'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
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

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to mark attendance'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
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

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load attendance'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
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

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': 'Failed to load summary'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
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

      // Check if offline mode and no internet
      if (await _shouldUseOfflineMode()) {
        final cachedProjects = OfflineStorageService.getCachedProjects();
        if (cachedProjects != null && !NetworkService.isOnline) {
          print('📴 Offline - returning cached projects');
          return {
            'success': true,
            'data': cachedProjects.map((p) => p.toJson()).toList(),
            'fromCache': true,
          };
        }
      }

      final response = await http.get(
        Uri.parse('$baseUrl/projects/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Check if response is JSON
      String contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        // If offline mode and cache exists, return cache
        if (await _shouldUseOfflineMode()) {
          final cachedProjects = OfflineStorageService.getCachedProjects();
          if (cachedProjects != null) {
            return {
              'success': true,
              'data': cachedProjects.map((p) => p.toJson()).toList(),
              'fromCache': true,
            };
          }
        }
        return {
          'success': false,
          'message': 'Server error. Please check if the backend server is running.'
        };
      }

      try {
        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          final projectsList = data is List ? data : (data['results'] ?? data);
          
          // Cache projects for offline access (if field officer)
          if (await _shouldUseOfflineMode() && projectsList is List) {
            try {
              final projects = (projectsList as List)
                  .map((json) => Project.fromJson(json))
                  .toList();
              await OfflineStorageService.cacheProjects(projects);
            } catch (e) {
              print('Warning: Failed to cache projects: $e');
            }
          }
          
          return {'success': true, 'data': projectsList};
        } else {
          // If offline mode and cache exists, return cache
          if (await _shouldUseOfflineMode()) {
            final cachedProjects = OfflineStorageService.getCachedProjects();
            if (cachedProjects != null) {
              return {
                'success': true,
                'data': cachedProjects.map((p) => p.toJson()).toList(),
                'fromCache': true,
              };
            }
          }
          return {
            'success': false,
            'message': data is Map && data.containsKey('error')
                ? data['error'].toString()
                : 'Failed to load projects'
          };
        }
      } catch (e) {
        // If offline mode and cache exists, return cache
        if (await _shouldUseOfflineMode()) {
          final cachedProjects = OfflineStorageService.getCachedProjects();
          if (cachedProjects != null) {
            return {
              'success': true,
              'data': cachedProjects.map((p) => p.toJson()).toList(),
              'fromCache': true,
            };
          }
        }
        return {'success': false, 'message': 'Invalid response from server'};
      }
    } catch (e) {
      // If offline mode and cache exists, return cache
      if (await _shouldUseOfflineMode()) {
        final cachedProjects = OfflineStorageService.getCachedProjects();
        if (cachedProjects != null) {
          print('📴 Connection error - returning cached projects: $e');
          return {
            'success': true,
            'data': cachedProjects.map((p) => p.toJson()).toList(),
            'fromCache': true,
          };
        }
      }
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Create project
  static Future<Map<String, dynamic>> createProject({
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String priority = 'medium',
    Map<String, dynamic>? clientInfo,
    Map<String, dynamic>? agentInfo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = {
        'title': title,
        if (description != null) 'description': description,
        if (startDate != null) 'start_date': startDate.toIso8601String().split('T')[0],
        if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
        'priority': priority,
        if (clientInfo != null) 'client_info': clientInfo,
        if (agentInfo != null) 'agent_info': agentInfo,
        'has_agent': agentInfo != null, // Track if agent is required
      };

      // Make the request (with retry logic for token refresh)
      http.Response response = await http.post(
        Uri.parse('$baseUrl/projects/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      // Check if response is JSON before parsing
      String contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        // Server returned HTML (likely an error page)
        return {
          'success': false,
          'message': 'Server error. Please check if the backend server is running.'
        };
      }

      try {
        var data = jsonDecode(response.body);

        // Check if token expired (401 or token error)
        if (response.statusCode == 401 || (response.statusCode != 201 && _isTokenError(data))) {
          // Try to refresh token
          final refreshResult = await refreshToken();
          if (refreshResult['success'] == true) {
            // Retry the request with new token
            token = prefs.getString('access_token');
            response = await http.post(
              Uri.parse('$baseUrl/projects/'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(body),
            );

            // Parse the retry response
            if (response.headers['content-type']?.contains('application/json') == true) {
              final retryData = jsonDecode(response.body);
              if (response.statusCode == 201) {
                return {'success': true, 'data': retryData};
              }
              // If still failing after refresh, return the error
              data = retryData;
            }
          } else {
            // Token refresh failed, return error
            return {
              'success': false,
              'message': refreshResult['message'] ?? 'Session expired. Please login again.'
            };
          }
        }

        if (response.statusCode == 201) {
          return {'success': true, 'data': data};
        } else {
          // Handle validation errors
          if (data is Map<String, dynamic>) {
            String errorMessage = '';
            if (data.containsKey('error')) {
              errorMessage = data['error'].toString();
            } else if (data.containsKey('message')) {
              errorMessage = data['message'].toString();
            } else if (data.containsKey('detail')) {
              errorMessage = data['detail'].toString();
            } else if (data.containsKey('non_field_errors')) {
              errorMessage = (data['non_field_errors'] as List).join(', ');
            } else {
              // Check for field-specific errors
              final errors = <String>[];
              data.forEach((key, value) {
                if (value is List) {
                  errors.add('${key}: ${value.join(', ')}');
                } else if (value is String) {
                  errors.add('${key}: $value');
                }
              });
              errorMessage = errors.isNotEmpty ? errors.join('\n') : 'Failed to create project';
            }
            return {'success': false, 'message': errorMessage};
          }
          return {'success': false, 'message': 'Failed to create project'};
        }
      } catch (e) {
        // If JSON parsing fails, return a user-friendly error
        return {
          'success': false,
          'message': 'Invalid response from server. Please try again.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
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

  // Get available clients
  static Future<Map<String, dynamic>> getAvailableClients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/projects/clients/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to load clients'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get available agents
  static Future<Map<String, dynamic>> getAvailableAgents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/projects/agents/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to load agents'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Assign client to project
  static Future<Map<String, dynamic>> assignClient({
    required int projectId,
    required int clientId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/projects/$projectId/assign-client/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'client_id': clientId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to assign client'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Assign agent to project
  static Future<Map<String, dynamic>> assignAgent({
    required int projectId,
    required int agentId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/projects/$projectId/assign-agent/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'agent_id': agentId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to assign agent'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get available accessors
  static Future<Map<String, dynamic>> getAvailableAccessors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/projects/accessors/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to load accessors'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Assign accessor to project
  static Future<Map<String, dynamic>> assignAccessor({
    required int projectId,
    required int accessorId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/projects/$projectId/assign-accessor/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'accessor_id': accessorId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to assign accessor'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get available senior valuers
  static Future<Map<String, dynamic>> getAvailableSeniorValuers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/projects/senior-valuers/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to load senior valuers'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Assign senior valuer to project
  static Future<Map<String, dynamic>> assignSeniorValuer({
    required int projectId,
    required int seniorValuerId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/projects/$projectId/assign-senior-valuer/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'senior_valuer_id': seniorValuerId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to assign senior valuer'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get projects assigned to a user
  static Future<Map<String, dynamic>> getUserAssignedProjects({
    required int userId,
    required String roleType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/projects/users/$userId/projects/$roleType/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to load assigned projects'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update project
  static Future<Map<String, dynamic>> updateProject({
    required int projectId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? priority,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (startDate != null) body['start_date'] = startDate.toIso8601String().split('T')[0];
      if (endDate != null) body['end_date'] = endDate.toIso8601String().split('T')[0];
       if (priority != null) body['priority'] = priority;

      final response = await http.patch(
        Uri.parse('$baseUrl/projects/$projectId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      // Check if response is JSON
      String contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return {
          'success': false,
          'message': 'Server error. Please check if the backend server is running.'
        };
      }

      try {
        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          return {'success': true, 'data': data};
        } else {
          if (data is Map<String, dynamic>) {
            String errorMessage = '';
            if (data.containsKey('error')) {
              errorMessage = data['error'].toString();
            } else if (data.containsKey('message')) {
              errorMessage = data['message'].toString();
            } else if (data.containsKey('non_field_errors')) {
              errorMessage = (data['non_field_errors'] as List).join(', ');
            } else {
              final errors = <String>[];
              data.forEach((key, value) {
                if (value is List) {
                  errors.add('${key}: ${value.join(', ')}');
                } else if (value is String) {
                  errors.add('${key}: $value');
                }
              });
              errorMessage = errors.isNotEmpty ? errors.join('\n') : 'Failed to update project';
            }
            return {'success': false, 'message': errorMessage};
          }
          return {'success': false, 'message': 'Failed to update project'};
        }
      } catch (e) {
        return {'success': false, 'message': 'Invalid response from server'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Update project status
  static Future<Map<String, dynamic>> updateProjectStatus({
    required int projectId,
    required String status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/projects/$projectId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? data.toString()};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update project workflow stage
  static Future<Map<String, dynamic>> updateProjectWorkflowStage({
    required int projectId,
    String? workflowStage,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/projects/$projectId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'workflow_stage': workflowStage,
        }),
      );

      // Safely parse JSON response (handles HTML error pages)
      final data = _safeParseJsonResponse(response);
      
      if (data == null) {
        // HTML response detected
        return {
          'success': false,
          'message': _getHtmlErrorMessage(response)
        };
      }

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        // Try to extract error message from various possible formats
        String errorMessage = 'Failed to update workflow stage';
        if (data.containsKey('error')) {
          errorMessage = data['error'].toString();
        } else if (data.containsKey('message')) {
          errorMessage = data['message'].toString();
        } else if (data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
        } else if (data.containsKey('non_field_errors')) {
          errorMessage = (data['non_field_errors'] as List).join(', ');
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Upload document to project
  static Future<Map<String, dynamic>> uploadProjectDocument({
    required int projectId,
    required String filePath,
    required String fileName,
    String? description,
    int? assignedToId,
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

      // Validate file exists and get file size
      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'message': 'Selected file does not exist'};
      }
      
      // Check file size (limit to 50MB)
      final fileSize = await file.length();
      const maxFileSize = 50 * 1024 * 1024; // 50MB
      if (fileSize > maxFileSize) {
        return {
          'success': false,
          'message': 'File size exceeds maximum limit of 50MB. Current size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB'
        };
      }

      request.fields['project'] = projectId.toString();
      request.fields['name'] = fileName;
      if (description != null) {
        request.fields['description'] = description;
      }
      if (assignedToId != null) {
        request.fields['assigned_to'] = assignedToId.toString();
      }

      final multipartFile = await http.MultipartFile.fromPath('file', filePath);
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // Check if response is JSON before parsing
      String contentType = response.headers['content-type'] ?? '';
      
      // Check if response body starts with HTML (common error indicator)
      if (response.body.trim().startsWith('<!DOCTYPE') || 
          response.body.trim().startsWith('<html') ||
          (!contentType.contains('application/json') && response.body.isNotEmpty && !response.body.trim().startsWith('{'))) {
        String errorMessage = 'Server returned an error page';
        if (response.statusCode != 201 && response.statusCode != 200) {
          errorMessage = 'Server error (Status ${response.statusCode}). Please check if the backend server is running correctly.';
        } else {
          errorMessage = 'Server returned HTML instead of JSON. Please check backend configuration.';
        }
        return {
          'success': false,
          'message': errorMessage
        };
      }

      // Try to parse JSON response
      Map<String, dynamic> data;
      try {
        if (response.body.isEmpty) {
          data = {};
        } else {
          data = jsonDecode(response.body);
        }
      } catch (e) {
        // If parsing fails, check if it's HTML
        if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
          return {
            'success': false,
            'message': 'Server returned an HTML error page instead of JSON. Status: ${response.statusCode}. Please check backend server.'
          };
        }
        return {
          'success': false,
          'message': 'Failed to parse server response. Status: ${response.statusCode}. Response: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}'
        };
      }

      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        // Try to extract error message from various possible formats
        String errorMessage = 'Failed to upload document';
        if (data.containsKey('error')) {
          errorMessage = data['error'].toString();
        } else if (data.containsKey('message')) {
          errorMessage = data['message'].toString();
        } else if (data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
        } else if (data.containsKey('non_field_errors')) {
          errorMessage = (data['non_field_errors'] as List).join(', ');
        } else if (data.isNotEmpty) {
          // If there are field errors, format them
          final fieldErrors = data.entries
              .where((e) => e.value is List || e.value is String)
              .map((e) => '${e.key}: ${e.value}')
              .join(', ');
          if (fieldErrors.isNotEmpty) {
            errorMessage = fieldErrors;
          }
        }
        
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete project
  static Future<Map<String, dynamic>> deleteProject(int projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/projects/$projectId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['error'] ?? data.toString()};
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
    // Check if offline mode is enabled (field officers only)
    final useOfflineMode = await _shouldUseOfflineMode();
    
    if (useOfflineMode) {
      // OFFLINE-FIRST: Always save locally first
      try {
        final localId = await OfflineStorageService.saveValuationOffline(valuationData);
        print('💾 Valuation saved offline with localId: ${localId.substring(0, 8)}...');
        
        // Try to sync immediately if online
        if (NetworkService.isOnline) {
          try {
            final syncResult = await syncValuationToServer(valuationData);
            if (syncResult['success']) {
              final serverId = syncResult['data']['id'] as int;
              await OfflineStorageService.markValuationSynced(localId, serverId);
              print('✅ Valuation synced immediately: $localId -> $serverId');
              return {'success': true, 'data': syncResult['data'], 'localId': localId};
            } else {
              // Sync failed, but data saved locally
              print('📴 Sync failed, but valuation saved locally');
              return {'success': true, 'localId': localId, 'synced': false};
            }
          } catch (syncErr) {
            // Sync failed, but data saved locally
            print('📴 Sync error, but valuation saved locally: $syncErr');
            return {'success': true, 'localId': localId, 'synced': false};
          }
        } else {
          // Offline, data saved locally
          print('📴 Offline - valuation saved locally, will sync later');
          return {'success': true, 'localId': localId, 'synced': false};
        }
      } catch (e) {
        return {'success': false, 'message': 'Failed to save valuation offline: $e'};
      }
    }
    
    // Normal online flow for non-field officers
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

  /// Helper method to sync valuation to server (used by offline mode and sync engine)
  /// This method does NOT save offline - it only posts to the server
  static Future<Map<String, dynamic>> syncValuationToServer(Map<String, dynamic> valuationData) async {
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
      String errorMessage = 'Failed to create valuation';
      if (data.containsKey('detail')) {
        errorMessage = data['detail'].toString();
      } else if (data.containsKey('message')) {
        errorMessage = data['message'].toString();
      } else if (data.containsKey('error')) {
        errorMessage = data['error'].toString();
      } else if (data.isNotEmpty) {
        // Try to extract field errors
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
          errorMessage = 'Validation failed';
        }
      }
      print('❌ Server validation error: $errorMessage');
      print('Response data: $data');
      return {'success': false, 'message': errorMessage, 'data': null};
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

  static Future<Map<String, dynamic>> deleteValuation(int valuationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/valuations/$valuationId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return {'success': false, 'message': data['detail'] ?? 'Failed to delete valuation'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}


import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your computer's IP address when testing on physical device
  // For emulator, use 10.0.2.2 (Android) or localhost (iOS)
  // For physical device, use your computer's IP address (e.g., 'http://192.168.1.100:8000/api')
  static const String baseUrl = 'http://10.0.2.2:8000/api';

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

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Save tokens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        await prefs.setString('refresh_token', data['refresh']);
        await prefs.setString('user_id', data['user']['id'].toString());
        await prefs.setString('username', data['user']['username']);
        
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data.toString()};
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

      final data = jsonDecode(response.body);

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
        return {
          'success': false,
          'message': 'Server error. Please check if the backend server is running.'
        };
      }

      try {
        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          // Backend returns a list directly, so wrap it in data
          return {'success': true, 'data': data is List ? data : (data['results'] ?? data)};
        } else {
          return {
            'success': false,
            'message': data is Map && data.containsKey('error')
                ? data['error'].toString()
                : 'Failed to load projects'
          };
        }
      } catch (e) {
        return {'success': false, 'message': 'Invalid response from server'};
      }
    } catch (e) {
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

      request.fields['project'] = projectId.toString();
      request.fields['name'] = fileName;
      if (description != null) {
        request.fields['description'] = description;
      }
      if (assignedToId != null) {
        request.fields['assigned_to'] = assignedToId.toString();
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
}


import 'package:flutter/material.dart';
import 'package:local_auth_platform_interface/types/biometric_type.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../widgets/dark_mode_toggle.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _biometricRequired = false;
  String? _storedUsername;
  String _biometricType = 'Fingerprint';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check biometric availability when screen is shown (e.g., after logout)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAvailability();
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final availability = await BiometricService.checkBiometricAvailability();
    final stored = await BiometricService.getStoredUsername();
    final available = availability['isAvailable'] as bool? ?? false;
    final availableTypesRaw = availability['availableTypes'] as List? ?? [];
    final availableTypes = availableTypesRaw.cast<BiometricType>();
    
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _storedUsername = stored;
        if (_storedUsername != null) {
          _usernameController.text = _storedUsername!;
        }
        if (availableTypes.isNotEmpty) {
          _biometricType = BiometricService.getBiometricTypeName(availableTypes);
        }
      });
      
      // If username is stored, check backend biometric status
      if (_storedUsername != null && _storedUsername!.isNotEmpty) {
        _checkBiometricStatus();
      }
    }
  }

  Future<void> _checkBiometricStatus() async {
    // If username is stored and biometric is available, enable the button
    // The backend will verify when attempting biometric login
    if (_storedUsername != null && _storedUsername!.isNotEmpty && _biometricAvailable) {
      setState(() {
        _biometricEnabled = true; // Show button if username is stored and biometric available
      });
      print('LoginScreen: Biometric enabled - Username: $_storedUsername, Available: $_biometricAvailable');
    } else {
      setState(() {
        _biometricEnabled = false;
      });
      print('LoginScreen: Biometric disabled - Username: $_storedUsername, Available: $_biometricAvailable');
    }
  }

  Future<void> _loginWithBiometric() async {
    if (_storedUsername == null || _storedUsername!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No stored username found for biometric login'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Authenticate with biometric
    final authResult = await BiometricService.authenticateWithResult(
      reason: 'Authenticate to login',
    );

    if (!authResult['success'] as bool) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authResult['error'] ?? 'Biometric authentication failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Login with biometric (username only)
    final result = await ApiService.biometricLogin(_storedUsername!);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      // Get user role to route to appropriate dashboard
      await ApiService.getMyRole();
      final role = await ApiService.getUserRole();
      
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(userRole: role ?? 'unassigned')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Biometric login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      // Store username for biometric login if biometric is available
      if (_biometricAvailable) {
        await BiometricService.storeUsernameForBiometric(_usernameController.text.trim());
        
        // Check if biometric is enabled on backend
        final biometricStatus = await ApiService.getBiometricStatus();
        if (biometricStatus['success'] == true && mounted) {
          final statusData = biometricStatus['data'] as Map<String, dynamic>?;
          setState(() {
            _biometricEnabled = statusData?['biometric_enabled'] as bool? ?? false;
            _biometricRequired = statusData?['biometric_required'] as bool? ?? false;
          });
        }
      }
      
      // Get user role to route to appropriate dashboard
      await ApiService.getMyRole();
      final role = await ApiService.getUserRole();
      
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(userRole: role ?? 'unassigned')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const [
          DarkModeToggle(),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Title
                  const Icon(
                    Icons.verified_user,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Auditra',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Biometric Login Button (if available and username stored)
                  if (_biometricAvailable && _storedUsername != null && _storedUsername!.isNotEmpty)
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _loginWithBiometric,
                          icon: Icon(
                            _biometricType.contains('Face') 
                                ? Icons.face 
                                : Icons.fingerprint,
                          ),
                          label: Text('Login with $_biometricType'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: _biometricRequired 
                                ? Colors.orange 
                                : Colors.blue[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text('Register'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


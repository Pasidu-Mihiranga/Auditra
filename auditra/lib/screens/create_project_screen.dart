import 'dart:convert';
import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/project_model.dart';

class CreateProjectScreen extends StatefulWidget {
  final Project? rejectedProject; // Optional rejected project to recreate from
  
  const CreateProjectScreen({super.key, this.rejectedProject});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final clientNameController = TextEditingController();
  final clientEmailController = TextEditingController();
  final clientPhoneController = TextEditingController();
  final clientAddressController = TextEditingController();
  final clientCompanyController = TextEditingController();
  final agentNameController = TextEditingController();
  final agentEmailController = TextEditingController();
  final agentPhoneController = TextEditingController();
  final agentAddressController = TextEditingController();
  final agentLicenseController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool hasAgent = false;
  bool _isCreating = false;
  String _priority = 'medium'; // high, medium, low
  final formKey = GlobalKey<FormState>();
  
  // Client email check state
  bool _checkingClientEmail = false;
  bool? _clientExists;
  String? _clientCheckMessage;
  bool _creatingClient = false;
  
  // Agent email check state
  bool _checkingAgentEmail = false;
  bool? _agentExists;
  String? _agentCheckMessage;
  bool _creatingAgent = false;
  
  bool get _isRecreating => widget.rejectedProject != null;

  @override
  void initState() {
    super.initState();
    // Add listeners to email fields for real-time checking
    clientEmailController.addListener(_onClientEmailChanged);
    agentEmailController.addListener(_onAgentEmailChanged);
    
    // Use post-frame callback to ensure controllers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-fill all fields from rejected project if recreating
      if (widget.rejectedProject != null) {
        _prefillFieldsFromProject(widget.rejectedProject!);
      }
      
      // Check emails if they're already filled (e.g., when editing or after prefilling)
      final clientEmail = clientEmailController.text.trim();
      if (clientEmail.isNotEmpty) {
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (emailRegex.hasMatch(clientEmail)) {
          setState(() {
            _checkingClientEmail = true;
          });
          _checkClientEmail(clientEmail);
        }
      }
      
      if (hasAgent) {
        final agentEmail = agentEmailController.text.trim();
        if (agentEmail.isNotEmpty) {
          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          if (emailRegex.hasMatch(agentEmail)) {
            setState(() {
              _checkingAgentEmail = true;
            });
            _checkAgentEmail(agentEmail);
          }
        }
      }
    });
  }

  void _prefillFieldsFromProject(Project project) {
    titleController.text = project.title;
    descriptionController.text = project.description ?? '';
    startDate = project.startDate;
    endDate = project.endDate;
    _priority = project.priority ?? 'medium';
    
    // Pre-fill client info - try clientInfo first, then fall back to assigned client fields
    if (project.clientInfo != null && project.clientInfo!.isNotEmpty) {
      print('🔍 Client Info from project.clientInfo: ${project.clientInfo}');
      final clientInfo = project.clientInfo!;
      clientNameController.text = (clientInfo['name'] ?? clientInfo['client_name'] ?? '').toString();
      clientEmailController.text = (clientInfo['email'] ?? clientInfo['client_email'] ?? '').toString();
      clientPhoneController.text = (clientInfo['phone'] ?? clientInfo['client_phone'] ?? clientInfo['phone_number'] ?? '').toString();
      clientAddressController.text = (clientInfo['address'] ?? clientInfo['client_address'] ?? '').toString();
      clientCompanyController.text = (clientInfo['company'] ?? clientInfo['company_name'] ?? '').toString();
      print('✅ Pre-filled client from clientInfo: ${clientNameController.text}, ${clientEmailController.text}');
    } else if (project.assignedClientName != null || project.assignedClientEmail != null) {
      // Fall back to assigned client fields
      print('🔍 Using assigned client fields: name=${project.assignedClientName}, email=${project.assignedClientEmail}');
      clientNameController.text = project.assignedClientName ?? '';
      clientEmailController.text = project.assignedClientEmail ?? '';
      // Phone, address, and company might not be in assigned fields, so leave them empty
      print('✅ Pre-filled client from assigned fields: ${clientNameController.text}, ${clientEmailController.text}');
    } else {
      print('⚠️ No client info found in project (clientInfo: ${project.clientInfo}, assignedClientName: ${project.assignedClientName})');
    }
    
    // Pre-fill agent info
    if (project.agentInfo != null && project.agentInfo!.isNotEmpty) {
      print('🔍 Agent Info from project: ${project.agentInfo}');
      final agentInfo = project.agentInfo!;
      hasAgent = true;
      agentNameController.text = (agentInfo['name'] ?? agentInfo['agent_name'] ?? '').toString();
      agentEmailController.text = (agentInfo['email'] ?? agentInfo['agent_email'] ?? '').toString();
      agentPhoneController.text = (agentInfo['phone'] ?? agentInfo['agent_phone'] ?? agentInfo['phone_number'] ?? '').toString();
      agentAddressController.text = (agentInfo['address'] ?? agentInfo['agent_address'] ?? '').toString();
      agentLicenseController.text = (agentInfo['license_number'] ?? agentInfo['license'] ?? '').toString();
      print('✅ Pre-filled agent: ${agentNameController.text}, ${agentEmailController.text}');
    } else if (project.assignedAgentName != null || project.assignedAgentEmail != null) {
      // Fall back to assigned agent fields
      print('🔍 Using assigned agent fields: name=${project.assignedAgentName}, email=${project.assignedAgentEmail}');
      hasAgent = true;
      agentNameController.text = project.assignedAgentName ?? '';
      agentEmailController.text = project.assignedAgentEmail ?? '';
      print('✅ Pre-filled agent from assigned fields: ${agentNameController.text}, ${agentEmailController.text}');
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    clientEmailController.removeListener(_onClientEmailChanged);
    agentEmailController.removeListener(_onAgentEmailChanged);
    titleController.dispose();
    descriptionController.dispose();
    clientNameController.dispose();
    clientEmailController.dispose();
    clientPhoneController.dispose();
    clientAddressController.dispose();
    clientCompanyController.dispose();
    agentNameController.dispose();
    agentEmailController.dispose();
    agentPhoneController.dispose();
    agentAddressController.dispose();
    agentLicenseController.dispose();
    super.dispose();
  }

  void _onClientEmailChanged() {
    final email = clientEmailController.text.trim();
    print('DEBUG: _onClientEmailChanged called with: $email');
    if (email.isEmpty) {
      setState(() {
        _clientExists = null;
        _clientCheckMessage = null;
        _checkingClientEmail = false;
      });
      return;
    }
    
    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      print('DEBUG: Email validation failed for: $email');
      setState(() {
        _clientExists = null;
        _clientCheckMessage = null;
        _checkingClientEmail = false;
      });
      return;
    }
    
    print('DEBUG: Email validation passed, starting check for: $email');
    // Show checking state immediately and start checking right away
    setState(() {
      _checkingClientEmail = true;
    });
    
    // Check email after a very short delay (debounce) - reduced to 200ms for faster response
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && clientEmailController.text.trim() == email && email.isNotEmpty) {
        print('DEBUG: Debounce complete, calling _checkClientEmail for: $email');
        _checkClientEmail(email);
      } else {
        // If email changed, cancel the check
        print('DEBUG: Email changed during debounce, canceling check');
        if (mounted) {
          setState(() {
            _checkingClientEmail = false;
          });
        }
      }
    });
  }

  void _onAgentEmailChanged() {
    if (!hasAgent) return;
    final email = agentEmailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _agentExists = null;
        _agentCheckMessage = null;
        _checkingAgentEmail = false;
      });
      return;
    }
    
    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _agentExists = null;
        _agentCheckMessage = null;
        _checkingAgentEmail = false;
      });
      return;
    }
    
    // Show checking state immediately and start checking right away
    setState(() {
      _checkingAgentEmail = true;
    });
    
    // Check email after a very short delay (debounce) - reduced to 200ms for faster response
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && hasAgent && agentEmailController.text.trim() == email && email.isNotEmpty) {
        _checkAgentEmail(email);
      } else {
        // If email changed, cancel the check
        if (mounted) {
          setState(() {
            _checkingAgentEmail = false;
          });
        }
      }
    });
  }

  Future<void> _checkClientEmail(String email) async {
    if (!mounted) return;
    
    // Only reset exists state, keep checking state true
    setState(() {
      _clientExists = null;
      _clientCheckMessage = null;
    });

    try {
      print('DEBUG: Starting client email check for: $email');
      final result = await ApiService.checkUserByEmail(
        email: email,
        roleType: 'client',
      );

      if (!mounted) return;

      print('DEBUG: Client email check result: $result');
      setState(() {
        _checkingClientEmail = false;
        if (result['success'] == true) {
          _clientExists = result['exists'] ?? false;
          _clientCheckMessage = result['message'] ?? '';
          print('DEBUG: Client exists: $_clientExists, Message: $_clientCheckMessage');
        } else {
          _clientExists = null;
          _clientCheckMessage = result['message'] ?? 'Error checking client';
          print('DEBUG: Client check failed: $_clientCheckMessage');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingClientEmail = false;
        _clientExists = null;
        String errorMsg = e.toString();
        if (errorMsg.contains('timeout')) {
          _clientCheckMessage = 'Connection timeout. Please check your internet.';
        } else if (errorMsg.contains('Failed host lookup')) {
          _clientCheckMessage = 'Cannot reach server. Please check your connection.';
        } else {
          _clientCheckMessage = 'Error: ${errorMsg.length > 50 ? errorMsg.substring(0, 50) + "..." : errorMsg}';
        }
      });
    }
  }

  Future<void> _checkAgentEmail(String email) async {
    if (!mounted || !hasAgent) return;
    
    // Only reset exists state, keep checking state true
    setState(() {
      _agentExists = null;
      _agentCheckMessage = null;
    });

    try {
      print('DEBUG: Starting agent email check for: $email');
      final result = await ApiService.checkUserByEmail(
        email: email,
        roleType: 'agent',
      );

      if (!mounted) return;

      print('DEBUG: Agent email check result: $result');
      setState(() {
        _checkingAgentEmail = false;
        if (result['success'] == true) {
          _agentExists = result['exists'] ?? false;
          _agentCheckMessage = result['message'] ?? '';
          print('DEBUG: Agent exists: $_agentExists, Message: $_agentCheckMessage');
        } else {
          _agentExists = null;
          _agentCheckMessage = result['message'] ?? 'Error checking agent';
          print('DEBUG: Agent check failed: $_agentCheckMessage');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingAgentEmail = false;
        _agentExists = null;
        String errorMsg = e.toString();
        if (errorMsg.contains('timeout')) {
          _agentCheckMessage = 'Connection timeout. Please check your internet.';
        } else if (errorMsg.contains('Failed host lookup')) {
          _agentCheckMessage = 'Cannot reach server. Please check your connection.';
        } else {
          _agentCheckMessage = 'Error: ${errorMsg.length > 50 ? errorMsg.substring(0, 50) + "..." : errorMsg}';
        }
      });
    }
  }

  Future<void> _createClientAccount() async {
    if (clientNameController.text.trim().isEmpty || clientEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client name and email are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('DEBUG: Starting client account creation');
    setState(() => _creatingClient = true);

    try {
      final result = await ApiService.createClientAccount(
        email: clientEmailController.text.trim(),
        name: clientNameController.text.trim(),
        phone: clientPhoneController.text.trim().isEmpty ? null : clientPhoneController.text.trim(),
        address: clientAddressController.text.trim().isEmpty ? null : clientAddressController.text.trim(),
        company: clientCompanyController.text.trim().isEmpty ? null : clientCompanyController.text.trim(),
      );

      if (!mounted) return;

      print('DEBUG: Client account creation result: $result');
      setState(() => _creatingClient = false);

      if (result['success'] == true) {
        // Check if client already existed
        if (result['already_exists'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result['message'] ?? 'Client already exists')),
                ],
              ),
              backgroundColor: Colors.blue,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result['message'] ?? 'Client account created successfully')),
                ],
              ),
              backgroundColor: const Color(0xFF84BCDA),
            ),
          );
        }
        // Re-check email to update status
        _checkClientEmail(clientEmailController.text.trim());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to create client account'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error creating client account: $e');
      if (!mounted) return;
      setState(() => _creatingClient = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating client account: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createAgentAccount() async {
    if (agentNameController.text.trim().isEmpty || agentEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agent name and email are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('DEBUG: Starting agent account creation');
    setState(() => _creatingAgent = true);

    try {
      final result = await ApiService.createAgentAccount(
        email: agentEmailController.text.trim(),
        name: agentNameController.text.trim(),
        phone: agentPhoneController.text.trim().isEmpty ? null : agentPhoneController.text.trim(),
        address: agentAddressController.text.trim().isEmpty ? null : agentAddressController.text.trim(),
      );

      if (!mounted) return;

      print('DEBUG: Agent account creation result: $result');
      setState(() => _creatingAgent = false);

      if (result['success'] == true) {
        // Check if agent already existed
        if (result['already_exists'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result['message'] ?? 'Agent already exists')),
                ],
              ),
              backgroundColor: Colors.blue,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result['message'] ?? 'Agent account created successfully')),
                ],
              ),
              backgroundColor: const Color(0xFF84BCDA),
            ),
          );
        }
        // Re-check email to update status
        _checkAgentEmail(agentEmailController.text.trim());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to create agent account'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error creating agent account: $e');
      if (!mounted) return;
      setState(() => _creatingAgent = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating agent account: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!formKey.currentState!.validate()) {
      // Validate dates manually since they're not in the form
      if (startDate == null || endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required fields (Description, Start Date, End Date)'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Additional validation for dates
    if (startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start date is required'),
          //backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate client name and email
    if (clientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (clientEmailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client email is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if client email is being checked
    if (_checkingClientEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while we check the client email...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if client exists
    if (_clientExists == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client account does not exist. Please create the client account first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate agent name and email if agent is enabled
    if (hasAgent) {
      if (agentNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agent name is required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (agentEmailController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agent email is required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if agent email is being checked
      if (_checkingAgentEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait while we check the agent email...'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check if agent exists
      if (_agentExists == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agent account does not exist. Please create the agent account first.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isCreating = true);

    try {
      final createResult = await ApiService.createProject(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        startDate: startDate,
        endDate: endDate,
        priority: _priority,
        clientInfo: {
          'name': clientNameController.text.trim(),
          'email': clientEmailController.text.trim().isEmpty ? null : clientEmailController.text.trim(),
          'phone': clientPhoneController.text.trim().isEmpty ? null : clientPhoneController.text.trim(),
          'address': clientAddressController.text.trim().isEmpty ? null : clientAddressController.text.trim(),
          'company': clientCompanyController.text.trim().isEmpty ? null : clientCompanyController.text.trim(),
        },
        agentInfo: hasAgent ? {
          'name': agentNameController.text.trim().isEmpty ? null : agentNameController.text.trim(),
          'email': agentEmailController.text.trim().isEmpty ? null : agentEmailController.text.trim(),
          'phone': agentPhoneController.text.trim().isEmpty ? null : agentPhoneController.text.trim(),
          'address': agentAddressController.text.trim().isEmpty ? null : agentAddressController.text.trim(),
          'license_number': agentLicenseController.text.trim().isEmpty ? null : agentLicenseController.text.trim(),
        } : null,
      );

      if (mounted) {
        if (createResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('Project created successfully!')),
                ],
              ),
              backgroundColor: const Color(0xFF84BCDA),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(createResult['message'] ?? 'Failed to create project'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Widget _buildClientStatusWidget() {
    if (_checkingClientEmail) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFDAF6EF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF4CAF50)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Checking client...',
              style: TextStyle(color: Color(0xFF2E7D32), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // If email is entered but not checked yet, show nothing
    if (_clientExists == null && !_checkingClientEmail) {
      return const SizedBox.shrink();
    }

    if (_clientExists == true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9), // Light Green
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _clientCheckMessage ?? 'Client already exists',
                style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE), // Light Red/Pink for warning
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFC62828), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _clientCheckMessage ?? 'Client does not exist',
                    style: const TextStyle(color: Color(0xFFC62828), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48, // Taller button
            child: ElevatedButton.icon(
              onPressed: _creatingClient ? null : _createClientAccount,
              icon: _creatingClient
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.person_add_rounded, size: 20),
              label: Text(
                _creatingClient ? 'Creating...' : 'Create Client',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50), // Green Theme
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildAgentStatusWidget() {
    if (_checkingAgentEmail) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFDAF6EF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF4CAF50)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Checking agent...',
              style: TextStyle(color: Color(0xFF2E7D32), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // If email is entered but not checked yet, show nothing
    if (_agentExists == null && !_checkingAgentEmail) {
      return const SizedBox.shrink();
    }

    if (_agentExists == true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _agentCheckMessage ?? 'Agent already exists',
                style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFC62828), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _agentCheckMessage ?? 'Agent does not exist',
                    style: const TextStyle(color: Color(0xFFC62828), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _creatingAgent ? null : _createAgentAccount,
              icon: _creatingAgent
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.person_add_rounded, size: 20),
              label: Text(
                _creatingAgent ? 'Creating...' : 'Create Agent',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }
  }

  InputDecoration _buildInputDecoration({required String hintText, required IconData icon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
      prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red[400]!, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child, Widget? trailing}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6), // Semi-transparent for glass effect
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.05), // Subtle green shadow
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Frosted glass blur
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          fontFamily: 'Etna Sans Serif',
                        ),
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChipModern({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _priority == value;
    return Expanded(
      child: InkWell(
        onTap: _isRecreating ? null : () => setState(() => _priority = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.05) : Colors.white,
            border: Border.all(
              color: isSelected ? color : Colors.grey[200]!,
              width: isSelected ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? color : Colors.grey[400],
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey[500],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required IconData icon,
    required DateTime? date,
    required VoidCallback onTap,
    bool isRequired = false,
  }) {
    return InkWell(
      onTap: _isRecreating ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _isRecreating ? Colors.grey[100] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF4CAF50)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRequired ? '$label *' : label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? DateFormat('MMM dd, yyyy').format(date)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isRecreating ? Colors.grey[600] : (date != null ? Colors.black87 : Colors.grey[400]),
                      fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today, color: _isRecreating ? Colors.grey[400] : Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDAF6EF),
      body: Form(
        key: formKey,
        child: Column(
          children: [
            // Modern Header
            // Glassmorphic Header
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 20,
                    left: 20,
                    right: 20,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.create_new_folder, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isRecreating ? 'Recreate Project' : 'Create New Project',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.create_new_folder_outlined, color: Color(0xFF1F2937), size: 28),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Create New Project',
                          style: TextStyle(
                            fontFamily: 'Etna Sans Serif',
                            color: Color(0xFF1F2937),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Scrollable Content
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(10),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Card
                      _buildSectionCard(
                        title: 'Basic Information',
                        icon: Icons.info_outline,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: titleController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _buildInputDecoration(
                                hintText: 'Project Title *',
                                icon: Icons.title,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Project title is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: descriptionController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _buildInputDecoration(
                                hintText: 'Description *',
                                icon: Icons.description_outlined,
                              ),
                              maxLines: 1, // Keep single line to look like other inputs as per design
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Description is required';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Priority Card
                      _buildSectionCard(
                        title: 'Priority',
                        icon: Icons.flag_outlined,
                        child: Row(
                          children: [
                            _buildPriorityChipModern(
                              label: 'High',
                              value: 'high',
                              color: Colors.red[500]!,
                              icon: Icons.priority_high_rounded,
                            ),
                            const SizedBox(width: 12),
                            _buildPriorityChipModern(
                              label: 'Medium',
                              value: 'medium',
                              color: Colors.orange[500]!,
                              icon: Icons.remove_circle_outline_rounded,
                            ),
                            const SizedBox(width: 12),
                            _buildPriorityChipModern(
                              label: 'Low',
                              value: 'low',
                              color: const Color(0xFF84BCDA)!,
                              icon: Icons.arrow_downward_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Dates Card
                      _buildSectionCard(
                        title: 'Project Timeline',
                        icon: Icons.calendar_today,
                        child: Column(
                          children: [
                            _buildDatePickerField(
                              label: 'Start Date *',
                              icon: Icons.play_circle_outline,
                              date: startDate,
                              isRequired: true,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF4CAF50),
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Colors.black87,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() => startDate = picked);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildDatePickerField(
                              label: 'End Date *',
                              icon: Icons.event_available,
                              date: endDate,
                              isRequired: true,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate ?? startDate ?? DateTime.now().add(const Duration(days: 30)),
                                  firstDate: startDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF4CAF50),
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Colors.black87,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() => endDate = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Client Information Card
                      _buildSectionCard(
                        title: 'Client Information *',
                        icon: Icons.business_outlined,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: clientNameController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _buildInputDecoration(
                                hintText: 'Enter client name *',
                                icon: Icons.person_outline_rounded,
                              ),
                              readOnly: _isRecreating,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Client name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Email field (vertical layout)
                            TextFormField(
                              controller: clientEmailController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _buildInputDecoration(
                                hintText: 'client@email.com *',
                                icon: Icons.email_outlined,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              readOnly: _isRecreating,
                              onChanged: (value) {
                                setState(() {}); // Trigger rebuild to show/hide status widget
                                _onClientEmailChanged(); // Trigger email check
                              },
                              onEditingComplete: () {
                                // Trigger check immediately when user finishes editing
                                final email = clientEmailController.text.trim();
                                if (email.isNotEmpty) {
                                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                  if (emailRegex.hasMatch(email)) {
                                    setState(() {
                                      _checkingClientEmail = true;
                                    });
                                    _checkClientEmail(email);
                                  }
                                }
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Client email is required';
                                }
                                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Phone field (vertical layout)
                            TextFormField(
                              controller: clientPhoneController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _buildInputDecoration(
                                hintText: 'Phone number',
                                icon: Icons.phone_outlined,
                              ),
                              keyboardType: TextInputType.phone,
                              readOnly: _isRecreating,
                            ),
                            // Client email status and create button
                            const SizedBox(height: 12),
                            _buildClientStatusWidget(),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: clientAddressController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _buildInputDecoration(
                                hintText: 'Enter client address',
                                icon: Icons.location_on_outlined,
                              ),
                              maxLines: 2,
                              readOnly: _isRecreating,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: clientCompanyController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _buildInputDecoration(
                                hintText: 'Company name (optional)',
                                icon: Icons.business_outlined,
                              ),
                              readOnly: _isRecreating,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Agent Information Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.badge_outlined, color: Theme.of(context).primaryColor, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Agent Information',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Switch(
                                    value: hasAgent,
                                    onChanged: _isRecreating ? null : (value) {
                                      setState(() {
                                        hasAgent = value;
                                        if (!value) {
                                          // Clear agent check state when disabled
                                          _agentExists = null;
                                          _agentCheckMessage = null;
                                        } else if (agentEmailController.text.trim().isNotEmpty) {
                                          // Check email if already filled
                                          _checkAgentEmail(agentEmailController.text.trim());
                                        }
                                      });
                                    },
                                    activeColor: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Agent Available',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              if (hasAgent) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: agentNameController,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: _buildInputDecoration(
                                    hintText: 'Enter agent name *',
                                    icon: Icons.badge_outlined,
                                  ),
                                  readOnly: _isRecreating,
                                  validator: (value) {
                                    if (hasAgent && (value == null || value.trim().isEmpty)) {
                                      return 'Agent name is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Agent email field (vertical layout)
                                TextFormField(
                                  controller: agentEmailController,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: _buildInputDecoration(
                                    hintText: 'agent@email.com *',
                                    icon: Icons.email_outlined,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  readOnly: _isRecreating,
                                  onChanged: (value) {
                                    setState(() {}); // Trigger rebuild to show/hide status widget
                                    _onAgentEmailChanged(); // Trigger email check
                                  },
                                  onEditingComplete: () {
                                    // Trigger check immediately when user finishes editing
                                    if (hasAgent) {
                                      final email = agentEmailController.text.trim();
                                      if (email.isNotEmpty) {
                                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                        if (emailRegex.hasMatch(email)) {
                                          setState(() {
                                            _checkingAgentEmail = true;
                                          });
                                          _checkAgentEmail(email);
                                        }
                                      }
                                    }
                                  },
                                  validator: (value) {
                                    if (hasAgent && (value == null || value.trim().isEmpty)) {
                                      return 'Agent email is required';
                                    }
                                    if (hasAgent && value != null && value.trim().isNotEmpty) {
                                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                      if (!emailRegex.hasMatch(value.trim())) {
                                        return 'Please enter a valid email address';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Agent phone field (vertical layout)
                                TextFormField(
                                  controller: agentPhoneController,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: _buildInputDecoration(
                                    hintText: 'Phone number',
                                    icon: Icons.phone_outlined,
                                  ),
                                  keyboardType: TextInputType.phone,
                                  readOnly: _isRecreating,
                                ),
                                // Agent email status and create button
                                if (hasAgent) ...[
                                  const SizedBox(height: 12),
                                  _buildAgentStatusWidget(),
                                ],
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: agentAddressController,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: _buildInputDecoration(
                                    hintText: 'Enter agent address',
                                    icon: Icons.location_on_outlined,
                                  ),
                                  maxLines: 2,
                                  readOnly: _isRecreating,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: agentLicenseController,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: _buildInputDecoration(
                                    hintText: 'Agent license number (optional)',
                                    icon: Icons.verified_outlined,
                                  ),
                                  readOnly: _isRecreating,
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: agentAddressController,
                                style: const TextStyle(fontSize: 16),
                                decoration: _buildInputDecoration(
                                  hintText: 'Enter agent address',
                                  icon: Icons.location_on_outlined,
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: agentLicenseController,
                                style: const TextStyle(fontSize: 16),
                                decoration: _buildInputDecoration(
                                  hintText: 'Agent license number (optional)',
                                  icon: Icons.verified_outlined,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isCreating ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                          ),
                          child: _isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_circle, size: 20),
                                    SizedBox(width: 8),
                                    Text('Create Project', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


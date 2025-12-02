import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

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

  @override
  void dispose() {
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
              backgroundColor: Colors.green,
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

  Widget _buildFormField({required String label, required bool isRequired, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[600],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _buildInputDecoration({required String hintText, required IconData icon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
      prefixIcon: Icon(icon, color: Colors.blue[700], size: 20),
      filled: true,
      fillColor: Colors.grey[50],
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
        borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
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

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
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
        onTap: () => setState(() => _priority = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    required bool isRequired,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRequired && date == null ? Colors.red[300]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
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
                      color: date != null ? Colors.black87 : Colors.grey[400],
                      fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: formKey,
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
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
                  const Expanded(
                    child: Text(
                      'Create New Project',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
                              decoration: InputDecoration(
                                labelText: 'Project Title *',
                                hintText: 'Enter project title',
                                prefixIcon: const Icon(Icons.title),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                              decoration: InputDecoration(
                                labelText: 'Description *',
                                hintText: 'Enter project description',
                                prefixIcon: const Icon(Icons.description),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              maxLines: 1,
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
                              color: Colors.red,
                              icon: Icons.priority_high,
                            ),
                            const SizedBox(width: 12),
                            _buildPriorityChipModern(
                              label: 'Medium',
                              value: 'medium',
                              color: Colors.orange,
                              icon: Icons.remove_circle_outline,
                            ),
                            const SizedBox(width: 12),
                            _buildPriorityChipModern(
                              label: 'Low',
                              value: 'low',
                              color: Colors.green,
                              icon: Icons.arrow_downward,
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
                                        colorScheme: ColorScheme.light(
                                          primary: Theme.of(context).primaryColor,
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
                                        colorScheme: ColorScheme.light(
                                          primary: Theme.of(context).primaryColor,
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
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Client name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: clientEmailController,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: _buildInputDecoration(
                                      hintText: 'client@email.com *',
                                      icon: Icons.email_outlined,
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Client email is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: clientPhoneController,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: _buildInputDecoration(
                                      hintText: 'Phone number',
                                      icon: Icons.phone_outlined,
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: clientAddressController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _buildInputDecoration(
                                hintText: 'Enter client address',
                                icon: Icons.location_on_outlined,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: clientCompanyController,
                              style: const TextStyle(fontSize: 16),
                              decoration: _buildInputDecoration(
                                hintText: 'Company name (optional)',
                                icon: Icons.business_outlined,
                              ),
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
                                    onChanged: (value) => setState(() => hasAgent = value),
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
                                  validator: (value) {
                                    if (hasAgent && (value == null || value.trim().isEmpty)) {
                                      return 'Agent name is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: agentEmailController,
                                        style: const TextStyle(fontSize: 16),
                                        decoration: _buildInputDecoration(
                                          hintText: 'agent@email.com *',
                                          icon: Icons.email_outlined,
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (value) {
                                          if (hasAgent && (value == null || value.trim().isEmpty)) {
                                            return 'Agent email is required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: agentPhoneController,
                                        style: const TextStyle(fontSize: 16),
                                        decoration: _buildInputDecoration(
                                          hintText: 'Phone number',
                                          icon: Icons.phone_outlined,
                                        ),
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                  ],
                                ),
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
                            elevation: 2,
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


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/project_model.dart';
import '../../../services/api_service.dart';

class ProjectEditDialog extends StatefulWidget {
  final Project project;
  final VoidCallback onProjectUpdated;

  const ProjectEditDialog({
    Key? key,
    required this.project,
    required this.onProjectUpdated,
  }) : super(key: key);

  @override
  State<ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends State<ProjectEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _startDate;
  DateTime? _endDate;
  late String _priority;
  bool _isUpdating = false;
  bool _showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.project.title);
    _descriptionController = TextEditingController(text: widget.project.description ?? '');
    _startDate = widget.project.startDate;
    _endDate = widget.project.endDate;
    _priority = (widget.project.priority ?? 'medium').toLowerCase();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateProject() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a project title'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // Update project details
      final result = await ApiService.updateProject(
        projectId: widget.project.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        priority: _priority,
      );

      if (!mounted) return;

      if (result['success']) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Project updated successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF84BCDA),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        widget.onProjectUpdated();
      } else {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result['message'] ?? 'Failed to update project'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating project: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange[500]!,
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
                      color: Colors.orange[400]!,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Project',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.project.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // Basic Information Card
                    _buildSectionCard(
                      context,
                      title: 'Basic Information',
                      icon: Icons.info_outline,
                      child: Column(
                        children: [
                          TextField(
                            controller: _titleController,
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
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _descriptionController,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              labelText: 'Description',
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
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Priority Card
                    _buildSectionCard(
                      context,
                      title: 'Priority',
                      icon: Icons.flag_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildPriorityChip(
                                  context,
                                  label: 'High',
                                  value: 'high',
                                  selectedValue: _priority,
                                  color: Colors.red,
                                  icon: Icons.priority_high,
                                  onTap: () => setState(() => _priority = 'high'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPriorityChip(
                                  context,
                                  label: 'Medium',
                                  value: 'medium',
                                  selectedValue: _priority,
                                  color: Colors.orange,
                                  icon: Icons.remove_circle_outline,
                                  onTap: () => setState(() => _priority = 'medium'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPriorityChip(
                                  context,
                                  label: 'Low',
                                  value: 'low',
                                  selectedValue: _priority,
                                  color: const Color(0xFF84BCDA),
                                  icon: Icons.arrow_downward,
                                  onTap: () => setState(() => _priority = 'low'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Dates Card
                    _buildSectionCard(
                      context,
                      title: 'Project Timeline',
                      icon: Icons.calendar_today,
                      child: Column(
                        children: [
                          _buildDatePickerField(
                            context,
                            label: 'Start Date',
                            icon: Icons.play_circle_outline,
                            date: _startDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.orange[600]!,
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
                                setState(() => _startDate = picked);
                              }
                            },
                            onClear: () => setState(() => _startDate = null),
                          ),
                          const SizedBox(height: 16),
                          _buildDatePickerField(
                            context,
                            label: 'End Date',
                            icon: Icons.event_available,
                            date: _endDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                                firstDate: _startDate ?? DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.orange[600]!,
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
                                setState(() => _endDate = picked);
                              }
                            },
                            onClear: () => setState(() => _endDate = null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Advanced Options (Expandable)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ExpansionTile(
                        leading: Icon(Icons.tune, color: Colors.orange[600]!),
                        title: const Text(
                          'Additional Options',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('View project metadata'),
                        initiallyExpanded: _showAdvancedOptions,
                        onExpansionChanged: (expanded) {
                          setState(() => _showAdvancedOptions = expanded);
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Project ID', '#${widget.project.id}'),
                                const SizedBox(height: 12),
                                _buildInfoRow('Created', DateFormat('MMM dd, yyyy • hh:mm a').format(widget.project.createdAt)),
                                const SizedBox(height: 12),
                                _buildInfoRow('Last Updated', DateFormat('MMM dd, yyyy • hh:mm a').format(widget.project.updatedAt)),
                                const SizedBox(height: 12),
                                _buildInfoRow('Coordinator', widget.project.coordinatorName ?? widget.project.coordinatorUsername),
                                if (widget.project.assignedFieldOfficerName != null) ...[
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Field Officer', widget.project.assignedFieldOfficerName!),
                                ],
                                if (widget.project.assignedClientName != null) ...[
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Client', widget.project.assignedClientName!),
                                ],
                                if (widget.project.assignedAgentName != null) ...[
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Agent', widget.project.assignedAgentName!),
                                ],
                                const SizedBox(height: 12),
                                _buildInfoRow('Documents', '${widget.project.documentsCount} file(s)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                      onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
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
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : _updateProject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isUpdating
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
                                Icon(Icons.save, size: 20),
                                SizedBox(width: 8),
                                Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required IconData icon, required Widget child}) {
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
                Icon(icon, color: Colors.orange[600]!, size: 20),
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

  Widget _buildPriorityChip(BuildContext context, {
    required String label,
    required String value,
    required String selectedValue,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[200]! : Colors.grey[100]!,
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
    );
  }

  Widget _buildDatePickerField(BuildContext context, {
    required String label,
    required IconData icon,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange[600]!),
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
            if (date != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                color: Colors.grey[600],
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 8),
            Icon(Icons.calendar_today, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isWarning = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isWarning ? Colors.orange[700] : null,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../../services/api_service.dart';

/// Dialog for assigning a field officer to a project
class FieldOfficerAssignmentDialog extends StatelessWidget {
  final Project project;
  final Function(Project) onAssigned;

  const FieldOfficerAssignmentDialog({
    super.key,
    required this.project,
    required this.onAssigned,
  });

  Future<void> _assignFieldOfficer(BuildContext context, FieldOfficer officer) async {
    final result = await ApiService.assignFieldOfficer(
      projectId: project.id,
      fieldOfficerId: officer.id,
    );

    if (!context.mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Field officer ${officer.fullName} assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(officer);
      onAssigned(project);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to assign field officer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.getAvailableFieldOfficers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading field officers...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!['success']) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.data?['message'] ?? 'Failed to load field officers',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        final officers = (snapshot.data!['data']['field_officers'] as List<dynamic>)
            .map((o) => FieldOfficer.fromJson(o))
            .toList();

        if (officers.isEmpty) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_off, color: Colors.grey, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'No field officers available',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue[500]!,
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
                          color: Colors.lightBlue[400]!,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_outline, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Assign Field Officer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.lightBlue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.lightBlue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.lightBlue[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tap a field officer to assign. Higher project count means they are busier.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.lightBlue[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...officers.map((officer) {
                          final initials = (officer.fullName.isNotEmpty
                                  ? officer.fullName.trim().split(' ').map((p) => p[0]).take(2).join()
                                  : officer.username.substring(0, 1))
                              .toUpperCase();
                          final isAssigned = officer.id == project.assignedFieldOfficerId;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: isAssigned ? 4 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isAssigned ? const Color(0xFF84BCDA) : Colors.grey[200]!,
                                width: isAssigned ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _assignFieldOfficer(context, officer),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.lightBlue[100],
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: Colors.lightBlue[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  officer.fullName.isNotEmpty
                                                      ? officer.fullName
                                                      : officer.username,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              if (isAssigned)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF84BCDA),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: const Text(
                                                    'Assigned',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '@${officer.username}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.work_outline, size: 16, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${officer.assignedProjectsCount} ${officer.assignedProjectsCount == 1 ? 'project' : 'projects'}',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show the dialog and return the selected field officer
  static Future<FieldOfficer?> show(
    BuildContext context,
    Project project,
    Function(Project) onAssigned,
  ) {
    return showDialog<FieldOfficer>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FieldOfficerAssignmentDialog(
        project: project,
        onAssigned: onAssigned,
      ),
    );
  }
}

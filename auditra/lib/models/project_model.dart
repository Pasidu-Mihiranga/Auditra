import 'valuation_model.dart';

class Project {
  final int id;
  final String title;
  final String? description;
  final int coordinatorId;
  final String coordinatorUsername;
  final String? coordinatorName;
  final int? assignedFieldOfficerId;
  final String? assignedFieldOfficerUsername;
  final String? assignedFieldOfficerName;
  final String status;
  final String statusDisplay;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<ProjectDocument> documents;
  final int documentsCount;
  final List<Valuation> valuations;
  final int valuationsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.title,
    this.description,
    required this.coordinatorId,
    required this.coordinatorUsername,
    this.coordinatorName,
    this.assignedFieldOfficerId,
    this.assignedFieldOfficerUsername,
    this.assignedFieldOfficerName,
    required this.status,
    required this.statusDisplay,
    this.startDate,
    this.endDate,
    required this.documents,
    required this.documentsCount,
    required this.valuations,
    required this.valuationsCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse int values
    int? parseIntSafely(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
      return null;
    }

    // Parse required int fields with validation
    final id = parseIntSafely(json['id']);
    final coordinatorId = parseIntSafely(json['coordinator']);

    if (id == null) {
      throw FormatException('Required field "id" is null or cannot be parsed in Project JSON: ${json['id']}');
    }
    if (coordinatorId == null) {
      throw FormatException('Required field "coordinator" is null or cannot be parsed in Project JSON: ${json['coordinator']}');
    }

    // Parse valuations safely, skipping any that fail to parse
    List<Valuation> valuations = [];
    if (json['valuations'] != null && json['valuations'] is List) {
      for (var valJson in json['valuations']) {
        try {
          valuations.add(Valuation.fromJson(valJson));
        } catch (e) {
          print('Warning: Failed to parse valuation: $e');
          // Continue with other valuations
        }
      }
    }

    return Project(
      id: id,
      title: json['title'] ?? '',
      description: json['description'],
      coordinatorId: coordinatorId,
      coordinatorUsername: json['coordinator_username'] ?? '',
      coordinatorName: json['coordinator_name'],
      assignedFieldOfficerId: parseIntSafely(json['assigned_field_officer']),
      assignedFieldOfficerUsername: json['assigned_field_officer_username'],
      assignedFieldOfficerName: json['assigned_field_officer_name'],
      status: json['status'] ?? 'pending',
      statusDisplay: json['status_display'] ?? 'Pending',
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      documents: (json['documents'] as List<dynamic>?)
          ?.map((doc) {
            try {
              return ProjectDocument.fromJson(doc);
            } catch (e) {
              print('Warning: Failed to parse document: $e');
              return null;
            }
          })
          .whereType<ProjectDocument>()
          .toList() ?? [],
      documentsCount: parseIntSafely(json['documents_count']) ?? 0,
      valuations: valuations,
      valuationsCount: parseIntSafely(json['valuations_count']) ?? valuations.length,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  bool get isAssigned => assignedFieldOfficerId != null;
  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
}

class ProjectDocument {
  final int id;
  final int projectId;
  final String? fileUrl;
  final int? fileSize;
  final String name;
  final String? description;
  final int? uploadedById;
  final String? uploadedByUsername;
  final DateTime uploadedAt;

  ProjectDocument({
    required this.id,
    required this.projectId,
    this.fileUrl,
    this.fileSize,
    required this.name,
    this.description,
    this.uploadedById,
    this.uploadedByUsername,
    required this.uploadedAt,
  });

  factory ProjectDocument.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse int values
    int? parseIntSafely(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
      return null;
    }

    final id = parseIntSafely(json['id']);
    final projectId = parseIntSafely(json['project']);

    if (id == null) {
      throw FormatException('Required field "id" is null or cannot be parsed in ProjectDocument JSON: ${json['id']}');
    }
    if (projectId == null) {
      throw FormatException('Required field "project" is null or cannot be parsed in ProjectDocument JSON: ${json['project']}');
    }

    return ProjectDocument(
      id: id,
      projectId: projectId,
      fileUrl: json['file_url'],
      fileSize: parseIntSafely(json['file_size']),
      name: json['name'] ?? '',
      description: json['description'],
      uploadedById: parseIntSafely(json['uploaded_by']),
      uploadedByUsername: json['uploaded_by_username'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }

  String get fileSizeFormatted {
    if (fileSize == null) return 'Unknown size';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class FieldOfficer {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String fullName;
  final int assignedProjectsCount;

  FieldOfficer({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    required this.fullName,
    required this.assignedProjectsCount,
  });

  factory FieldOfficer.fromJson(Map<String, dynamic> json) {
    return FieldOfficer(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      fullName: json['full_name'] ?? json['username'],
      assignedProjectsCount: json['assigned_projects_count'] ?? 0,
    );
  }
}


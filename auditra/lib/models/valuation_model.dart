class Valuation {
  final int id;
  final int projectId;
  final String projectTitle;
  final int fieldOfficerId;
  final String fieldOfficerUsername;
  final String? fieldOfficerName;
  final String category;
  final String categoryDisplay;
  final String status;
  final String statusDisplay;
  final String? description;
  final double? estimatedValue;
  final String? notes;
  
  // Land fields
  final double? landArea;
  final String? landType;
  final String? landLocation;
  final double? landLatitude;
  final double? landLongitude;
  
  // Building fields
  final double? buildingArea;
  final String? buildingType;
  final String? buildingLocation;
  final double? buildingLatitude;
  final double? buildingLongitude;
  final int? numberOfFloors;
  final int? yearBuilt;
  
  // Vehicle fields
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleRegistrationNumber;
  final int? vehicleMileage;
  final String? vehicleCondition;
  
  // Other fields
  final String? otherType;
  final String? otherSpecifications;
  
  final List<ValuationPhoto> photos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;
  final bool canBeEdited;

  Valuation({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.fieldOfficerId,
    required this.fieldOfficerUsername,
    this.fieldOfficerName,
    required this.category,
    required this.categoryDisplay,
    required this.status,
    required this.statusDisplay,
    this.description,
    this.estimatedValue,
    this.notes,
    this.landArea,
    this.landType,
    this.landLocation,
    this.landLatitude,
    this.landLongitude,
    this.buildingArea,
    this.buildingType,
    this.buildingLocation,
    this.buildingLatitude,
    this.buildingLongitude,
    this.numberOfFloors,
    this.yearBuilt,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleRegistrationNumber,
    this.vehicleMileage,
    this.vehicleCondition,
    this.otherType,
    this.otherSpecifications,
    required this.photos,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
    this.canBeEdited = false,
  });

  factory Valuation.fromJson(Map<String, dynamic> json) {
    // Safely parse required int fields with null handling
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value);
      }
      if (value is double) {
        return value.toInt();
      }
      return null;
    }

    // Required fields - throw error if null
    final id = parseInt(json['id']);
    final projectId = parseInt(json['project']);
    final fieldOfficerId = parseInt(json['field_officer']);

    if (id == null) {
      throw FormatException('Required field "id" is null or cannot be parsed');
    }
    if (projectId == null) {
      throw FormatException('Required field "project" is null or cannot be parsed');
    }
    if (fieldOfficerId == null) {
      throw FormatException('Required field "field_officer" is null or cannot be parsed');
    }

    return Valuation(
      id: id,
      projectId: projectId,
      projectTitle: json['project_title'] ?? '',
      fieldOfficerId: fieldOfficerId,
      fieldOfficerUsername: json['field_officer_username'] ?? '',
      fieldOfficerName: json['field_officer_name'],
      category: json['category'] ?? '',
      categoryDisplay: json['category_display'] ?? '',
      status: json['status'] ?? 'draft',
      statusDisplay: json['status_display'] ?? 'Draft',
      description: json['description'],
      estimatedValue: json['estimated_value'] != null ? double.parse(json['estimated_value'].toString()) : null,
      notes: json['notes'],
      landArea: json['land_area'] != null ? double.parse(json['land_area'].toString()) : null,
      landType: json['land_type'],
      landLocation: json['land_location'],
      landLatitude: json['land_latitude'] != null 
          ? double.parse(double.parse(json['land_latitude'].toString()).toStringAsFixed(6))
          : null,
      landLongitude: json['land_longitude'] != null 
          ? double.parse(double.parse(json['land_longitude'].toString()).toStringAsFixed(6))
          : null,
      buildingArea: json['building_area'] != null ? double.parse(json['building_area'].toString()) : null,
      buildingType: json['building_type'],
      buildingLocation: json['building_location'],
      buildingLatitude: json['building_latitude'] != null 
          ? double.parse(double.parse(json['building_latitude'].toString()).toStringAsFixed(6))
          : null,
      buildingLongitude: json['building_longitude'] != null 
          ? double.parse(double.parse(json['building_longitude'].toString()).toStringAsFixed(6))
          : null,
      numberOfFloors: json['number_of_floors'],
      yearBuilt: json['year_built'],
      vehicleMake: json['vehicle_make'],
      vehicleModel: json['vehicle_model'],
      vehicleYear: json['vehicle_year'],
      vehicleRegistrationNumber: json['vehicle_registration_number'],
      vehicleMileage: json['vehicle_mileage'],
      vehicleCondition: json['vehicle_condition'],
      otherType: json['other_type'],
      otherSpecifications: json['other_specifications'],
      photos: (json['photos'] as List<dynamic>?)
          ?.map((photo) => ValuationPhoto.fromJson(photo))
          .toList() ?? [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at']) : null,
      canBeEdited: json['can_be_edited'] ?? false,
    );
  }

  bool get isDraft => status == 'draft';
  bool get isSubmitted => status == 'submitted';
}

class ValuationPhoto {
  final int id;
  final int valuationId;
  final String? photoUrl;
  final String? caption;
  final DateTime uploadedAt;

  ValuationPhoto({
    required this.id,
    required this.valuationId,
    this.photoUrl,
    this.caption,
    required this.uploadedAt,
  });

  factory ValuationPhoto.fromJson(Map<String, dynamic> json) {
    return ValuationPhoto(
      id: json['id'],
      valuationId: json['valuation'] ?? json['valuation_id'],
      photoUrl: json['photo_url'],
      caption: json['caption'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }
}


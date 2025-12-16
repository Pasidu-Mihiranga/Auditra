import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../models/project_model.dart';
import '../models/valuation_model.dart';
import '../widgets/dark_mode_toggle.dart';

class ValuationFormScreen extends StatefulWidget {
  final Project project;
  final Valuation? existingValuation;

  const ValuationFormScreen({
    super.key,
    required this.project,
    this.existingValuation,
  });

  @override
  State<ValuationFormScreen> createState() => _ValuationFormScreenState();
}

class _ValuationFormScreenState extends State<ValuationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  
  String _category = 'land';
  bool _isLoading = false;
  bool _isSubmitting = false;
  
  // Common fields
  final _descriptionController = TextEditingController();
  final _estimatedValueController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Land fields
  final _landAreaController = TextEditingController();
  final _landTypeController = TextEditingController();
  final _landLocationController = TextEditingController();
  double? _landLatitude;
  double? _landLongitude;
  
  // Building fields
  final _buildingAreaController = TextEditingController();
  final _buildingTypeController = TextEditingController();
  final _buildingLocationController = TextEditingController();
  final _numberOfFloorsController = TextEditingController();
  final _yearBuiltController = TextEditingController();
  double? _buildingLatitude;
  double? _buildingLongitude;
  
  // Vehicle fields
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleRegistrationController = TextEditingController();
  final _vehicleMileageController = TextEditingController();
  final _vehicleConditionController = TextEditingController();
  
  // Other fields
  final _otherTypeController = TextEditingController();
  final _otherSpecificationsController = TextEditingController();
  
  List<File> _selectedPhotos = [];
  List<ValuationPhoto> _existingPhotos = [];
  int? _valuationId;

  @override
  void initState() {
    super.initState();
    if (widget.existingValuation != null) {
      _loadExistingValuation(widget.existingValuation!);
    }
  }

  void _loadExistingValuation(Valuation valuation) {
    setState(() {
      _valuationId = valuation.id;
      _category = valuation.category;
      _descriptionController.text = valuation.description ?? '';
      _estimatedValueController.text = valuation.estimatedValue?.toString() ?? '';
      _notesController.text = valuation.notes ?? '';
      
      // Land fields
      _landAreaController.text = valuation.landArea?.toString() ?? '';
      _landTypeController.text = valuation.landType ?? '';
      _landLocationController.text = valuation.landLocation ?? '';
      // Round to 6 decimal places when loading
      if (valuation.landLatitude != null) {
        _landLatitude = double.parse(valuation.landLatitude!.toStringAsFixed(6));
      }
      if (valuation.landLongitude != null) {
        _landLongitude = double.parse(valuation.landLongitude!.toStringAsFixed(6));
      }
      // Update location text if coordinates exist
      if (_landLatitude != null && _landLongitude != null) {
        _landLocationController.text = '$_landLatitude, $_landLongitude';
      }
      
      // Building fields
      _buildingAreaController.text = valuation.buildingArea?.toString() ?? '';
      _buildingTypeController.text = valuation.buildingType ?? '';
      _buildingLocationController.text = valuation.buildingLocation ?? '';
      _numberOfFloorsController.text = valuation.numberOfFloors?.toString() ?? '';
      _yearBuiltController.text = valuation.yearBuilt?.toString() ?? '';
      // Round to 6 decimal places when loading
      if (valuation.buildingLatitude != null) {
        _buildingLatitude = double.parse(valuation.buildingLatitude!.toStringAsFixed(6));
      }
      if (valuation.buildingLongitude != null) {
        _buildingLongitude = double.parse(valuation.buildingLongitude!.toStringAsFixed(6));
      }
      // Update location text if coordinates exist
      if (_buildingLatitude != null && _buildingLongitude != null) {
        _buildingLocationController.text = '$_buildingLatitude, $_buildingLongitude';
      }
      
      // Vehicle fields
      _vehicleMakeController.text = valuation.vehicleMake ?? '';
      _vehicleModelController.text = valuation.vehicleModel ?? '';
      _vehicleYearController.text = valuation.vehicleYear?.toString() ?? '';
      _vehicleRegistrationController.text = valuation.vehicleRegistrationNumber ?? '';
      _vehicleMileageController.text = valuation.vehicleMileage?.toString() ?? '';
      _vehicleConditionController.text = valuation.vehicleCondition ?? '';
      
      // Other fields
      _otherTypeController.text = valuation.otherType ?? '';
      _otherSpecificationsController.text = valuation.otherSpecifications ?? '';
      
      _existingPhotos = valuation.photos;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _estimatedValueController.dispose();
    _notesController.dispose();
    _landAreaController.dispose();
    _landTypeController.dispose();
    _landLocationController.dispose();
    _buildingAreaController.dispose();
    _buildingTypeController.dispose();
    _buildingLocationController.dispose();
    _numberOfFloorsController.dispose();
    _yearBuiltController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleRegistrationController.dispose();
    _vehicleMileageController.dispose();
    _vehicleConditionController.dispose();
    _otherTypeController.dispose();
    _otherSpecificationsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedPhotos.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedPhotos.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }

      setState(() => _isLoading = true);

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Round to 6 decimal places to match backend DecimalField(max_digits=9, decimal_places=6)
      final roundedLat = double.parse(position.latitude.toStringAsFixed(6));
      final roundedLng = double.parse(position.longitude.toStringAsFixed(6));
      
      // Create Google Maps link
      final googleMapsUrl = 'https://www.google.com/maps?q=$roundedLat,$roundedLng';
      final locationText = '$roundedLat, $roundedLng';

      setState(() {
        if (_category == 'land') {
          _landLatitude = roundedLat;
          _landLongitude = roundedLng;
          _landLocationController.text = locationText;
        } else if (_category == 'building') {
          _buildingLatitude = roundedLat;
          _buildingLongitude = roundedLng;
          _buildingLocationController.text = locationText;
        }
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(child: Text('Location captured successfully!')),
                TextButton(
                  onPressed: () async {
                    final url = Uri.parse(googleMapsUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open: $googleMapsUrl')),
                        );
                      }
                    }
                  },
                  child: const Text('View Map', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _saveValuation({bool submit = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Helper function to clean empty strings to null
      String? cleanString(String? value) {
        if (value == null || value.trim().isEmpty) return null;
        return value.trim();
      }

      Map<String, dynamic> data = {
        'project': widget.project.id,
        'category': _category,
      };

      // Add common fields (only if not empty)
      final description = cleanString(_descriptionController.text);
      if (description != null) data['description'] = description;

      if (_estimatedValueController.text.isNotEmpty) {
        final estimatedValue = double.tryParse(_estimatedValueController.text);
        if (estimatedValue != null) data['estimated_value'] = estimatedValue;
      }

      final notes = cleanString(_notesController.text);
      if (notes != null) data['notes'] = notes;

      // Add category-specific fields
      if (_category == 'land') {
        if (_landAreaController.text.isNotEmpty) {
          final landArea = double.tryParse(_landAreaController.text);
          if (landArea != null) data['land_area'] = landArea;
        }
        final landType = cleanString(_landTypeController.text);
        if (landType != null) data['land_type'] = landType;
        final landLocation = cleanString(_landLocationController.text);
        if (landLocation != null) data['land_location'] = landLocation;
        if (_landLatitude != null) {
          // Ensure exactly 6 decimal places
          data['land_latitude'] = double.parse(_landLatitude!.toStringAsFixed(6));
        }
        if (_landLongitude != null) {
          // Ensure exactly 6 decimal places
          data['land_longitude'] = double.parse(_landLongitude!.toStringAsFixed(6));
        }
      } else if (_category == 'building') {
        if (_buildingAreaController.text.isNotEmpty) {
          final buildingArea = double.tryParse(_buildingAreaController.text);
          if (buildingArea != null) data['building_area'] = buildingArea;
        }
        final buildingType = cleanString(_buildingTypeController.text);
        if (buildingType != null) data['building_type'] = buildingType;
        final buildingLocation = cleanString(_buildingLocationController.text);
        if (buildingLocation != null) data['building_location'] = buildingLocation;
        if (_buildingLatitude != null) {
          // Ensure exactly 6 decimal places
          data['building_latitude'] = double.parse(_buildingLatitude!.toStringAsFixed(6));
        }
        if (_buildingLongitude != null) {
          // Ensure exactly 6 decimal places
          data['building_longitude'] = double.parse(_buildingLongitude!.toStringAsFixed(6));
        }
        if (_numberOfFloorsController.text.isNotEmpty) {
          final floors = int.tryParse(_numberOfFloorsController.text);
          if (floors != null) data['number_of_floors'] = floors;
        }
        if (_yearBuiltController.text.isNotEmpty) {
          final year = int.tryParse(_yearBuiltController.text);
          if (year != null) data['year_built'] = year;
        }
      } else if (_category == 'vehicle') {
        final vehicleMake = cleanString(_vehicleMakeController.text);
        if (vehicleMake != null) data['vehicle_make'] = vehicleMake;
        final vehicleModel = cleanString(_vehicleModelController.text);
        if (vehicleModel != null) data['vehicle_model'] = vehicleModel;
        if (_vehicleYearController.text.isNotEmpty) {
          final year = int.tryParse(_vehicleYearController.text);
          if (year != null) data['vehicle_year'] = year;
        }
        final regNumber = cleanString(_vehicleRegistrationController.text);
        if (regNumber != null) data['vehicle_registration_number'] = regNumber;
        if (_vehicleMileageController.text.isNotEmpty) {
          final mileage = int.tryParse(_vehicleMileageController.text);
          if (mileage != null) data['vehicle_mileage'] = mileage;
        }
        final condition = cleanString(_vehicleConditionController.text);
        if (condition != null) data['vehicle_condition'] = condition;
      } else if (_category == 'other') {
        final otherType = cleanString(_otherTypeController.text);
        if (otherType != null) data['other_type'] = otherType;
        final otherSpecs = cleanString(_otherSpecificationsController.text);
        if (otherSpecs != null) data['other_specifications'] = otherSpecs;
      }

      // Debug: Print data being sent
      print('Sending valuation data: $data');

      Map<String, dynamic> result;
      if (_valuationId != null) {
        result = await ApiService.updateValuation(_valuationId!, data);
      } else {
        result = await ApiService.createValuation(data);
      }

      if (result['success']) {
        final valuationData = result['data'];
        
        // Debug: Print the response data
        print('Valuation creation response: $valuationData');
        print('Response type: ${valuationData.runtimeType}');
        
        // Safely get the valuation ID
        int? newValuationId;
        
        try {
          if (valuationData != null && valuationData is Map<String, dynamic>) {
            final idValue = valuationData['id'];
            print('ID value: $idValue, type: ${idValue?.runtimeType}');
            
            if (idValue != null) {
              if (idValue is int) {
                newValuationId = idValue;
              } else if (idValue is String) {
                newValuationId = int.tryParse(idValue);
              } else if (idValue is double) {
                newValuationId = idValue.toInt();
              } else if (idValue is num) {
                newValuationId = idValue.toInt();
              }
            } else {
              print('Warning: ID field is null in response');
              // Try to fetch the valuation by project and category as fallback
              // This is a workaround if backend doesn't return ID
              print('Response keys: ${valuationData.keys.toList()}');
            }
          } else if (valuationData is int) {
            // If the response is just an ID
            newValuationId = valuationData;
          }
        } catch (e) {
          print('Error parsing valuation ID: $e');
        }
        
        // Fallback to existing ID if new ID is null
        newValuationId ??= _valuationId;
        
        if (newValuationId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Error: Could not get valuation ID from response. The valuation may have been created but we cannot proceed with photos. Please refresh and try again.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 7),
                action: SnackBarAction(
                  label: 'Details',
                  textColor: Colors.white,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Response Details'),
                        content: SingleChildScrollView(
                          child: Text('Response: $valuationData'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          }
          // Don't return - still show success message but warn about photos
          if (mounted && !submit) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Valuation saved, but ID not received. Photos may not upload.'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.of(context).pop(true);
          }
          return;
        }
        
        print('Using valuation ID: $newValuationId');
        
        // Upload photos
        for (var photo in _selectedPhotos) {
          try {
            await ApiService.uploadValuationPhoto(newValuationId, photo.path);
          } catch (e) {
            print('Error uploading photo: $e');
            // Continue with other photos even if one fails
          }
        }

        // Submit if requested
        if (submit) {
          final submitResult = await ApiService.submitValuation(newValuationId);
          if (submitResult['success']) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Valuation submitted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop(true);
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(submitResult['message'] ?? 'Failed to submit valuation'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Valuation saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            if (submit) {
              Navigator.of(context).pop(true);
            }
          }
        }
      } else {
        if (mounted) {
          // Show detailed error message
          final errorMsg = result['message'] ?? 'Failed to save valuation';
          print('Valuation save error: $errorMsg');
          print('Full result: $result');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Details',
                textColor: Colors.white,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Error Details'),
                      content: SingleChildScrollView(
                        child: Text(errorMsg),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Exception in _saveValuation: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        String errorMessage = 'Error: $e';
        if (e.toString().contains('Null') && e.toString().contains('int')) {
          errorMessage = 'Server response is missing required data. Please try again or contact support.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Error Details'),
                    content: SingleChildScrollView(
                      child: Text('$e\n\n$stackTrace'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deletePhoto(ValuationPhoto photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ApiService.deleteValuationPhoto(photo.id);
      if (result['success']) {
        setState(() {
          _existingPhotos.removeWhere((p) => p.id == photo.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to delete photo')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if project is assigned to current user
    if (!widget.project.isAssigned) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('New Valuation'),
          actions: const [
            DarkModeToggle(),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Project Not Assigned',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This project has not been assigned to a field officer yet.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingValuation != null ? 'Edit Valuation' : 'New Valuation'),
        actions: const [
          DarkModeToggle(),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Project Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project: ${widget.project.title}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.project.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.project.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Show edit status banner if editing submitted valuation
            if (widget.existingValuation != null && widget.existingValuation!.status == 'submitted') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.existingValuation!.canBeEdited 
                      ? Colors.orange[50] 
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.existingValuation!.canBeEdited 
                        ? Colors.orange[300]! 
                        : Colors.red[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.existingValuation!.canBeEdited 
                          ? Icons.info_outline 
                          : Icons.error_outline,
                      color: widget.existingValuation!.canBeEdited 
                          ? Colors.orange[900] 
                          : Colors.red[900],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.existingValuation!.canBeEdited
                            ? 'This valuation was submitted. You can edit it within 2 hours of submission. Editing will reset it to draft status.'
                            : 'This valuation was submitted more than 2 hours ago and cannot be edited.',
                        style: TextStyle(
                          color: widget.existingValuation!.canBeEdited 
                              ? Colors.orange[900] 
                              : Colors.red[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            
            // Category Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category *',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildCategoryChip('land', 'Land', Icons.landscape),
                        _buildCategoryChip('building', 'Building', Icons.business),
                        _buildCategoryChip('vehicle', 'Vehicle', Icons.directions_car),
                        _buildCategoryChip('other', 'Other', Icons.category),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Common Fields
            _buildSectionTitle('Common Information'),
            _buildTextField(_descriptionController, 'Description', maxLines: 3),
            _buildTextField(_estimatedValueController, 'Estimated Value', keyboardType: TextInputType.number),
            _buildTextField(_notesController, 'Notes', maxLines: 3),
            const SizedBox(height: 16),
            
            // Category-specific fields
            if (_category == 'land') _buildLandFields(),
            if (_category == 'building') _buildBuildingFields(),
            if (_category == 'vehicle') _buildVehicleFields(),
            if (_category == 'other') _buildOtherFields(),
            
            const SizedBox(height: 16),
            
            // Photos Section
            _buildSectionTitle('Photos'),
            _buildPhotosSection(),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => _saveValuation(submit: false),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Draft'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _saveValuation(submit: true),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String value, String label, IconData icon) {
    final isSelected = _category == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() => _category = value);
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildLandFields() {
    final hasLocation = _landLatitude != null && _landLongitude != null;
    final googleMapsUrl = hasLocation 
        ? 'https://www.google.com/maps?q=$_landLatitude,$_landLongitude'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Land Details'),
        _buildTextField(_landAreaController, 'Area (sq meters)', keyboardType: TextInputType.number),
        _buildTextField(_landTypeController, 'Land Type (e.g., Residential, Commercial)'),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _landLocationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getCurrentLocation,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.location_on),
              label: const Text('Get Location'),
            ),
          ],
        ),
        if (hasLocation && googleMapsUrl != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse(googleMapsUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open Google Maps')),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.map, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View on Google Maps',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Icon(Icons.open_in_new, color: Colors.blue[700], size: 18),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBuildingFields() {
    final hasLocation = _buildingLatitude != null && _buildingLongitude != null;
    final googleMapsUrl = hasLocation 
        ? 'https://www.google.com/maps?q=$_buildingLatitude,$_buildingLongitude'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Building Details'),
        _buildTextField(_buildingAreaController, 'Area (sq meters)', keyboardType: TextInputType.number),
        _buildTextField(_buildingTypeController, 'Building Type (e.g., House, Apartment)'),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _buildingLocationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getCurrentLocation,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.location_on),
              label: const Text('Get Location'),
            ),
          ],
        ),
        if (hasLocation && googleMapsUrl != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse(googleMapsUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open Google Maps')),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.map, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View on Google Maps',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Icon(Icons.open_in_new, color: Colors.blue[700], size: 18),
                ],
              ),
            ),
          ),
        ],
        _buildTextField(_numberOfFloorsController, 'Number of Floors', keyboardType: TextInputType.number),
        _buildTextField(_yearBuiltController, 'Year Built', keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildVehicleFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Vehicle Details'),
        _buildTextField(_vehicleMakeController, 'Make'),
        _buildTextField(_vehicleModelController, 'Model'),
        _buildTextField(_vehicleYearController, 'Year', keyboardType: TextInputType.number),
        _buildTextField(_vehicleRegistrationController, 'Registration Number'),
        _buildTextField(_vehicleMileageController, 'Mileage', keyboardType: TextInputType.number),
        _buildTextField(_vehicleConditionController, 'Condition (e.g., Excellent, Good, Fair)'),
      ],
    );
  }

  Widget _buildOtherFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Other Details'),
        _buildTextField(_otherTypeController, 'Type'),
        _buildTextField(_otherSpecificationsController, 'Specifications', maxLines: 3),
      ],
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick from Gallery'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_existingPhotos.isNotEmpty || _selectedPhotos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._existingPhotos.map((photo) => _buildPhotoThumbnail(
                photoUrl: photo.photoUrl,
                onDelete: () => _deletePhoto(photo),
              )),
              ..._selectedPhotos.map((photo) => _buildPhotoThumbnail(
                photoFile: photo,
                onDelete: () {
                  setState(() => _selectedPhotos.remove(photo));
                },
              )),
            ],
          ),
      ],
    );
  }

  Widget _buildPhotoThumbnail({String? photoUrl, File? photoFile, required VoidCallback onDelete}) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: photoFile != null
                ? Image.file(photoFile, fit: BoxFit.cover)
                : photoUrl != null
                    ? Image.network(photoUrl, fit: BoxFit.cover)
                    : const Icon(Icons.image),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.red,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close, size: 16, color: Colors.white),
              onPressed: onDelete,
            ),
          ),
        ),
      ],
    );
  }
}


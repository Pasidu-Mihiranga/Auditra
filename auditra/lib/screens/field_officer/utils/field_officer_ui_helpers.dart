
import 'package:flutter/material.dart';
import '../../../../models/valuation_model.dart';

class FieldOfficerUiHelpers {
  /// Get color for valuation status
  static Color getValuationStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'submitted':
      case 'pending':
        return Colors.orange;
      case 'draft':
      default:
        return Colors.blue;
    }
  }

  /// Check if a valuation can be edited (created within 2 days)
  static bool canEditValuation(Valuation valuation) {
    final now = DateTime.now();
    final createdAt = valuation.createdAt;
    final difference = now.difference(createdAt);
    
    // Allow editing if created within 2 days (48 hours)
    return difference.inDays < 2;
  }

  /// Check if a valuation can be deleted (created within 2 days)
  static bool canDeleteValuation(Valuation valuation) {
    final now = DateTime.now();
    final createdAt = valuation.createdAt;
    final difference = now.difference(createdAt);
    
    // Allow deletion if created within 2 days (48 hours)
    return difference.inDays < 2;
  }
}

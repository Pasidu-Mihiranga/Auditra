import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/project_model.dart';
import '../../../models/valuation_model.dart';
import '../../../services/api_service.dart';
import '../../../services/pdf_service.dart';

/// Document management for Coordinator Dashboard
/// Handles document uploads and PDF report generation
class CoordinatorDocumentManager {
  
  /// Upload a document for a project
  static Future<void> uploadDocument(
    BuildContext context,
    Project project,
    VoidCallback onUpdate,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final filePathNullable = file.path;
        if (filePathNullable == null || filePathNullable.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to get file path'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        final filePath = filePathNullable; // Now guaranteed non-null
        final fileName = (file.name.isNotEmpty) ? file.name : 'document';

        final uploadResult = await ApiService.uploadProjectDocument(
          projectId: project.id,
          filePath: filePath,
          fileName: fileName,
        );

        if (!context.mounted) return;

        if (uploadResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully!')),
          );
          onUpdate();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(uploadResult['message'] ?? 'Failed to upload document')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Generate PDF report for a valuation
  static Future<void> generatePdfReport(
    BuildContext context,
    Valuation valuation,
    Project project,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF report...'),
                ],
              ),
            ),
          ),
        ),
      );

      final pdfFile = await PdfService.generateValuationReport(
        valuation: valuation,
        project: project,
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Share/Print the PDF
      if (context.mounted) {
        try {
          await PdfService.sharePdf(
            pdfFile,
            subject: 'Valuation Report - ${valuation.categoryDisplay}',
          );
        } catch (shareError) {
          print('Error sharing PDF: $shareError');
          // Try alternative method
          if (context.mounted) {
            await PdfService.saveAndOpenPdf(pdfFile);
          }
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report generated successfully!'),
            backgroundColor: Color(0xFF84BCDA),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

import 'package:flutter/material.dart';
import '../../../models/project_model.dart';
import '../../../models/valuation_model.dart';
import '../../../services/pdf_service.dart';

class ProjectReportHandler {
  static Future<void> generatePdfReport(BuildContext context, Valuation valuation, Project project) async {
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
          debugPrint('Error sharing PDF: $shareError');
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

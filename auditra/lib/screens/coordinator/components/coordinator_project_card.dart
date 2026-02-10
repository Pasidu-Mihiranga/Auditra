import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' show ImageFilter;
import '../../../models/project_model.dart';
import '../styles/coordinator_styles.dart';
import 'coordinator_actions.dart';

class CoordinatorProjectCard extends StatelessWidget {
  final Project project;
  final bool isReceivedTab;
  final bool isCancelledTab;
  final Function(Project) onViewDetails;
  final Function(Project) onUploadDocuments;
  final Function(Project) onViewStatus;
  final Function(Project) onEdit;
  final Function(Project) onDelete;
  final Function(Project) onStart;
  final Function(Project) onCancel;
  final Function(Project) onComplete;

  const CoordinatorProjectCard({
    super.key,
    required this.project,
    this.isReceivedTab = false,
    this.isCancelledTab = false,
    required this.onViewDetails,
    required this.onUploadDocuments,
    required this.onViewStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
    required this.onCancel,
    required this.onComplete,
  });



  @override
  Widget build(BuildContext context) {
    final isPending = project.status.toLowerCase() == 'pending';
    final isOngoing = project.status.toLowerCase() == 'in_progress';
    final priority = project.priority ?? 'medium';
    
    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    // Responsive sizes
    final titleFontSize = isSmallScreen ? 13.0 : isMediumScreen ? 14.0 : 15.0;
    final descFontSize = isSmallScreen ? 12.0 : isMediumScreen ? 13.0 : 14.0;
    final dateFontSize = isSmallScreen ? 11.0 : isMediumScreen ? 12.0 : 13.0;
    final iconSize = isSmallScreen ? 14.0 : isMediumScreen ? 16.0 : 18.0;
    final buttonIconSize = isSmallScreen ? 28.0 : isMediumScreen ? 32.0 : 36.0;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onViewDetails(project),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: EdgeInsets.only(bottom: isReceivedTab ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                   filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                   child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spacing for priority label
                const SizedBox(height: 28),
                // Top row: project name + status aligned with edit/delete icons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Project name and status on left
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              project.title,
                              style: TextStyle(
                                fontFamily: 'Calibri',
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Attachment, Edit & Delete buttons aligned with title - Modern Design
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: buttonIconSize,
                          height: buttonIconSize,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE0F2F1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => onUploadDocuments(project),
                            icon: Icon(Icons.attach_file, size: iconSize),
                            color: const Color(0xFF00897B),
                            padding: EdgeInsets.zero,
                            tooltip: 'Documents',
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 4 : 6),
                        // Status icon button (only for ongoing projects)
                        if (isOngoing) ...[
                          Container(
                            width: buttonIconSize,
                            height: buttonIconSize,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE3F2FD),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: () => onViewStatus(project),
                              icon: Icon(Icons.account_tree, size: iconSize),
                              color: const Color(0xFF1976D2),
                              padding: EdgeInsets.zero,
                              tooltip: 'View/Update Status',
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 4 : 6),
                        ],
                        Container(
                          width: buttonIconSize,
                          height: buttonIconSize,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF3E0),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => onEdit(project),
                            icon: Icon(Icons.edit_outlined, size: iconSize),
                            color: const Color(0xFFF57C00),
                            padding: EdgeInsets.zero,
                            tooltip: 'Edit Project',
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 4 : 6),
                        Container(
                          width: buttonIconSize,
                          height: buttonIconSize,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => onDelete(project),
                            icon: Icon(Icons.delete_outline, size: iconSize),
                            color: const Color(0xFFD32F2F),
                            padding: EdgeInsets.zero,
                            tooltip: 'Delete Project',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Description row with Cancel and Start buttons (for pending projects) or Cancel button (for ongoing projects)
                if (project.description != null || isPending || isOngoing) ...[
                  SizedBox(height: isReceivedTab ? 4 : 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Description section
                      if (project.description != null)
                        Expanded(
                          child: Text(
                            project.description!,
                            maxLines: isSmallScreen ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Calibri',
                              fontSize: descFontSize,
                              color: Colors.black87,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ),
                      // Spacer to push buttons to the right when there's no description
                      if (project.description == null && !isPending && isOngoing)
                        const Spacer(),
                      // Cancel and Start buttons (for pending projects)
                      if (isPending) ...[
                        if (project.description != null)
                          SizedBox(width: isSmallScreen ? 4 : 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HoverableStartButton(
                              canStart: CoordinatorActions.canStartProject(project),
                              onPressed: () => onStart(project),
                            ),
                            SizedBox(width: isSmallScreen ? 2 : 4),
                            _HoverableCancelButton(
                              onPressed: () => onCancel(project),
                            ),
                          ],
                        ),
                      ],
                      // Cancel and Complete buttons for ongoing projects (parallel with description) - MUST appear before contact button
                      if (isOngoing && !isPending) ...[
                        if (project.description != null)
                          SizedBox(width: isSmallScreen ? 4 : 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HoverableCompleteButton(
                              onPressed: () => onComplete(project),
                            ),
                            SizedBox(width: isSmallScreen ? 2 : 4),
                            _HoverableCancelButton(
                              onPressed: () => onCancel(project),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
                // Date row
                SizedBox(height: isReceivedTab ? 4 : 8),
                if (project.startDate != null || project.endDate != null)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (project.startDate != null) ...[
                        Icon(Icons.calendar_today, size: dateFontSize - 1, color: Colors.grey[600]),
                        const SizedBox(width: 2),
                        Text(
                          isSmallScreen 
                            ? DateFormat('MMM dd').format(project.startDate!)
                            : DateFormat('MMM dd, yyyy').format(project.startDate!),
                          style: TextStyle(
                            fontFamily: 'Calibri',
                            fontSize: dateFontSize,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (project.startDate != null && project.endDate != null)
                        Text(' - ', style: TextStyle(fontSize: dateFontSize, color: Colors.grey[400])),
                      if (project.endDate != null) ...[
                        Text(
                          isSmallScreen 
                            ? DateFormat('MMM dd').format(project.endDate!)
                            : DateFormat('MMM dd, yyyy').format(project.endDate!),
                          style: TextStyle(
                            fontFamily: 'Calibri',
                            fontSize: dateFontSize,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
                   ),
                ),
              ),
            ),
          ),
        ),
        // Priority Badge at top-left
        Positioned(
          left: 16,
          top: -12, // Move up to overflow
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: CoordinatorStyles.getPriorityColor(priority),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: CoordinatorStyles.getPriorityColor(priority).withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 12,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                Text(
                  CoordinatorStyles.formatPriorityLabel(priority),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }



  }


class _HoverableStartButton extends StatefulWidget {
  final bool canStart;
  final VoidCallback onPressed;

  const _HoverableStartButton({
    required this.canStart,
    required this.onPressed,
  });

  @override
  State<_HoverableStartButton> createState() => _HoverableStartButtonState();
}

class _HoverableStartButtonState extends State<_HoverableStartButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Always use green theme for start button
    final backgroundColor = const Color(0xFF0570B0);
    final foregroundColor = Colors.white;
    
    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final fontSize = isSmallScreen ? 9.0 : isMediumScreen ? 10.0 : 11.0;
    final buttonWidth = isSmallScreen ? 55.0 : isMediumScreen ? 62.0 : 70.0;
    final buttonHeight = isSmallScreen ? 24.0 : isMediumScreen ? 26.0 : 28.0;
    final horizontalPadding = isSmallScreen ? 8.0 : isMediumScreen ? 10.0 : 12.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        child: Text(
          'Start',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            fontFamily: 'Calibri',
            color: foregroundColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor,
          disabledForegroundColor: foregroundColor,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          fixedSize: Size(buttonWidth, buttonHeight),
          elevation: _isHovered ? 3 : 2,
          shadowColor: Colors.grey[400]!,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
    );
  }
}

class _HoverableCancelButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _HoverableCancelButton({
    required this.onPressed,
  });

  @override
  State<_HoverableCancelButton> createState() => _HoverableCancelButtonState();
}

class _HoverableCancelButtonState extends State<_HoverableCancelButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Red theme for cancel button
    final backgroundColor = _isHovered ? Colors.red[700]! : Colors.red[600]!;
    final foregroundColor = Colors.white;
    
    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final fontSize = isSmallScreen ? 8.0 : isMediumScreen ? 9.0 : 10.0;
    final buttonWidth = isSmallScreen ? 50.0 : isMediumScreen ? 55.0 : 60.0;
    final buttonHeight = isSmallScreen ? 20.0 : isMediumScreen ? 22.0 : 24.0;
    final horizontalPadding = isSmallScreen ? 6.0 : isMediumScreen ? 7.0 : 8.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        child: Text(
          'Cancel',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            fontFamily: 'Calibri',
            color: foregroundColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          fixedSize: Size(buttonWidth, buttonHeight),
          elevation: _isHovered ? 3 : 2,
          shadowColor: Colors.grey[400]!,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
    );
  }
}

class _HoverableCompleteButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _HoverableCompleteButton({
    required this.onPressed,
  });

  @override
  State<_HoverableCompleteButton> createState() => _HoverableCompleteButtonState();
}

class _HoverableCompleteButtonState extends State<_HoverableCompleteButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Teal/green theme for complete button
    final backgroundColor = const Color(0xFF0570B0);
    final foregroundColor = Colors.white;
    
    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final fontSize = isSmallScreen ? 8.0 : isMediumScreen ? 9.0 : 10.0;
    final buttonWidth = isSmallScreen ? 60.0 : isMediumScreen ? 65.0 : 70.0;
    final buttonHeight = isSmallScreen ? 20.0 : isMediumScreen ? 22.0 : 24.0;
    final horizontalPadding = isSmallScreen ? 6.0 : isMediumScreen ? 7.0 : 8.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ElevatedButton(
        onPressed: widget.onPressed,
        child: Text(
          'Complete',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            fontFamily: 'Calibri',
            color: foregroundColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          fixedSize: Size(buttonWidth, buttonHeight),
          elevation: _isHovered ? 3 : 2,
          shadowColor: Colors.grey[400]!,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../../models/project_model.dart';
import 'coordinator_project_card.dart';

class CoordinatorProjectList extends StatefulWidget {
  final List<Project> projects;
  final String emptyTitle;
  final String emptySubtitle;
  final bool isReceivedTab;
  final bool isCancelledTab;
  // Search & Sort dependencies
  final TextEditingController searchController;
  final String currentSortOption;
  final Function(String) onSortChanged;
  // Card Callbacks
  final Function(Project) onViewDetails;
  final Function(Project) onUploadDocuments;
  final Function(Project) onViewStatus;
  final Function(Project) onEdit;
  final Function(Project) onDelete;
  final Function(Project) onStart;
  final Function(Project) onCancel;
  final Function(Project) onComplete;
  // Optional header widget (e.g., Create Project button)
  final Widget? headerWidget;

  const CoordinatorProjectList({
    super.key,
    required this.projects,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.isReceivedTab = false,
    this.isCancelledTab = false,
    required this.searchController,
    required this.currentSortOption,
    required this.onSortChanged,
    required this.onViewDetails,
    required this.onUploadDocuments,
    required this.onViewStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
    required this.onCancel,
    required this.onComplete,
    this.headerWidget,
  });

  @override
  State<CoordinatorProjectList> createState() => _CoordinatorProjectListState();
}

class _CoordinatorProjectListState extends State<CoordinatorProjectList> {
  // Sort options labels
  final Map<String, String> _sortLabels = {
    'date_asc': 'Date (Oldest)',
    'date_desc': 'Date (Newest)',
    'title_asc': 'Name (A-Z)',
    'title_desc': 'Name (Z-A)',
    'priority': 'Priority (High-Low)',
  };

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    // Responsive sizes
    final searchFontSize = isSmallScreen ? 12.0 : isMediumScreen ? 13.0 : 14.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final sortFontSize = isSmallScreen ? 11.0 : isMediumScreen ? 12.0 : 13.0;
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    final sortPadding = isSmallScreen ? 10.0 : isMediumScreen ? 12.0 : 16.0;
    
    return Stack(
      children: [
        // Project list - scrollable content
        Padding(
          padding: const EdgeInsets.only(top: 70), // Space for search bar
          child: widget.projects.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate responsive sizes based on available height
                    final availableHeight = constraints.maxHeight;
                    final iconSize = availableHeight < 150 
                        ? (availableHeight * 0.3).clamp(32.0, 64.0)
                        : 64.0;
                    final titleFontSize = availableHeight < 150 
                        ? 14.0 
                        : 18.0;
                    final spacing = availableHeight < 150 ? 8.0 : 16.0;
                    final smallSpacing = availableHeight < 150 ? 4.0 : 8.0;
                    
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_open, size: iconSize, color: Colors.grey[400]),
                                SizedBox(height: spacing),
                                Text(
                                  widget.emptyTitle,
                                  style: TextStyle(
                                    fontSize: titleFontSize, 
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: smallSpacing),
                                Text(
                                  widget.emptySubtitle,
                                  style: TextStyle(
                                    fontSize: availableHeight < 150 ? 12.0 : 14.0,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Optional header widget (e.g., Create Project button)
                    if (widget.headerWidget != null)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(horizontalPadding, horizontalPadding, horizontalPadding, 8),
                        sliver: SliverToBoxAdapter(
                          child: widget.headerWidget!,
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.all(horizontalPadding),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => CoordinatorProjectCard(
                            project: widget.projects[index],
                            isReceivedTab: widget.isReceivedTab,
                            isCancelledTab: widget.isCancelledTab,
                            onViewDetails: widget.onViewDetails,
                            onUploadDocuments: widget.onUploadDocuments,
                            onViewStatus: widget.onViewStatus,
                            onEdit: widget.onEdit,
                            onDelete: widget.onDelete,
                            onStart: widget.onStart,
                            onCancel: widget.onCancel,
                            onComplete: widget.onComplete,
                          ),
                          childCount: widget.projects.length,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        // Search and Sort Bar - Overlay with Frosted Glass
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
                child: Row(
                  children: [
              // Search field
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: widget.searchController,
                        style: TextStyle(
                          fontFamily: 'Etna Sans Serif',
                          fontSize: searchFontSize,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: isSmallScreen ? 'Search...' : 'Search projects...',
                          hintStyle: TextStyle(
                            fontFamily: 'Etna Sans Serif',
                            color: Colors.grey[400],
                            fontSize: searchFontSize,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(Icons.search_rounded, size: iconSize, color: const Color(0xFF10B981)),
                          suffixIcon: widget.searchController.text.isNotEmpty == true
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded, size: iconSize - 2, color: Colors.grey[500]),
                                  onPressed: () {
                                    widget.searchController.clear();
                                  },
                                )
                              : null,
                          filled: false,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12 : 16,
                            vertical: isSmallScreen ? 12 : 14,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              // Sort dropdown with frosted glass
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: sortPadding, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.currentSortOption,
                        icon: Icon(Icons.sort_rounded, size: iconSize, color: const Color(0xFF10B981)),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        style: TextStyle(
                          fontFamily: 'Etna Sans Serif',
                          color: Colors.black87,
                          fontSize: sortFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        items: _sortLabels.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            widget.onSortChanged(newValue);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

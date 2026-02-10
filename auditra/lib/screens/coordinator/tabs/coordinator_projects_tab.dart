
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import '../../../models/project_model.dart';
import '../components/coordinator_project_list.dart';

class CoordinatorProjectsTab extends StatefulWidget {
  final TabController tabController;
  final List<Project> projects;
  final Future<void> Function() onRefresh;
  final Function(Project) onViewDetails;
  final Function(Project) onUploadDocuments;
  final Function(Project) onViewStatus;
  final Function(Project) onEdit;
  final Function(Project) onDelete;
  final Function(Project) onStart;
  final Function(Project) onCancel;
  final Function(Project) onComplete;

  const CoordinatorProjectsTab({
    Key? key,
    required this.tabController,
    required this.projects,
    required this.onRefresh,
    required this.onViewDetails,
    required this.onUploadDocuments,
    required this.onViewStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onStart,
    required this.onCancel,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<CoordinatorProjectsTab> createState() => _CoordinatorProjectsTabState();
}

class _CoordinatorProjectsTabState extends State<CoordinatorProjectsTab> {
  // Search & Sort State
  final Map<int, TextEditingController> _searchControllers = {};
  final Map<int, String> _sortOptions = {};

  // Wheel/Swipe Logic State
  double? _dragStartX;
  int? _initialTabIndex;
  Timer? _autoScrollTimer;
  int _swipeDirection = 0; // -1 for left, 1 for right, 0 for none

  @override
  void initState() {
    super.initState();
    // Initialize search controllers for each tab
    for (int i = 0; i < 4; i++) {
      _searchControllers[i] = TextEditingController();
      _searchControllers[i]!.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    for (var controller in _searchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startAutoScroll({required bool forward}) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Logic for continuous scroll could be added here if using a ScrollController
      // Since we use animateTo on TabController, this might just be for debounce or state tracking
    });
  }

  List<Project> _filterAndSortProjects(List<Project> projects, int tabIndex) {
    // Get search query for this tab
    final searchQuery = _searchControllers[tabIndex]?.text.toLowerCase().trim() ?? '';
    
    // Filter by search query
    var filtered = projects.where((p) {
      if (searchQuery.isEmpty) return true;
      return p.title.toLowerCase().contains(searchQuery) ||
          (p.description?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();
    
    // Get sort option for this tab (default to date_asc)
    final sortOption = _sortOptions[tabIndex] ?? 'date_asc';
    
    // Sort projects
    switch (sortOption) {
      case 'date_desc':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'title_asc':
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'title_desc':
        filtered.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'priority':
        final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
        filtered.sort((a, b) {
          final aPriority = priorityOrder[a.priority?.toLowerCase() ?? 'medium'] ?? 2;
          final bPriority = priorityOrder[b.priority?.toLowerCase() ?? 'medium'] ?? 2;
          if (aPriority != bPriority) return bPriority.compareTo(aPriority);
          return a.createdAt.compareTo(b.createdAt);
        });
        break;
      case 'date_asc':
      default:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // Filter projects by status
    final pendingProjects = widget.projects.where((p) => p.status.toLowerCase() == 'pending').toList();
    final ongoingProjects = widget.projects.where((p) => p.status.toLowerCase() == 'in_progress').toList();
    final completedProjects = widget.projects.where((p) => p.status.toLowerCase() == 'completed').toList();
    final cancelledProjects = widget.projects.where((p) => p.status.toLowerCase() == 'cancelled').toList();

    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    return Column(
      children: [
        // Project Subtabs - Rotating Wheel Style with Navigation Arrows
        Container(
          margin: const EdgeInsets.symmetric(vertical: 15),
          height: 95,
          child: widget.tabController.length == 4
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating wheel in center
                    _buildRotatingWheel(
                      selectedIndex: widget.tabController.index,
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                    ),
                    // Left arrow
                    Positioned(
                      left: 16,
                      top: 54,
                      child: _buildNavigationArrow(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () {
                          final currentIndex = widget.tabController.index;
                          final newIndex = currentIndex > 0 ? currentIndex - 1 : 3;
                          widget.tabController.animateTo(newIndex);
                        },
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    // Right arrow
                    Positioned(
                      right: 16,
                      top: 54,
                      child: _buildNavigationArrow(
                        icon: Icons.arrow_forward_ios_rounded,
                        onTap: () {
                          final currentIndex = widget.tabController.index;
                          final newIndex = currentIndex < 3 ? currentIndex + 1 : 0;
                          widget.tabController.animateTo(newIndex);
                        },
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    // Dot Indicator at arrow level
                    Positioned(
                      top: 78,
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: _buildDotIndicator(
                        selectedIndex: widget.tabController.index,
                        itemCount: 4,
                      ),
                    ),
                  ],
                )
              : const SizedBox(height: 48),
        ),
        const SizedBox(height: 0),
        // Projects List with Subtabs - Swipeable
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            color: const Color(0xFF4CAF50),
            child: widget.tabController.length != 4
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // Update the carousel when swiping
                      if (notification is ScrollUpdateNotification) {
                        setState(() {});
                      }
                      return false;
                    },
                    child: TabBarView(
                      controller: widget.tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        CoordinatorProjectList(
                          projects: _filterAndSortProjects(pendingProjects, 0),
                          emptyTitle: 'No received projects',
                          emptySubtitle: 'Newly received projects will appear here',
                          isReceivedTab: true,
                          searchController: _searchControllers[0]!,
                          currentSortOption: _sortOptions[0] ?? 'date_asc',
                          onSortChanged: (val) => setState(() => _sortOptions[0] = val),
                          onViewDetails: widget.onViewDetails,
                          onUploadDocuments: widget.onUploadDocuments,
                          onViewStatus: widget.onViewStatus,
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          onStart: widget.onStart,
                          onCancel: widget.onCancel,
                          onComplete: widget.onComplete,
                        ),
                        CoordinatorProjectList(
                          projects: _filterAndSortProjects(ongoingProjects, 1),
                          emptyTitle: 'No ongoing projects',
                          emptySubtitle: 'Projects in progress will appear here',
                          searchController: _searchControllers[1]!,
                          currentSortOption: _sortOptions[1] ?? 'date_asc',
                          onSortChanged: (val) => setState(() => _sortOptions[1] = val),
                          onViewDetails: widget.onViewDetails,
                          onUploadDocuments: widget.onUploadDocuments,
                          onViewStatus: widget.onViewStatus,
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          onStart: widget.onStart,
                          onCancel: widget.onCancel,
                          onComplete: widget.onComplete,
                        ),
                        CoordinatorProjectList(
                          projects: _filterAndSortProjects(completedProjects, 2),
                          emptyTitle: 'No completed projects',
                          emptySubtitle: 'Finished projects will appear here',
                          searchController: _searchControllers[2]!,
                          currentSortOption: _sortOptions[2] ?? 'date_asc',
                          onSortChanged: (val) => setState(() => _sortOptions[2] = val),
                          onViewDetails: widget.onViewDetails,
                          onUploadDocuments: widget.onUploadDocuments,
                          onViewStatus: widget.onViewStatus,
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          onStart: widget.onStart,
                          onCancel: widget.onCancel,
                          onComplete: widget.onComplete,
                        ),
                        CoordinatorProjectList(
                          projects: _filterAndSortProjects(cancelledProjects, 3),
                          emptyTitle: 'No cancelled projects',
                          emptySubtitle: 'Cancelled projects will appear here',
                          isCancelledTab: true,
                          searchController: _searchControllers[3]!,
                          currentSortOption: _sortOptions[3] ?? 'date_asc',
                          onSortChanged: (val) => setState(() => _sortOptions[3] = val),
                          onViewDetails: widget.onViewDetails,
                          onUploadDocuments: widget.onUploadDocuments,
                          onViewStatus: widget.onViewStatus,
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          onStart: widget.onStart,
                          onCancel: widget.onCancel,
                          onComplete: widget.onComplete,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRotatingWheel({
    required int selectedIndex,
    required bool isSmallScreen,
    required bool isMediumScreen,
  }) {
    // Keep 'assets/icons/recieve projects.svg' typo as receiving projects (matching original)
    final tabs = [
      {'icon': 'assets/icons/recieve projects.svg', 'index': 0, 'isSvg': true},
      {'icon': 'assets/icons/Ongoing Project.svg', 'index': 1, 'isSvg': true},
      {'icon': Icons.task_alt, 'index': 2, 'isSvg': false},
      {'icon': 'assets/icons/canceled project.svg', 'index': 3, 'isSvg': true},
    ];

    final baseSize = isSmallScreen ? 48.0 : isMediumScreen ? 52.0 : 56.0;
    final activeSize = baseSize * 1.4; // Active tab 40% larger
    final spacing = baseSize * 1.2; // Increased spacing for more spread
    
    return GestureDetector(
      onHorizontalDragStart: (details) {
        setState(() {
          _dragStartX = details.globalPosition.dx;
          _initialTabIndex = selectedIndex;
          _swipeDirection = 0;
        });
        // Cancel any existing auto-scroll
        _autoScrollTimer?.cancel();
      },
      onHorizontalDragUpdate: (details) {
        if (_dragStartX == null || _initialTabIndex == null) return;
        
        // Calculate drag distance from initial position
        final dragDistance = details.globalPosition.dx - _dragStartX!;
        final currentIndex = widget.tabController.index;
        
        // Determine swipe direction and handle tab switching
        if (dragDistance < -60 && _swipeDirection != -1) {
          // Swipe left - go forward
          setState(() => _swipeDirection = -1);
          
          // Immediately move to next tab
          if (currentIndex < 3) {
            widget.tabController.animateTo(
              currentIndex + 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
          
          // Start auto-scroll for continuous movement
          _startAutoScroll(forward: true);
        } else if (dragDistance > 60 && _swipeDirection != 1) {
          // Swipe right - go back
          setState(() => _swipeDirection = 1);
          
          // Immediately move to previous tab
          if (currentIndex > 0) {
            widget.tabController.animateTo(
              currentIndex - 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
          
          // Start auto-scroll for continuous movement
          _startAutoScroll(forward: false);
        } else if (dragDistance.abs() < 60 && _swipeDirection != 0) {
          // Back in dead zone - stop auto-scroll
          setState(() => _swipeDirection = 0);
          _autoScrollTimer?.cancel();
        }
      },
      onHorizontalDragEnd: (details) {
        // Stop auto-scrolling when finger is lifted
        _autoScrollTimer?.cancel();
        
        // Reset tracking variables
        setState(() {
          _dragStartX = null;
          _initialTabIndex = null;
          _swipeDirection = 0;
        });
      },
      child: TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      tween: Tween<double>(begin: selectedIndex.toDouble(), end: selectedIndex.toDouble()),
      builder: (context, animatedIndex, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final centerX = constraints.maxWidth / 2;
            
            return SizedBox(
              height: 100,
              width: constraints.maxWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(4, (index) {
                  final distanceFromCenter = (index - animatedIndex);
                  final isActive = index == selectedIndex;
                  
                  // Layered positioning - closer spacing for overlap
                  final offset = distanceFromCenter * spacing;
                  
                  // Scale based on distance - smooth transition
                  final targetScale = isActive ? 1.0 : math.max(0.65, 1.0 - (distanceFromCenter.abs() * 0.15));
                  
                  // Opacity - smooth fade
                  final targetOpacity = isActive ? 1.0 : math.max(0.4, 1.0 - (distanceFromCenter.abs() * 0.2));
                  
                  // Size based on active state
                  final size = isActive ? activeSize : baseSize;
                  
                  // Vertical position - active tab higher
                  final topPosition = isActive ? 5.0 : 15.0;
                  
                  return TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, animation, child) {
                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        left: centerX + offset - size / 2,
                        top: topPosition,
                        child: Transform.scale(
                          scale: targetScale,
                          child: Opacity(
                            opacity: targetOpacity,
                            child: _buildTabIcon(tabs[index], isActive, size),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            );
          },
        );
      },
    ),
    );
  }

  Widget _buildTabIcon(Map<String, dynamic> tab, bool isActive, double size) {
    final icon = tab['icon'];
    final isSvg = tab['isSvg'] as bool;
    final iconSize = size * 0.5;
    
    return GestureDetector(
      onTap: () {
        widget.tabController.animateTo(tab['index'] as int);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
          shape: BoxShape.circle,
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isActive ? const Color(0xFF4CAF50) : Colors.white,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: isSvg
                  ? SvgPicture.asset(
                      icon as String,
                      key: ValueKey<bool>(isActive),
                      width: iconSize,
                      height: iconSize,
                      colorFilter: ColorFilter.mode(
                        isActive ? const Color(0xFF4CAF50) : const Color(0xFF9CA3AF),
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(
                      icon as IconData,
                      key: ValueKey<bool>(isActive),
                      color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF9CA3AF),
                      size: iconSize,
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavigationArrow({
    required IconData icon,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    final size = isSmallScreen ? 32.0 : 36.0;
    final iconSize = isSmallScreen ? 14.0 : 16.0;

    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: const Color(0xFF10B981),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicator({
    required int selectedIndex,
    required int itemCount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        final isActive = index == selectedIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 12 : 4,
          height: 5,
          decoration: BoxDecoration(
            color: isActive 
                ? const Color.fromARGB(255, 0, 0, 0) 
                : const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
            boxShadow: isActive ? [
              BoxShadow(
                color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ] : [],
          ),
        );
      }),
    );
  }
}

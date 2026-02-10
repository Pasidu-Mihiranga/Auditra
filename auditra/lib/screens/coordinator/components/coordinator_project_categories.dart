import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../../../../models/project_model.dart';
import '../../../../theme/app_colors.dart';

class CoordinatorProjectCategories extends StatefulWidget {
  final List<Project> projects;

  const CoordinatorProjectCategories({
    super.key,
    required this.projects,
  });

  @override
  State<CoordinatorProjectCategories> createState() => _CoordinatorProjectCategoriesState();
}

class _CoordinatorProjectCategoriesState extends State<CoordinatorProjectCategories> {
  int _selectedCategoryIndex = 1; // Default to 'Active' (index 1)
  double? _categoryDragStartX;

  @override
  Widget build(BuildContext context) {
    // Count all projects by status
    final receivedProjects = widget.projects.where((p) => p.status.toLowerCase() == 'pending').length;
    final activeProjects = widget.projects.where((p) => p.status.toLowerCase() == 'in_progress').length;
    final completedProjects = widget.projects.where((p) => p.status.toLowerCase() == 'completed').length;
    final cancelledProjects = widget.projects.where((p) => p.status.toLowerCase() == 'cancelled').length;
    
    final categories = [
      {
        'icon': 'assets/icons/recieve projects.svg',
        'isSvg': true,
        'label': 'Received',
        'count': receivedProjects,
        'color': const Color(0xFFF37748), // Orange (using hex to match original) - AppColors.orange
      },
      {
        'icon': 'assets/icons/Ongoing Project.svg',
        'isSvg': true,
        'label': 'Active',
        'count': activeProjects,
        'color': const Color(0xFF0570B0), // Strong Blue - AppColors.strongBlue
      },
      {
        'icon': Icons.task_alt,
        'isSvg': false,
        'label': 'Completed',
        'count': completedProjects,
        'color': const Color(0xFF067BC2), // Blue - AppColors.blue
      },
      {
        'icon': 'assets/icons/canceled project.svg',
        'isSvg': true,
        'label': 'Cancelled',
        'count': cancelledProjects,
        'color': const Color(0xFFD56062), // Red - AppColors.red
      },
    ];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 2),
            child: Text(
              'Projects Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF374151),
              ),
            ),
          ),
          _buildCategoryCarousel(categories),
        ],
      ),
    );
  }

  Widget _buildCategoryCarousel(List<Map<String, dynamic>> categories) {
    final baseSize = 140.0;
    final activeSize = baseSize * 1.2; // Active card 20% larger
    final spacing = 120.0; // Spacing between cards
    
    return GestureDetector(
      onHorizontalDragStart: (details) {
        setState(() {
          _categoryDragStartX = details.globalPosition.dx;
        });
      },
      onHorizontalDragUpdate: (details) {
        if (_categoryDragStartX == null) return;
        final dragDistance = details.globalPosition.dx - _categoryDragStartX!;
        final threshold = 50.0;
        
        if (dragDistance < -threshold && _selectedCategoryIndex < categories.length - 1) {
          setState(() {
            _selectedCategoryIndex++;
            _categoryDragStartX = details.globalPosition.dx;
          });
        } else if (dragDistance > threshold && _selectedCategoryIndex > 0) {
          setState(() {
            _selectedCategoryIndex--;
            _categoryDragStartX = details.globalPosition.dx;
          });
        }
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          _categoryDragStartX = null;
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SizedBox(
              height: 250,
              width: constraints.maxWidth,
              child: ClipRect(
              clipBehavior: Clip.hardEdge,
              child: Stack(
                clipBehavior: Clip.none,
                children: () {
                  // Build cards widget function
                  Widget buildCard(int index) {
                    final distanceFromCenter = (index - _selectedCategoryIndex).toDouble();
                    final isActive = index == _selectedCategoryIndex;
                    
                    // Layered positioning - cards spread horizontally
                    final offset = distanceFromCenter * spacing;
                    
                    // Scale based on distance from center
                    final distanceAbs = distanceFromCenter.abs();
                    final targetScale = isActive ? 1.0 : math.max(0.75, 1.0 - (distanceAbs * 0.2));
                    
                    // Opacity based on distance
                    final targetOpacity = isActive ? 1.0 : math.max(0.5, 1.0 - (distanceAbs * 0.3));
                    
                    // Size based on active state
                    final width = isActive ? activeSize : baseSize;
                    final height = isActive ? activeSize : baseSize;
                    
                    // Vertical position - active card slightly higher for layered effect
                    final topPosition = isActive ? 0.0 : (distanceAbs * 32.0);
                    
                    // Z-index effect - bring active card forward and push others back
                    final zOffset = isActive ? 10.0 : (distanceAbs * -5.0);
                    
                    return AnimatedPositioned(
                      key: ValueKey('category_card_$index'), // Stable key for animation tracking
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                      left: centerX + offset - width / 2,
                      top: topPosition,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        scale: targetScale,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                          opacity: targetOpacity,
                          child: Transform.translate(
                            offset: Offset(0, zOffset),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategoryIndex = index;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOutCubic,
                                width: width,
                                height: height,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: isActive ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 20,
                                      spreadRadius: 3,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: (categories[index]['color'] as Color).withOpacity(0.3),
                                      blurRadius: 24,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 6),
                                    ),
                                  ] : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildProjectCategoryCard(
                                  icon: categories[index]['icon'],
                                  isSvg: categories[index]['isSvg'] as bool,
                                  label: categories[index]['label'] as String,
                                  count: categories[index]['count'] as int,
                                  color: categories[index]['color'] as Color,
                                  isActive: isActive,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  
                  // Build non-active cards first, then active card last (appears on top)
                  final nonActiveCards = <Widget>[];
                  Widget? activeCard;
                  
                  for (int i = 0; i < categories.length; i++) {
                    if (i == _selectedCategoryIndex) {
                      activeCard = buildCard(i);
                    } else {
                      nonActiveCards.add(buildCard(i));
                    }
                  }
                  
                  // Combine: non-active first, then active (rendered last = on top)
                  final allCards = <Widget>[...nonActiveCards];
                  if (activeCard != null) {
                    allCards.add(activeCard);
                  }
                  
                  return allCards;
                }(),
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProjectCategoryCard({
    required dynamic icon,
    required bool isSvg,
    required String label,
    required int count,
    required Color color,
    bool isActive = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isActive ? 16 : 14,
        vertical: isActive ? 16 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            isSvg
                ? SvgPicture.asset(
                    icon as String,
                    width: isActive ? 36 : 32,
                    height: isActive ? 36 : 32,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  )
                : Icon(
                    icon as IconData,
                    size: isActive ? 36 : 32,
                    color: color,
                  ),
            SizedBox(height: isActive ? 6 : 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isActive ? 12 : 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9CA3AF),
                fontFamily: 'Inter',
              ),
            ),
            SizedBox(height: isActive ? 6 : 5),
            Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isActive ? 24 : 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

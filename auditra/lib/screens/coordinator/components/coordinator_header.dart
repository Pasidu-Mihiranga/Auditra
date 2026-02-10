import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' show ImageFilter;
import '../../../widgets/shared_dashboard_widgets.dart';

class CoordinatorHeader extends StatelessWidget {
  final TabController tabController;
  final TabController? projectSubTabController;
  final String? username;
  final String? roleDisplay;
  final VoidCallback onLogout;
  final VoidCallback onNotificationTap;
  final VoidCallback onStatsTap;
  final String Function(int index) getProjectSubTabName;

  const CoordinatorHeader({
    super.key,
    required this.tabController,
    required this.projectSubTabController,
    required this.username,
    required this.roleDisplay,
    required this.onLogout,
    required this.onNotificationTap,
    required this.onStatsTap,
    required this.getProjectSubTabName,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    // Responsive sizes
    final avatarSize = isSmallScreen ? 40.0 : 48.0;
    final avatarFontSize = isSmallScreen ? 16.0 : 20.0;
    final greetingFontSize = isSmallScreen ? 15.0 : isMediumScreen ? 16.0 : 18.0;
    final iconSize = isSmallScreen ? 20.0 : 24.0;
    final horizontalPadding = isSmallScreen ? 12.0 : isMediumScreen ? 16.0 : 20.0;
    final spacing = isSmallScreen ? 8.0 : 12.0;
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: 40,
            bottom: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Show project sub-tab name when in Projects tab
              tabController.index == 1 && projectSubTabController != null
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: isSmallScreen ? 34 : 38,
                          color: DashboardColors.primaryTeal,
                        ),
                        SizedBox(width: spacing),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Projects',
                              style: TextStyle(
                                fontFamily: 'Etna Sans Serif',
                                fontSize: isSmallScreen ? 22.0 : isMediumScreen ? 23.0 : 25.0,
                                fontWeight: FontWeight.w400,
                                color: DashboardColors.darkNavy, // Dark Navy for light background
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              getProjectSubTabName(projectSubTabController!.index),
                              style: TextStyle(
                                fontFamily: 'Etna Sans Serif',
                                fontSize: isSmallScreen ? 12.0 : isMediumScreen ? 13.0 : 14.0,
                                fontWeight: FontWeight.w400,
                                color: DashboardColors.primaryTeal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    )
                  // Show Attendance title when in Generic Dashboard tab (index 2)
                  : tabController.index == 2
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: isSmallScreen ? 34 : 38,
                            color: DashboardColors.primaryTeal,
                          ),
                          SizedBox(width: spacing),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Attendance',
                                style: TextStyle(
                                  fontFamily: 'Etna Sans Serif',
                                  fontSize: isSmallScreen ? 22.0 : isMediumScreen ? 23.0 : 25.0,
                                  fontWeight: FontWeight.w400,
                                  color: DashboardColors.darkNavy, // Dark Navy for light background
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${username ?? 'User'} | ${roleDisplay ?? 'Coordinator'}',
                                style: TextStyle(
                                  fontFamily: 'Etna Sans Serif',
                                  fontSize: isSmallScreen ? 12.0 : isMediumScreen ? 13.0 : 14.0,
                                  fontWeight: FontWeight.w400,
                                  color: DashboardColors.primaryTeal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      )
                    // Show greeting for Home tab (index 0)
                    : Row(
                      children: [
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: DashboardColors.sageGreen, // Sage Green for avatar
                          ),
                          child: username != null
                              ? Center(
                                  child: Text(
                                    username!.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'Etna Sans Serif',
                                      fontSize: avatarFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white, // White for Sage Green avatar
                                    ),
                                  ),
                                )
                              : Icon(Icons.person, color: Colors.white, size: avatarSize * 0.6),
                        ),
                        SizedBox(width: spacing),
                        Text(
                          'Hi, ${username ?? 'User'}!',
                          style: TextStyle(
                            fontFamily: 'Etna Sans Serif',
                            fontSize: greetingFontSize,
                            fontWeight: FontWeight.normal,
                            color: DashboardColors.darkNavy, // Dark Navy for light background
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
              // Show icons only when in Home tab (index 0)
              if (tabController.index == 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isSmallScreen)
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        iconSize: iconSize,
                        color: DashboardColors.primaryTeal,
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        constraints: const BoxConstraints(),
                        onPressed: onNotificationTap,
                      ),
                    if (!isSmallScreen)
                      IconButton(
                        icon: const Icon(Icons.show_chart),
                        iconSize: iconSize,
                        color: DashboardColors.sageGreen,
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        constraints: const BoxConstraints(),
                        onPressed: onStatsTap,
                      ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      iconSize: iconSize,
                      color: DashboardColors.accentOrange, // Orange for logout
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                      constraints: const BoxConstraints(),
                      onPressed: onLogout,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

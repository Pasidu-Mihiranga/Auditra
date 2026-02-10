
import 'package:flutter/material.dart';
import '../../../../widgets/sync_status_indicator.dart';
import '../styles/field_officer_styles.dart';

class FieldOfficerHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? username;
  final String? roleDisplay;
  final TabController tabController;
  final VoidCallback onLogout;

  const FieldOfficerHeader({
    super.key,
    required this.username,
    required this.roleDisplay,
    required this.tabController,
    required this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(110); // Toolbar height + TabBar height

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: (username != null || roleDisplay != null)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (username != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        username!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white.withOpacity(0.95) : Colors.black87,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                if (username != null && roleDisplay != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Container(
                      width: 1,
                      height: 18,
                      color: isDark ? Colors.white.withOpacity(0.3) : Colors.black26,
                    ),
                  ),
                if (roleDisplay != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.15),
                              ]
                            : [
                                FieldOfficerStyles.primaryBlue.withOpacity(0.1),
                                FieldOfficerStyles.lightBlue.withOpacity(0.1),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : FieldOfficerStyles.primaryBlue.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 14,
                          color: isDark ? Colors.white.withOpacity(0.9) : FieldOfficerStyles.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          roleDisplay!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: isDark ? Colors.white : FieldOfficerStyles.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : null,
      centerTitle: true,
      actions: [
        const SyncStatusIndicator(),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.black87),
          onPressed: onLogout,
          tooltip: 'Logout',
        ),
        const SizedBox(width: 8),
      ],
      bottom: TabBar(
        controller: tabController,
        labelColor: FieldOfficerStyles.primaryBlue,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: FieldOfficerStyles.primaryBlue,
        tabs: const [
          Tab(icon: Icon(Icons.access_time), text: 'Attendance'),
          Tab(icon: Icon(Icons.folder), text: 'Projects'),
        ],
      ),
    );
  }
}

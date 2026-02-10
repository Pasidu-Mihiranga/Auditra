import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' show ImageFilter;
import '../../../widgets/shared_dashboard_widgets.dart';

class CoordinatorBottomNav extends StatefulWidget {
  final TabController tabController;

  const CoordinatorBottomNav({
    super.key,
    required this.tabController,
  });

  @override
  State<CoordinatorBottomNav> createState() => _CoordinatorBottomNavState();
}

class _CoordinatorBottomNavState extends State<CoordinatorBottomNav> {
  @override
  void initState() {
    super.initState();
    // Listen to tab changes to rebuild and animate icons
    widget.tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    
    return IgnorePointer(
      ignoring: isKeyboardVisible, // Disable interactions when keyboard is visible
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        transform: Matrix4.translationValues(
          0,
          isKeyboardVisible ? 100 : 0, // Slide down completely off screen
          0,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          opacity: isKeyboardVisible ? 0.0 : 1.0, // Fade out background and content
          child: _buildNavigationContent(),
        ),
      ),
    );
  }

  Widget _buildNavigationContent() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: DashboardColors.background.withOpacity(0.85), // Light Cream with opacity
            border: Border(
              top: BorderSide(
                color: DashboardColors.sageGreen.withOpacity(0.3), // Sage Green border
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: DashboardColors.primaryTeal.withOpacity(0.1), // Teal Blue shadow
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAnimatedTabButton(
                index: 2,
                icon: 'assets/icons/Attendance .svg',
                isSvg: true,
                onPressed: () => widget.tabController.animateTo(2),
              ),
              const SizedBox(width: 0),
              _buildAnimatedTabButton(
                index: 0,
                icon: 'assets/icons/home-2.svg',
                isSvg: true,
                onPressed: () => widget.tabController.animateTo(0),
              ),
              const SizedBox(width: 0),
              _buildAnimatedTabButton(
                index: 1,
                icon: Icons.folder_outlined,
                isSvg: false,
                onPressed: () => widget.tabController.animateTo(1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTabButton({
    required int index,
    required dynamic icon,
    required bool isSvg,
    required VoidCallback onPressed,
  }) {
    final isActive = widget.tabController.index == index;
    
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated black circle background
          AnimatedScale(
            scale: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFF111827),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // Animated icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: child,
              );
            },
            child: isSvg
                ? GestureDetector(
                    key: ValueKey<bool>(isActive),
                    onTap: onPressed,
                    child: SvgPicture.asset(
                      icon as String,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        isActive ? Colors.white : const Color(0xFF9CA3AF),
                        BlendMode.srcIn,
                      ),
                    ),
                  )
                : IconButton(
                    key: ValueKey<bool>(isActive),
                    icon: Icon(icon as IconData),
                    color: isActive ? Colors.white : const Color(0xFF9CA3AF),
                    onPressed: onPressed,
                  ),
          ),
        ],
      ),
    );
  }
}

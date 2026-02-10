import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' show FontFeature; // Ensure correct import for FontFeature if specialized features are needed

class CoordinatorAnimations {
  // Static wrapper to expose widgets if needed, or just keep them as classes in this file
}

class PulsingContainer extends StatefulWidget {
  final Color color;

  const PulsingContainer({Key? key, required this.color}) : super(key: key);

  @override
  State<PulsingContainer> createState() => _PulsingContainerState();
}

class _PulsingContainerState extends State<PulsingContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: widget.color.withOpacity(0.1 + (0.2 * _controller.value)), // Use opacity for pulsing effect
          ),
        );
      },
    );
  }
}

class PulsingButtonBackground extends StatefulWidget {
  final Color color;

  const PulsingButtonBackground({Key? key, required this.color}) : super(key: key);

  @override
  State<PulsingButtonBackground> createState() => _PulsingButtonBackgroundState();
}

class _PulsingButtonBackgroundState extends State<PulsingButtonBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.color.withOpacity(0.1 + (0.2 * _controller.value)),
          ),
        );
      },
    );
  }
}

class RotatingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const RotatingIcon({
    Key? key,
    required this.icon,
    required this.color,
    required this.size,
  }) : super(key: key);

  @override
  State<RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<RotatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}

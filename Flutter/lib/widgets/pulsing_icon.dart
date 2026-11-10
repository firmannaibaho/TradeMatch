import 'package:flutter/material.dart';

/// Pulsing Icon Widget
///
/// Creates an animated icon with a pulsing/breathing effect, useful for indicating
/// pending or loading states. The icon smoothly scales up and down continuously.
///
/// Example usage:
/// ```dart
/// PulsingIcon(
///   icon: Icons.hourglass_top,
///   color: Colors.orange,
///   size: 24.0,
/// )
/// ```
class PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final Duration duration;

  const PulsingIcon({
    super.key,
    required this.icon,
    this.color = Colors.orange,
    this.size = 24.0,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Create animation controller that repeats indefinitely
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true); // reverse: true makes it go back and forth

    // Create a curved animation for smooth pulsing effect
    _animation = Tween<double>(
      begin: 0.8, // Minimum scale
      end: 1.2, // Maximum scale
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(widget.icon, color: widget.color, size: widget.size),
        );
      },
    );
  }
}

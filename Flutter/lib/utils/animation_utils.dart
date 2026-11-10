import 'package:flutter/material.dart';

/// Custom page route with slide transition
class SlidePageRoute extends PageRouteBuilder {
  final Widget page;
  final AxisDirection direction;
  final Duration duration;
  
  SlidePageRoute({
    required this.page,
    this.direction = AxisDirection.right,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      Offset begin;
      switch (direction) {
        case AxisDirection.left:
          begin = const Offset(-1.0, 0.0);
          break;
        case AxisDirection.right:
          begin = const Offset(1.0, 0.0);
          break;
        case AxisDirection.up:
          begin = const Offset(0.0, -1.0);
          break;
        case AxisDirection.down:
          begin = const Offset(0.0, 1.0);
          break;
      }
      
      const end = Offset.zero;
      final tween = Tween(begin: begin, end: end);
      final offsetAnimation = animation.drive(tween.chain(
        CurveTween(curve: Curves.easeInOut),
      ));
      
      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}

/// Custom page route with fade transition
class FadePageRoute extends PageRouteBuilder {
  final Widget page;
  final Duration duration;
  
  FadePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}

/// Custom page route with scale transition
class ScalePageRoute extends PageRouteBuilder {
  final Widget page;
  final Duration duration;
  
  ScalePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
        ),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

/// Navigation helpers with custom transitions
class AnimatedNavigation {
  /// Navigate with slide transition
  static Future<T?> slideToPage<T>(
    BuildContext context,
    Widget page, {
    AxisDirection direction = AxisDirection.right,
  }) {
    return Navigator.push<T>(
      context,
      SlidePageRoute(page: page, direction: direction) as Route<T>,
    );
  }
  
  /// Navigate with fade transition
  static Future<T?> fadeToPage<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      FadePageRoute(page: page) as Route<T>,
    );
  }
  
  /// Navigate with scale transition
  static Future<T?> scaleToPage<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      ScalePageRoute(page: page) as Route<T>,
    );
  }
  
  const AnimatedNavigation._();
}

/// Animated list item widget
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 50),
  });
  
  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
    
    // Staggered delay based on index
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Animated button with press effect
class AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scale;
  
  const AnimatedPressButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scale = 0.95,
  });
  
  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }
  
  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed?.call();
  }
  
  void _handleTapCancel() {
    _controller.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

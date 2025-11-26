import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Potrzebne do wibracji (HapticFeedback)

class AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;

  const AnimatedPressButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.95,
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
      vsync: this,
      duration: const Duration(milliseconds: 100), // Szybkie wciśnięcie
      reverseDuration: const Duration(milliseconds: 150), // Sprężyste odbicie
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // KLUCZOWE: Łapie kliknięcia nawet na przezroczystym tle
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        _controller.forward();
        // Dodajemy delikatną wibrację przy dotknięciu - to daje świetne poczucie "fizyczności"
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// An Apple-style gesture-driven draggable card that uses spring physics
/// and velocity handoff for natural, interruptible motion.
class SpringDraggableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDismissed;
  final double initialDamping;
  final double response;

  const SpringDraggableCard({
    super.key,
    required this.child,
    this.onDismissed,
    this.initialDamping = 1.0,
    this.response = 0.4, // Used to calculate stiffness/damping
  });

  @override
  State<SpringDraggableCard> createState() => _SpringDraggableCardState();
}

class _SpringDraggableCardState extends State<SpringDraggableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  
  // Spring params based on Apple's response and damping ratio
  late final SpringDescription _springDesc;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _controller.addListener(() {
      setState(() {
        _dragOffset = _controller.value;
      });
    });

    // Derive stiffness and damping from response time and damping ratio
    final mass = 1.0;
    // approximate stiffness based on response time: response ≈ 2π / sqrt(stiffness/mass)
    // -> stiffness = (2π / response)^2
    final stiffness = (2 * 3.14159 / widget.response) * (2 * 3.14159 / widget.response);
    final damping = 2 * widget.initialDamping * 3.14159 * 2 / widget.response;
    
    _springDesc = SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: damping,
    );
  }

  void _onPanStart(DragStartDetails details) {
    // Interrupt current animation immediately (Interruptibility principle)
    _controller.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      // Progressive resistance when dragging up past 0 (Rubber-banding principle)
      if (_dragOffset < 0) {
         _dragOffset -= details.delta.dy * 0.5; // Dampen upward drag
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Velocity handoff: pass the pointer's release velocity to the spring
    final pixelsPerSecond = details.velocity.pixelsPerSecond.dy;
    
    // Project momentum to see where it would land
    final projectedEndpoint = _dragOffset + (pixelsPerSecond / 1000) * 0.998 / (1 - 0.998);
    
    // Snap logic: if projected endpoint is far down, dismiss it. Otherwise snap back to 0.
    final dismissThreshold = 200.0;
    final target = projectedEndpoint > dismissThreshold ? 500.0 : 0.0;

    final simulation = SpringSimulation(_springDesc, _dragOffset, target, pixelsPerSecond);
    
    _controller.animateWith(simulation).then((_) {
      if (target == 500.0 && widget.onDismissed != null) {
        widget.onDismissed!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: widget.child,
      ),
    );
  }
}

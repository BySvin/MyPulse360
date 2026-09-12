import 'package:flutter/physics.dart';
import 'package:flutter/animation.dart';

/// A Custom Curve based on Apple's Spring physics.
/// Maps SpringSimulation to a 0.0 -> 1.0 Curve for use in standard
/// Flutter animations (like flutter_animate).
class AppleSpringCurve extends Curve {
  final SpringSimulation _sim;

  AppleSpringCurve({
    double damping = 1.0,
    double response = 0.4,
  }) : _sim = SpringSimulation(
          SpringDescription(
            mass: 1.0,
            stiffness: (2 * 3.14159 / response) * (2 * 3.14159 / response),
            damping: 2 * damping * 3.14159 * 2 / response,
          ),
          0.0, // initial position
          1.0, // target position
          0.0, // initial velocity
        );

  @override
  double transformInternal(double t) {
    // We evaluate the spring simulation at time t 
    // where t is scaled to the rough duration of the spring
    // For a curve, t goes from 0.0 to 1.0. 
    // We'll scale t by the response time to get the simulation time.
    final timeInSeconds = t * 1.5; // Scale up to give the spring time to settle
    return _sim.x(timeInSeconds);
  }
}

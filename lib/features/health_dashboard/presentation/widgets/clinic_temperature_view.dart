import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class ClinicTemperatureView extends StatefulWidget {
  final bool isAtClinic;

  const ClinicTemperatureView({
    super.key,
    required this.isAtClinic,
  });

  @override
  State<ClinicTemperatureView> createState() => _ClinicTemperatureViewState();
}

class _ClinicTemperatureViewState extends State<ClinicTemperatureView> {
  // Dummy records for when user is away from clinic
  final List<Map<String, dynamic>> _records = [
    {'date': 'Today, 10:30 AM', 'temp': 36.5},
    {'date': 'Yesterday, 02:15 PM', 'temp': 36.8},
    {'date': 'Sep 05, 09:00 AM', 'temp': 37.1},
    {'date': 'Sep 01, 11:20 AM', 'temp': 36.6},
  ];

  @override
  Widget build(BuildContext context) {
    // We use AnimatedSwitcher to smoothly transition between the live UI and records UI
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // Dark futuristic background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Body Temperature',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          // This switch is just for you to test the UI toggle easily!
          Row(
            children: [
              Text('At Clinic', style: GoogleFonts.inter(fontSize: 12)),
              Switch(
                value: widget.isAtClinic,
                onChanged: (val) {
                  // Normally this would be driven by location state/provider
                },
                activeThumbColor: Colors.purpleAccent,
              ),
            ],
          )
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: widget.isAtClinic ? _buildLiveView() : _buildRecordsView(),
      ),
    );
  }

  Widget _buildLiveView() {
    return Container(
      key: const ValueKey('live_view'),
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_tethering, color: Colors.purpleAccent, size: 28)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(end: 1.2, duration: 1.seconds)
              .fade(),
          const SizedBox(height: 8),
          Text(
            'Live Clinic Reading',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 64),
          Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: CustomPaint(
                painter: _GlowingGaugePainter(),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '36.5',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      Text(
                        '°C',
                        style: GoogleFonts.inter(
                          color: Colors.purpleAccent,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fade(duration: 800.ms).scale(begin: const Offset(0.9, 0.9)),
          ),
          const SizedBox(height: 64),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.purpleAccent, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Connected to clinic sensors.',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                ),
              ],
            ).animate().slideX(begin: 0.1).fade(),
          )
        ],
      ),
    );
  }

  Widget _buildRecordsView() {
    return Container(
      key: const ValueKey('records_view'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_off, color: Colors.amberAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Away from Clinic',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live tracking is paused until your next visit.',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: -0.1, duration: 500.ms).fade(),
          const SizedBox(height: 32),
          Text(
            'History Records',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fade(delay: 200.ms),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _records.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = _records[index];
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161625), 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record['date'],
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Recorded at Clinic',
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${record['temp']}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '°C',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().slideX(begin: 0.1, delay: (100 * index).ms).fade();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowingGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle track
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi,
      2 * pi,
      false,
      bgPaint,
    );

    // Glowing active track
    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [Colors.purpleAccent, Color(0xFFB388FF), Colors.purpleAccent],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4); 

    // Draw active arc (example: temperature level)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, 
      pi * 1.3, // Represents how "full" the temp gauge is
      false,
      activePaint,
    );
    
    // Outer blur for the glowing neon effect
    final outerGlowPaint = Paint()
      ..color = Colors.purpleAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      pi * 1.3,
      false,
      outerGlowPaint,
    );
    
    // Inner dashed futuristic lines
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    const int numDashes = 36;
    for (int i = 0; i < numDashes; i++) {
      final angle = (2 * pi * i) / numDashes;
      // Leave a gap for styling
      if (i > 25 && i < 30) continue; 
      
      final innerRadius = radius - 45;
      final outerRadius = radius - 35;
      
      final p1 = Offset(
        center.dx + innerRadius * cos(angle),
        center.dy + innerRadius * sin(angle),
      );
      final p2 = Offset(
        center.dx + outerRadius * cos(angle),
        center.dy + outerRadius * sin(angle),
      );
      
      canvas.drawLine(p1, p2, dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

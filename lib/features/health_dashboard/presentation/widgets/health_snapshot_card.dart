import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/status_badge.dart';
import '../../../patient/domain/entities/patient_profile.dart';

class HealthSnapshotCard extends StatelessWidget {
  const HealthSnapshotCard({super.key, required this.profile});

  final PatientProfile profile;

  StatusTone get _tone => switch (profile.bmiCategory) {
        'Healthy weight' => StatusTone.success,
        'Underweight' || 'Overweight' => StatusTone.warning,
        _ => StatusTone.danger,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 2.0,
          colors: [
            Color(0xFF8C2215), // Deep red/orange
            Color(0xFF330C05), // Very dark red
            Color(0xFF101015), // Near black
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C2215).withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Body Report',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              StatusBadge(label: profile.bmiCategory, tone: _tone),
            ],
          ),
          const SizedBox(height: 32),
          // Custom stylized ruler/gauge representation matching the image
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 2,
                width: double.infinity,
                color: Colors.white24,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTick(height: 8),
                  _buildTick(height: 12),
                  _buildTick(height: 24, isCenter: true),
                  _buildTick(height: 12),
                  _buildTick(height: 8),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text('Normal', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text('High', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildValueColumn('BMI', profile.bmi.toStringAsFixed(1), ''),
              _buildValueColumn('Height', profile.heightCm.toStringAsFixed(0), ' cm'),
              _buildValueColumn('Weight', profile.weightKg.toStringAsFixed(1), ' kg'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTick({required double height, bool isCenter = false}) {
    return Container(
      width: 2,
      height: height,
      color: isCenter ? const Color(0xFFFF8A00) : Colors.white24,
      margin: EdgeInsets.only(bottom: isCenter ? 6 : 0),
    );
  }

  Widget _buildValueColumn(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                color: Colors.white70,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

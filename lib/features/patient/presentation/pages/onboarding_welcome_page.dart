import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../widgets/onboarding_progress_bar.dart';

class _WelcomeSlide {
  const _WelcomeSlide({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;
}

const _slides = [
  _WelcomeSlide(
    icon: Icons.calendar_month_rounded,
    title: 'Book in seconds',
    message: 'Find a time that works and book your visit without a phone call.',
  ),
  _WelcomeSlide(
    icon: Icons.confirmation_number_rounded,
    title: 'Track your queue live',
    message: "See your position and estimated wait the moment you're checked in.",
  ),
  _WelcomeSlide(
    icon: Icons.favorite_rounded,
    title: 'Insights made for you',
    message: 'A few details about you power personalized health insights on your dashboard.',
  ),
];

/// Onboarding step 1 of 5 — a short welcome carousel. Purely presentational;
/// nothing is saved here.
class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key});

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      context.go(RoutePaths.onboardingEmergencyContact);
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OnboardingProgressBar(step: 1),
              const SizedBox(height: 12),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final slide in _slides)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.patientAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadii.lg),
                            ),
                            child: Icon(slide.icon, size: 32, color: colors.patientAccent),
                          ),
                          const SizedBox(height: 24),
                          Text(slide.title, style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 8),
                          Text(
                            slide.message,
                            style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index ? colors.patientAccent : colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: isLast ? 'Get Started' : 'Next', onPressed: _next),
            ],
          ),
        ),
      ),
    );
  }
}

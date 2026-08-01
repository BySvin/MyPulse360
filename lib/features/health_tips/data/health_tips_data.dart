import '../domain/entities/health_tip.dart';

/// Curated, static wellness content — no backend needed. Replaces the old
/// Health Overview tile on the patient home screen.
const List<HealthTip> kHealthTips = [
  HealthTip(
    emoji: '💧',
    title: 'Stay hydrated',
    body: 'Aim for 8 glasses of water a day — more if you\'re active or it\'s hot out.',
    category: 'Hydration',
  ),
  HealthTip(
    emoji: '🚶',
    title: 'Move every hour',
    body: 'A 5-minute walk each hour improves circulation and steadies blood sugar.',
    category: 'Activity',
  ),
  HealthTip(
    emoji: '😴',
    title: 'Protect your sleep',
    body: '7–9 hours a night supports your immune system and mood.',
    category: 'Sleep',
  ),
  HealthTip(
    emoji: '🥗',
    title: 'Half your plate: vegetables',
    body: 'Filling half your plate with vegetables makes balanced eating effortless.',
    category: 'Nutrition',
  ),
  HealthTip(
    emoji: '💊',
    title: 'Take medication on schedule',
    body: 'Set reminders — consistent timing matters as much as the dose itself.',
    category: 'Medication',
  ),
  HealthTip(
    emoji: '🧘',
    title: 'Make time to breathe',
    body: 'Five minutes of slow breathing can meaningfully lower stress and blood pressure.',
    category: 'Mindfulness',
  ),
  HealthTip(
    emoji: '🩺',
    title: 'Know your numbers',
    body: 'Regular check-ins on blood pressure and blood sugar catch changes early.',
    category: 'Prevention',
  ),
  HealthTip(
    emoji: '☀️',
    title: 'Get some daylight',
    body: 'Morning sunlight helps regulate your sleep cycle and energy through the day.',
    category: 'Wellness',
  ),
];

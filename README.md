# MyPulse360

MyPulse360 is a healthcare management platform built as a **Final Year Project** by a group of students. It brings patients, doctors, and pharmacists onto a single system — appointment booking, e-prescriptions, pharmacy inventory, staff scheduling, and personal health tracking — through one Flutter codebase that adapts to each role.

## Live Demo

🔗 Coming soon — a live/hosted demo link will be added here once deployed.

## Overview

The app is role-aware: patients use it as a mobile app, while doctors and pharmacists use it as a web app, all sharing the same codebase and backend logic.

- **Patients** book appointments, track health metrics, chat with an AI assistant, and manage prescriptions — including digitizing paper prescriptions by scanning a barcode/QR code or taking a photo (with on-device OCR).
- **Doctors** manage their queue and schedule, review patient history, issue prescriptions, and handle staff/leave management.
- **Pharmacists** manage medicine inventory (batches, suppliers, wastage, multi-location stock, FEFO dispensing), verify and dispense prescriptions, and manage their own shifts.

## Key Features

- Role-based authentication (patient / doctor / pharmacist) with a mobile-vs-web platform split
- Appointment booking with live queue tracking, and automatic awareness of doctor leave when booking
- E-prescriptions: doctor-issued, pharmacist-verified, and patient-scanned (barcode/QR or photo + OCR)
- Pharmacy inventory management: batch tracking, suppliers, wastage logging, multi-location stock, FEFO-based dispensing, and analytics
- Staff scheduling: shift creation, conflict detection, leave requests, clock in/out, and overtime tracking
- Health device integration: simulated Apple Health / Google Fit connection with activity & fitness metrics
- Personalized health dashboard with wellness insights, BMI snapshot, and health tips
- AI chat assistant for patient support

## Tech Stack

- **Flutter** with **Dart**
- **Riverpod** for state management
- **go_router** for navigation
- **mobile_scanner** for barcode/QR scanning
- **google_mlkit_text_recognition** for on-device OCR
- **fl_chart** for analytics and charts
- Clean architecture (domain / data / presentation) per feature, with an in-memory mock backend for demo purposes

## Getting Started

1. Install [Flutter](https://docs.flutter.dev/get-started/install)
2. Clone the repository and install dependencies:
   ```
   flutter pub get
   ```
3. Run the app on a connected device or emulator:
   ```
   flutter run
   ```

## Project Structure

The codebase follows clean architecture, organized by feature under `lib/features/`, with each feature split into `domain/` (entities, repositories, use cases), `data/` (data sources, repository implementations), and `presentation/` (pages, widgets, providers). Shared code lives under `lib/shared/`.

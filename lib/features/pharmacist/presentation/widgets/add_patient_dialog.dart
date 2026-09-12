import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/mock/mock_ids.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../patient/domain/entities/patient_profile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class AddPatientDialog extends ConsumerStatefulWidget {
  const AddPatientDialog({super.key});

  @override
  ConsumerState<AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends ConsumerState<AddPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _icController = TextEditingController();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    
    final db = ref.read(mockDatabaseProvider);
    final user = ref.read(currentUserProvider);
    
    final newPatientId = const Uuid().v4();
    
    final newUser = AppUser(
      id: newPatientId,
      email: 'walkin_$newPatientId@example.com',
      fullName: _nameController.text.trim(),
      role: UserRole.patient,
      clinicId: user?.clinicId ?? MockIds.defaultClinicId,
    );
    
    final newProfile = PatientProfile(
      id: newPatientId,
      icNumber: _icController.text.trim(),
      heightCm: 170,
      weightKg: 70,
      allergies: const [],
      chronicConditions: const [],
      currentMedications: const [],
      assignedDoctorId: MockIds.drAhmedDoctorId,
    );
    
    final newAppointment = Appointment(
      id: const Uuid().v4(),
      patientId: newPatientId,
      doctorId: MockIds.drAhmedDoctorId,
      clinicId: user?.clinicId ?? MockIds.defaultClinicId,
      scheduledAt: DateTime.now(),
      durationMinutes: 15,
      appointmentType: 'walk-in',
      status: AppointmentStatus.confirmed,
    );
    
    db.users.add(newUser);
    db.patients.add(newProfile);
    db.appointments.add(newAppointment);
    
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Patient added to queue')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _icController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Patient to Queue'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _icController,
              decoration: const InputDecoration(labelText: 'IC Number'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

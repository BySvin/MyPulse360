import '../../../features/doctor/domain/entities/doctor_profile.dart';
import '../mock_ids.dart';

List<DoctorProfile> seedDoctors() => [
      const DoctorProfile(
        id: MockIds.drAhmedDoctorId,
        licenseNumber: 'MD-48213',
        specialization: 'General Medicine',
        clinicId: MockIds.defaultClinicId,
        bio: 'Managing 20-30 patients a day, focused on chronic-condition follow-up.',
        averageRating: 4.8,
      ),
    ];

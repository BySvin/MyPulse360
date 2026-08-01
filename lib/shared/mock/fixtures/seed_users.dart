import '../../../features/auth/domain/entities/app_user.dart';
import '../../../features/auth/domain/entities/user_role.dart';
import '../mock_ids.dart';

List<AppUser> seedUsers() => [
      const AppUser(
        id: MockIds.sarahUserId,
        email: 'sarah@example.com',
        fullName: 'Sarah Johnson',
        role: UserRole.patient,
        clinicId: MockIds.defaultClinicId,
        phone: '+1 555-0101',
      ),
      const AppUser(
        id: MockIds.drAhmedUserId,
        email: 'dr.ahmed@mypulse360.clinic',
        fullName: 'Dr. Ahmed Ahmed',
        role: UserRole.doctor,
        clinicId: MockIds.defaultClinicId,
        phone: '+1 555-0102',
      ),
      const AppUser(
        id: MockIds.fatimaUserId,
        email: 'fatima@mypulse360.clinic',
        fullName: 'Fatima Rahman',
        role: UserRole.pharmacist,
        clinicId: MockIds.defaultClinicId,
        phone: '+1 555-0103',
      ),
      const AppUser(
        id: MockIds.patient2Id,
        email: 'james@example.com',
        fullName: 'James Carter',
        role: UserRole.patient,
        clinicId: MockIds.defaultClinicId,
      ),
      const AppUser(
        id: MockIds.patient3Id,
        email: 'mei@example.com',
        fullName: 'Mei Lin',
        role: UserRole.patient,
        clinicId: MockIds.defaultClinicId,
      ),
      const AppUser(
        id: MockIds.patient4Id,
        email: 'omar@example.com',
        fullName: 'Omar Hassan',
        role: UserRole.patient,
        clinicId: MockIds.defaultClinicId,
      ),
    ];

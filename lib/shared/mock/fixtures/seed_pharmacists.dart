import '../../../features/pharmacist/domain/entities/pharmacist_profile.dart';
import '../mock_ids.dart';

List<PharmacistProfile> seedPharmacists() => [
      const PharmacistProfile(
        id: MockIds.fatimaPharmacistId,
        licenseNumber: 'RPH-77410',
        pharmacyName: 'MyPulse360 Clinic Pharmacy',
        clinicId: MockIds.defaultClinicId,
      ),
    ];

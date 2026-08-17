abstract final class RoutePaths {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signUp = '/sign-up';
  static const String onboardingWelcome = '/onboarding/welcome';
  static const String onboardingEmergencyContact = '/onboarding/emergency-contact';
  static const String onboardingHealthcarePreferences = '/onboarding/healthcare-preferences';
  static const String onboardingWellnessGoals = '/onboarding/wellness-goals';
  static const String onboardingHealthProfile = '/onboarding/health-profile';
  static const String forcePasswordChange = '/force-password-change';

  // Patient branch roots
  static const String patientDashboard = '/patient/dashboard';
  static const String patientAppointments = '/patient/appointments';
  static const String patientQueue = '/patient/queue';
  static const String patientAssistant = '/patient/assistant';
  static const String patientPrescriptions = '/patient/prescriptions';
  static const String patientProfile = '/patient/profile';

  // Patient — full-screen pushes (outside the tab shell)
  static const String patientHealthMetricDetail = '/patient/health-metrics/:type';
  static const String patientBookAppointment = '/patient/book-appointment';
  static const String patientHealthOverview = '/patient/health-overview';
  static const String patientAppointmentDetail = '/patient/appointments/:appointmentId';

  // Doctor branch roots
  static const String doctorDashboard = '/doctor/dashboard';
  static const String doctorStaffManagement = '/doctor/staff';
  static const String doctorApplyLeave = '/doctor/apply-leave';
  static const String doctorPatientHistory = '/doctor/patient-history/:patientId';

  // Pharmacist branch roots
  static const String pharmacistDashboard = '/pharmacist/dashboard';
  static const String pharmacistPrescriptions = '/pharmacist/prescriptions';
  static const String pharmacistVerify = '/pharmacist/verify/:prescriptionId';
  static const String pharmacistCreatePrescription = '/pharmacist/create-prescription/:consultationId';

  static String healthMetricDetail(String type) => '/patient/health-metrics/$type';
  static String appointmentDetail(String appointmentId) => '/patient/appointments/$appointmentId';
  static String patientHistory(String patientId, {String? appointmentId}) =>
      appointmentId == null
          ? '/doctor/patient-history/$patientId'
          : '/doctor/patient-history/$patientId?appointmentId=$appointmentId';
  static String verify(String prescriptionId) => '/pharmacist/verify/$prescriptionId';
  static String createPrescription(String consultationId) => '/pharmacist/create-prescription/$consultationId';

  const RoutePaths._();
}

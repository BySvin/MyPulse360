import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/barcode_scanner_sheet.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/scanned_prescription_parser.dart';
import '../providers/prescriptions_providers.dart';

/// Digitizes a paper prescription from an outside prescriber: the patient
/// scans a QR/barcode, the app parses MyPulse360's own JSON schema for a
/// prescription (documented on [parseScannedPrescriptionPayload]), and —
/// after a quick review, since this becomes a permanent health record —
/// saves it. This never touches the pharmacist's own verification queue;
/// it's purely the patient's own copy of something prescribed elsewhere.
class ScanPrescriptionPage extends ConsumerStatefulWidget {
  const ScanPrescriptionPage({super.key});

  @override
  ConsumerState<ScanPrescriptionPage> createState() => _ScanPrescriptionPageState();
}

enum _ScanState { idle, error }

class _ScanPrescriptionPageState extends ConsumerState<ScanPrescriptionPage> {
  _ScanState _state = _ScanState.idle;
  ScannedPrescriptionPayload? _payload;
  bool _saving = false;

  Future<void> _startScan() async {
    final code = await showBarcodeScanner(
      context,
      title: 'Scan prescription',
      instructions: 'Point the camera at your prescription\'s QR code or barcode',
    );
    if (code == null || !mounted) return;

    final payload = parseScannedPrescriptionPayload(code);
    setState(() {
      _payload = payload;
      _state = payload == null ? _ScanState.error : _ScanState.idle;
    });
  }

  Future<void> _save() async {
    final payload = _payload;
    final user = ref.read(currentUserProvider);
    if (payload == null || user == null) return;
    setState(() => _saving = true);
    await ref.read(prescriptionsRepositoryProvider).create(
          Prescription(
            id: '',
            patientId: user.id,
            doctorId: 'external',
            issuedDate: payload.issuedDate,
            expiryDate: payload.expiryDate,
            status: PrescriptionStatus.active,
            items: payload.medications,
            source: PrescriptionSource.scannedExternal,
            externalDoctorName: payload.prescriberName,
          ),
        );
    ref.read(prescriptionsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final payload = _payload;

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Scan Prescription'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: payload != null ? _buildReview(context, colors, payload) : _buildIntro(context, colors),
      ),
    );
  }

  Widget _buildIntro(BuildContext context, AppSemanticColors colors) {
    final hasError = _state == _ScanState.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.patientAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.qr_code_scanner_rounded, size: 30, color: colors.patientAccent),
        ),
        const SizedBox(height: 16),
        Text('Digitize a paper prescription', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          "Scan the QR code or barcode on a prescription from an outside doctor to add it to your list automatically.",
          style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
        ),
        if (hasError) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.danger.withValues(alpha: 0.08),
              border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: colors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Couldn't read a valid prescription from that code. Make sure it's a MyPulse360-format prescription code and try again.",
                    style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        PrimaryButton(label: hasError ? 'Try Again' : 'Start Scanning', onPressed: _startScan),
      ],
    );
  }

  Widget _buildReview(BuildContext context, AppSemanticColors colors, ScannedPrescriptionPayload payload) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review before saving', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Make sure this looks right — it will be saved as a permanent record in your prescriptions.',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payload.prescriberName ?? 'Unknown prescriber',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Issued ${DateFormatters.short(payload.issuedDate)} · '
                      'Expires ${DateFormatters.short(payload.expiryDate)}',
                      style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Medications', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final med in payload.medications) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${med.medicationName} ${med.strength}', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 3),
                      Text(
                        '${med.frequency} · ${med.durationDays} days · Qty ${med.quantity} ${med.unit}',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                      if (med.instructions.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(med.instructions, style: TextStyle(fontSize: 11.5, color: colors.textTertiary)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => setState(() => _payload = null),
                child: const Text('Rescan'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(label: 'Save to My Prescriptions', onPressed: _save, loading: _saving),
            ),
          ],
        ),
      ],
    );
  }
}

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
import '../../domain/entities/prescription_item.dart';
import '../../domain/scanned_prescription_parser.dart';
import '../providers/prescriptions_providers.dart';

/// Digitizes a paper prescription from an outside prescriber: the patient
/// scans a QR/barcode and reviews (and, when needed, fills in) the details
/// before saving. Most real-world codes — a barcode off a medicine box, say
/// — aren't in MyPulse360's own JSON schema, so anything scanned is accepted
/// and turned into an editable draft rather than rejected outright. This
/// never touches the pharmacist's own verification queue; it's purely the
/// patient's own copy of something prescribed elsewhere.
class ScanPrescriptionPage extends ConsumerStatefulWidget {
  const ScanPrescriptionPage({super.key});

  @override
  ConsumerState<ScanPrescriptionPage> createState() => _ScanPrescriptionPageState();
}

enum _ScanState { idle, error }

class _MedFormControllers {
  _MedFormControllers(PrescriptionItem item)
      : name = TextEditingController(text: item.medicationName),
        strength = TextEditingController(text: item.strength),
        quantity = TextEditingController(text: item.quantity.toString()),
        unit = TextEditingController(text: item.unit),
        frequency = TextEditingController(text: item.frequency),
        durationDays = TextEditingController(text: item.durationDays.toString()),
        instructions = TextEditingController(text: item.instructions),
        form = item.form,
        refillsAllowed = item.refillsAllowed;

  final TextEditingController name;
  final TextEditingController strength;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController frequency;
  final TextEditingController durationDays;
  final TextEditingController instructions;
  final String form;
  final int refillsAllowed;

  void dispose() {
    name.dispose();
    strength.dispose();
    quantity.dispose();
    unit.dispose();
    frequency.dispose();
    durationDays.dispose();
    instructions.dispose();
  }
}

class _ScanPrescriptionPageState extends ConsumerState<ScanPrescriptionPage> {
  _ScanState _state = _ScanState.idle;
  ScannedPrescriptionPayload? _payload;
  final TextEditingController _prescriberController = TextEditingController();
  List<_MedFormControllers> _medControllers = [];
  String? _validationError;
  bool _saving = false;

  @override
  void dispose() {
    _prescriberController.dispose();
    for (final c in _medControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _startScan() async {
    final code = await showBarcodeScanner(
      context,
      title: 'Scan prescription',
      instructions: 'Point the camera at your prescription\'s QR code or barcode',
    );
    if (code == null || !mounted) return;

    if (code.trim().isEmpty) {
      setState(() => _state = _ScanState.error);
      return;
    }

    final payload = parseScannedPrescriptionPayload(code) ?? buildFallbackScannedPayload(code);
    _applyPayload(payload);
  }

  void _applyPayload(ScannedPrescriptionPayload payload) {
    for (final c in _medControllers) {
      c.dispose();
    }
    setState(() {
      _payload = payload;
      _state = _ScanState.idle;
      _validationError = null;
      _prescriberController.text = payload.prescriberName ?? '';
      _medControllers = payload.medications.map(_MedFormControllers.new).toList();
    });
  }

  void _rescan() {
    for (final c in _medControllers) {
      c.dispose();
    }
    setState(() {
      _payload = null;
      _medControllers = [];
      _validationError = null;
    });
  }

  Future<void> _save() async {
    final payload = _payload;
    final user = ref.read(currentUserProvider);
    if (payload == null || user == null) return;

    final items = <PrescriptionItem>[];
    for (var i = 0; i < _medControllers.length; i++) {
      final c = _medControllers[i];
      final name = c.name.text.trim();
      if (name.isEmpty) continue;
      items.add(
        PrescriptionItem(
          id: 'scanned-item-$i',
          medicationName: name,
          strength: c.strength.text.trim(),
          form: c.form,
          quantity: int.tryParse(c.quantity.text.trim()) ?? 1,
          unit: c.unit.text.trim().isEmpty ? 'units' : c.unit.text.trim(),
          frequency: c.frequency.text.trim().isEmpty ? 'As directed' : c.frequency.text.trim(),
          durationDays: int.tryParse(c.durationDays.text.trim()) ?? 30,
          instructions: c.instructions.text.trim(),
          refillsAllowed: c.refillsAllowed,
        ),
      );
    }

    if (items.isEmpty) {
      setState(() => _validationError = 'Enter at least a medication name before saving.');
      return;
    }

    setState(() {
      _validationError = null;
      _saving = true;
    });

    final prescriberName = _prescriberController.text.trim();
    await ref.read(prescriptionsRepositoryProvider).create(
          Prescription(
            id: '',
            patientId: user.id,
            doctorId: 'external',
            issuedDate: payload.issuedDate,
            expiryDate: payload.expiryDate,
            status: PrescriptionStatus.active,
            items: items,
            source: PrescriptionSource.scannedExternal,
            externalDoctorName: prescriberName.isEmpty ? null : prescriberName,
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
        child: payload != null ? _buildReview(context, colors) : _buildIntro(context, colors),
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
          "Scan the QR code or barcode on a prescription or medicine box to add it to your list. "
          "You'll get a chance to review and fill in the details before it's saved.",
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
                    "That code didn't have anything readable on it. Try scanning again.",
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

  Widget _buildReview(BuildContext context, AppSemanticColors colors) {
    final payload = _payload!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review before saving', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          "We couldn't always tell exactly what was on the code — check the details below and fix anything "
          'before saving. This will be kept as a permanent record in your prescriptions.',
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
                    TextField(
                      controller: _prescriberController,
                      decoration: const InputDecoration(labelText: 'Prescriber (optional)', isDense: true),
                    ),
                    const SizedBox(height: 8),
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
              for (final c in _medControllers) ...[
                _medicationCard(context, colors, c),
                const SizedBox(height: 8),
              ],
              if (_validationError != null) ...[
                const SizedBox(height: 4),
                Text(_validationError!, style: TextStyle(fontSize: 12, color: colors.danger)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _rescan,
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

  Widget _medicationCard(BuildContext context, AppSemanticColors colors, _MedFormControllers c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: c.name,
            style: Theme.of(context).textTheme.titleSmall,
            decoration: const InputDecoration(labelText: 'Medication name', isDense: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: c.strength,
                  decoration: const InputDecoration(labelText: 'Strength', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: c.quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: c.unit,
                  decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: c.frequency,
                  decoration: const InputDecoration(labelText: 'Frequency', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c.durationDays,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duration (days)', isDense: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c.instructions,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Instructions', isDense: true),
          ),
        ],
      ),
    );
  }
}

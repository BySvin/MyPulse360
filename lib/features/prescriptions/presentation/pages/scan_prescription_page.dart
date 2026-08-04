import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/barcode_scanner_sheet.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/entities/prescription_item.dart';
import '../../domain/scanned_prescription_ocr.dart';
import '../../domain/scanned_prescription_parser.dart';
import '../providers/prescriptions_providers.dart';

/// Digitizes a paper prescription from an outside prescriber: the patient
/// scans a QR/barcode or takes a photo, then reviews (and, when needed,
/// fills in) the details before saving. Most real-world codes — a barcode
/// off a medicine box, say — aren't in MyPulse360's own JSON schema and
/// can't encode things like expiry date at all, so both paths land on the
/// same editable draft rather than presenting a guess as fact. This never
/// touches the pharmacist's own verification queue; it's purely the
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
  DateTime _issuedDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  String? _validationError;
  bool _saving = false;
  bool _processingPhoto = false;

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

  Future<void> _takePhoto() async {
    XFile? photo;
    try {
      photo = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2000);
    } catch (_) {
      photo = null;
    }
    if (photo == null || !mounted) return;

    setState(() => _processingPhoto = true);

    var recognizedText = '';
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      recognizedText = (await recognizer.processImage(InputImage.fromFilePath(photo.path))).text;
    } catch (_) {
      recognizedText = '';
    } finally {
      await recognizer.close();
    }
    if (!mounted) return;

    final payload =
        recognizedText.trim().isEmpty ? buildFallbackScannedPayload('') : buildPayloadFromOcrText(recognizedText);
    setState(() => _processingPhoto = false);
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
      _issuedDate = payload.issuedDate;
      _expiryDate = payload.expiryDate;
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
    final user = ref.read(currentUserProvider);
    if (_payload == null || user == null) return;

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
            issuedDate: _issuedDate,
            expiryDate: _expiryDate,
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
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _processingPhoto ? null : _takePhoto,
          icon: _processingPhoto
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.camera_alt_outlined, size: 18),
          label: Text(_processingPhoto ? 'Reading photo…' : 'Take a Photo Instead'),
        ),
      ],
    );
  }

  Widget _buildReview(BuildContext context, AppSemanticColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review before saving', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          "These are our best guesses, not confirmed facts — double-check everything, especially the expiry "
          'date, and fix anything before saving. This will be kept as a permanent record in your prescriptions.',
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
                    Row(
                      children: [
                        Expanded(child: _dateField(context, colors, 'Issued', _issuedDate, (d) {
                          setState(() => _issuedDate = d);
                        })),
                        const SizedBox(width: 16),
                        Expanded(child: _dateField(context, colors, 'Expires', _expiryDate, (d) {
                          setState(() => _expiryDate = d);
                        })),
                      ],
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

  Widget _dateField(
    BuildContext context,
    AppSemanticColors colors,
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: colors.textTertiary)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                DateFormatters.short(value),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_calendar_outlined, size: 13, color: colors.textTertiary),
            ],
          ),
        ],
      ),
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

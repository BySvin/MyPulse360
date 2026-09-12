import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/primary_button.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../providers/pharmacist_providers.dart';

class TemperatureInputDialog extends ConsumerStatefulWidget {
  const TemperatureInputDialog({
    super.key,
    required this.appointment,
    required this.patientName,
  });

  final Appointment appointment;
  final String patientName;

  @override
  ConsumerState<TemperatureInputDialog> createState() => _TemperatureInputDialogState();
}

class _TemperatureInputDialogState extends ConsumerState<TemperatureInputDialog> {
  final _tempController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tempStr = _tempController.text.trim();
    if (tempStr.isEmpty) return;

    final temp = double.tryParse(tempStr);
    if (temp == null) return;

    setState(() => _saving = true);
    
    await ref.read(pharmacistRepositoryProvider).logTemperature(
      widget.appointment.id,
      widget.appointment.patientId,
      widget.appointment.doctorId,
      temp,
    );
    
    ref.read(appointmentsRevisionProvider.notifier).state++;
    
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    return AlertDialog(
      title: Text('Log Vitals for ${widget.patientName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter patient body temperature in Celsius:'),
          const SizedBox(height: 12),
          TextField(
            controller: _tempController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Temperature (°C)',
              hintText: 'e.g. 37.5',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          label: 'Save',
          fullWidth: false,
          color: colors.clinicianAccent,
          onPressed: _saving ? () {} : _submit,
          loading: _saving,
        ),
      ],
    );
  }
}

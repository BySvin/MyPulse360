import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Opens a full-screen camera barcode/QR scanner and returns the first
/// decoded value, or null if the user cancels. Real camera capture via the
/// `mobile_scanner` package — works on any device/emulator with a camera
/// and the permission granted; there's no special developer-account
/// requirement the way HealthKit/Fitbit integrations would need. Shared
/// across features (pharmacist inventory stock-in, patient prescription
/// scanning) since the scanning mechanics are identical either way.
Future<String?> showBarcodeScanner(
  BuildContext context, {
  String title = 'Scan barcode',
  String instructions = 'Point the camera at a barcode or QR code',
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => _BarcodeScannerPage(title: title, instructions: instructions),
      fullscreenDialog: true,
    ),
  );
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage({required this.title, required this.instructions});

  final String title;
  final String instructions;

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final _controller = MobileScannerController();
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_rounded),
            tooltip: 'Toggle flash',
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(
            width: 240,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Positioned(
            bottom: 40,
            child: Text(
              widget.instructions,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

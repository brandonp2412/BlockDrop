import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../multiplayer/direct_join_invite.dart';

/// Test seam for camera-denial handling without requiring hardware access.
typedef QrReaderBuilder = Widget Function(
  ValueChanged<String?> onDetected,
  VoidCallback onCameraUnavailable,
);

/// Decodes a locally scanned QR invitation without any online service.
class MultiplayerQrScannerScreen extends StatefulWidget {
  final QrReaderBuilder? readerBuilder;

  const MultiplayerQrScannerScreen({super.key, this.readerBuilder});

  @override
  State<MultiplayerQrScannerScreen> createState() =>
      _MultiplayerQrScannerScreenState();
}

class _MultiplayerQrScannerScreenState
    extends State<MultiplayerQrScannerScreen> {
  bool _completed = false;
  String? _error;

  void _onScanCode(String? value) {
    if (!mounted || _completed || value == null) return;
    try {
      final invite = DirectJoinInvite.fromUri(value);
      if (invite.expiresAt?.isBefore(DateTime.now()) ?? false) {
        throw const FormatException(
            'Pairing code expired; ask the host to refresh it.');
      }
      _completed = true;
      Navigator.of(context).pop(value);
    } on FormatException {
      if (mounted) {
        setState(() => _error = 'Not a valid, unexpired BlockDrop invitation.');
      }
    }
  }

  void _cameraUnavailable() {
    if (mounted) {
      setState(() => _error =
          'Camera unavailable or permission denied. Go back and join manually.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan host QR code')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: widget.readerBuilder?.call(
                      _onScanCode,
                      _cameraUnavailable,
                    ) ??
                    ReaderWidget(
                      codeFormat: Format.qrCode,
                      showGallery: false,
                      onScan: (code) {
                        if (code.isValid) _onScanCode(code.text);
                      },
                      onControllerCreated: (_, error) {
                        if (error != null) _cameraUnavailable();
                      },
                    ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, key: const Key('scanner-error')),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Enter details manually'),
                ),
              ),
            ],
          ),
        ),
      );
}

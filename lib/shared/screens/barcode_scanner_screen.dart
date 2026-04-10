import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Returns the scanned barcode string, or null if cancelled.
/// Call this instead of pushing the route directly.
Future<String?> scanBarcode(BuildContext context) {
  if (!Platform.isAndroid && !Platform.isIOS) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Barcode scanning is only available on mobile devices.'),
      ),
    );
    return Future.value(null);
  }

  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
  );
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _popped = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_popped) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null && code.isNotEmpty) {
      _popped = true;
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:    const Text('Scan Barcode'),
        actions: [
          // Torch toggle
          IconButton(
            icon:    const Icon(Icons.flashlight_on_outlined),
            tooltip: 'Toggle torch',
            onPressed: _controller.toggleTorch,
          ),
          // Camera flip
          IconButton(
            icon:    const Icon(Icons.flip_camera_ios_outlined),
            tooltip: 'Flip camera',
            onPressed: _controller.switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect:   _onDetect,
          ),

          // Overlay with scan window
          _ScanOverlay(),

          // Bottom hint
          Positioned(
            bottom: 48,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color:        Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Point camera at a barcode',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Darkens everything outside a centered scan window.
class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w      = constraints.maxWidth;
      final h      = constraints.maxHeight;
      final side   = w * 0.7;
      final left   = (w - side) / 2;
      final top    = (h - side) / 2 - 40;

      return Stack(
        children: [
          // Dark mask with hole
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
                Colors.black54, BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color:            Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Positioned(
                  left: left, top: top,
                  width: side, height: side,
                  child: Container(
                    decoration: BoxDecoration(
                      color:        Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Corner brackets
          Positioned(
            left: left, top: top,
            width: side, height: side,
            child: _Brackets(),
          ),
        ],
      );
    });
  }
}

/// Draws the 4 corner L-shapes around the scan window.
class _Brackets extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const color     = Colors.white;
    const thickness = 3.0;
    const length    = 20.0;
    const r         = 8.0;

    return CustomPaint(
      painter: _BracketPainter(
        color:     color,
        thickness: thickness,
        length:    length,
        radius:    r,
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color  color;
  final double thickness;
  final double length;
  final double radius;

  const _BracketPainter({
    required this.color,
    required this.thickness,
    required this.length,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = thickness
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawPath(
        Path()
          ..moveTo(0, length)
          ..lineTo(0, radius)
          ..arcToPoint(Offset(radius, 0),
              radius: Radius.circular(radius))
          ..lineTo(length, 0),
        paint);

    // Top-right
    canvas.drawPath(
        Path()
          ..moveTo(w - length, 0)
          ..lineTo(w - radius, 0)
          ..arcToPoint(Offset(w, radius),
              radius: Radius.circular(radius))
          ..lineTo(w, length),
        paint);

    // Bottom-left
    canvas.drawPath(
        Path()
          ..moveTo(0, h - length)
          ..lineTo(0, h - radius)
          ..arcToPoint(Offset(radius, h),
              radius: Radius.circular(radius))
          ..lineTo(length, h),
        paint);

    // Bottom-right
    canvas.drawPath(
        Path()
          ..moveTo(w - length, h)
          ..lineTo(w - radius, h)
          ..arcToPoint(Offset(w, h - radius),
              radius: Radius.circular(radius))
          ..lineTo(w, h - length),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

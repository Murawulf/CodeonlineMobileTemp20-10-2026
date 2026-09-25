import 'package:codeonline_info/core/commun/appBar.dart';
import 'package:codeonline_info/core/config/theme/app_colors.dart';
import 'package:codeonline_info/presentation/search/pages/ProductDetailsScreen.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with TickerProviderStateMixin {
  String? scannedValue;
  bool isScanned = false;

  late AnimationController _animationController;
  MobileScannerController cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Stack(
        alignment: Alignment.center,
        children: [
          /// 🔥 NEW QR SCANNER (mobile_scanner)
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (isScanned) return;

              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              final String? code = barcodes.first.rawValue;

              if (code == null) return;

              setState(() {
                scannedValue = code;
                isScanned = true;
              });

              cameraController.stop();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProductDetailScreen(gtin: scannedValue ?? ''),
                ),
              ).then((_) {
                setState(() {
                  isScanned = false;
                });
                cameraController.start();
              });
            },
          ),

          /// SCAN FRAME UI - flat, on-theme (single blue accent instead of
          /// a mismatched green/red pairing), rounded corners kept subtle.
          Positioned(
            top: 150,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          /// ANIMATED SCAN LINE
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned(
                top: 150 + (_animationController.value * 250),
                child: Container(
                  width: 250,
                  height: 3,
                  color: AppColors.accent,
                ),
              );
            },
          ),

          Positioned(
            bottom: 80,
            child: Text(
              'Align QR Code or Barcode within the frame',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../data/service/location_service/location_service.dart';

class ScanQrTab extends StatefulWidget {
  const ScanQrTab({super.key});

  @override
  State<ScanQrTab> createState() => _ScanQrTabState();
}

class _ScanQrTabState extends State<ScanQrTab> {
  bool _isScanning = true;
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();

  // Maximum allowed distance in meters
  static const double _maxDistanceMeters = 10.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleOnDetect(BarcodeCapture capture) {
    if (!_isScanning || _isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

    _processQrCode(rawValue);
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _isScanning = false;
    });

    try {
      final BarcodeCapture? capture =
          await _controller.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? rawValue = capture.barcodes.first.rawValue;
        if (rawValue != null) {
          _processQrCode(rawValue);
        } else {
          _showStatusPopup(isSuccess: false, message: "No Data in QR code");
        }
      } else {
        _showStatusPopup(
            isSuccess: false, message: "No QR code found in image");
      }
    } catch (e) {
      _showStatusPopup(
          isSuccess: false, message: "Failed to analyze image: $e");
    }
  }

  void _processQrCode(String rawValue) async {
    setState(() {
      _isProcessing = true;
      _isScanning = false; // Pause scanning
    });

    try {
      // 1. Parse QR Data (Expected "LAT,LNG")
      final parts = rawValue.split(',');
      if (parts.length != 2) throw "Invalid QR Format";

      final double qrLat = double.parse(parts[0].trim());
      final double qrLng = double.parse(parts[1].trim());

      // 2. Get User's Current Location
      final position = await LocationService.getCurrentLocation();

      // 3. Calculate Distance using Geolocator
      final double distance = Geolocator.distanceBetween(
        qrLat,
        qrLng,
        position.latitude,
        position.longitude,
      );

      // 4. Validate Distance
      if (distance <= _maxDistanceMeters) {
        _showStatusPopup(
          isSuccess: true,
          message:
              "Attendance Marked!\nDistance: ${distance.toStringAsFixed(2)}m",
        );
      } else {
        _showStatusPopup(
          isSuccess: false,
          message:
              "Attendance Failed.\nYou are ${distance.toStringAsFixed(2)}m away.\nAllowed: ${_maxDistanceMeters}m",
        );
      }
    } catch (e) {
      _showStatusPopup(
        isSuccess: false,
        message: "Error processing QR: $e",
      );
    }
  }

  void _showStatusPopup({required bool isSuccess, required String message}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Status",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Container();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.elasticOut,
          ),
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(20),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnimatedIcon(isSuccess: isSuccess),
                const SizedBox(height: 20),
                Text(
                  isSuccess ? "Success" : "Failed",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isSuccess ? Colors.green : Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _isProcessing = false;
                        _isScanning = true; // Resume scanning
                      });
                    },
                    child: const Text("OK"),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Scanner Area
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                )
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleOnDetect,
                  // Configure controller if needed for detailed settings
                ),
                // Custom Overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _isScanning
                        ? const _ScanningLine()
                        : null,
                  ),
                ),
                // Flash and Gallery Buttons
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _controller.toggleTorch(),
                        icon: const Icon(Icons.flash_on,
                            color: Colors.white, size: 30),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.image,
                            color: Colors.white, size: 30),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Instructions
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Column(
              children: [
                Text(
                  "Scan Attendance QR",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "Ensure you are within 10 meters of the location where the QR was generated.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanningLine extends StatefulWidget {
  const _ScanningLine();

  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = Tween<double>(begin: 0, end: 250).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: _animation.value,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.5),
                      blurRadius: 10.0,
                      spreadRadius: 2.0,
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedIcon extends StatefulWidget {
  final bool isSuccess;

  const _AnimatedIcon({required this.isSuccess});

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isSuccess
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
        ),
        child: Icon(
          widget.isSuccess ? Icons.check_circle : Icons.error,
          color: widget.isSuccess ? Colors.green : Colors.red,
          size: 80,
        ),
      ),
    );
  }
}

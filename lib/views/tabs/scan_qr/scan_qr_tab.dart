import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  // Maximum allowed distance in meters
  static const double _maxDistanceMeters = 10.0;

  void _handleOnDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

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
    } finally {
      // Logic handled in popup close
    }
  }

  void _showStatusPopup({required bool isSuccess, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
                size: 80,
              ),
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
                      backgroundColor:
                      isSuccess ? Colors.green : Colors.red,
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                )
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                MobileScanner(
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

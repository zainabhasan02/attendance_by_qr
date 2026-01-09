import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TestQrScreen2 extends StatefulWidget {
  const TestQrScreen2({super.key});

  @override
  State<TestQrScreen2> createState() => _TestQrScreen2State();
}

class _TestQrScreen2State extends State<TestQrScreen2> {
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final FlutterTts flutterTts = FlutterTts();

  // Aapka office ka exact location
  static const double officeLat = 26.876187716000537;
  static const double officeLon = 75.72635379251344;
  static const double maxAllowedRadius = 80.0; // meters (practical value)

  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("hi-IN");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  Future<Position?> _getCurrentPositionWithRetry() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorDialog("Location services are disabled.");
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorDialog("Location permission denied.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorDialog("Location permission permanently denied.");
      return null;
    }

    // Multiple attempts to get better accuracy
    Position? bestPosition;
    double bestAccuracy = 9999;

    for (int i = 0; i < 3; i++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best, // Highest accuracy
            distanceFilter: 0,
          ),
        );

        print("Attempt ${i + 1}: Accuracy ${position.accuracy}m");

        if (position.accuracy < bestAccuracy) {
          bestAccuracy = position.accuracy;
          bestPosition = position;
        }

        // Agar accuracy already achhi hai to break
        if (bestAccuracy < 25) break;

        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print("Location error: $e");
      }
    }

    return bestPosition;
  }

  Future<void> _processScan(Barcode barcode) async {
    if (!isScanning) return;
    isScanning = false;

    final String? code = barcode.rawValue;
    if (code == null || code.isEmpty) {
      _showErrorDialog("Invalid QR code");
      _resetScanning();
      return;
    }

    print("Scanned QR: $code");

    // QR code mein lat,long expect kar rahe hain (example: "26.876187716000537,75.72635379251344")
    List<String> parts = code.split(',');
    if (parts.length != 2) {
      _showErrorDialog("QR code format invalid.\nExpected: lat,long");
      _resetScanning();
      return;
    }

    double? qrLat = double.tryParse(parts[0].trim());
    double? qrLon = double.tryParse(parts[1].trim());

    if (qrLat == null || qrLon == null) {
      _showErrorDialog("Invalid latitude/longitude in QR");
      _resetScanning();
      return;
    }

    // Ab current location lete hain
    Position? currentPosition = await _getCurrentPositionWithRetry();

    if (currentPosition == null) {
      _resetScanning();
      return;
    }

    double distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      qrLat,
      qrLon,
    );

    print("QR Location: $qrLat, $qrLon");
    print(
      "Your Location: ${currentPosition.latitude}, ${currentPosition.longitude}",
    );
    print("Distance: ${distance.toStringAsFixed(2)} m");
    print("Accuracy: ${currentPosition.accuracy} m");

    if (distance <= maxAllowedRadius) {
      _showWelcomePopup();
    } else {
      _showTooFarPopup(distance);
    }
  }

  void _showWelcomePopup() {
    _speak("Welcome to Proftcode office! Aap office ke andar hain.");
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "🎉 Welcome!",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 80),
                SizedBox(height: 16),
                Text(
                  "Aap office ke andar hain!\nAttendance marked successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.pop(context);
                  _resetScanning();
                },
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  void _showTooFarPopup(double distance) {
    _speak(
      "Aap office se bahar hain. Distance: ${distance.toStringAsFixed(0)} meter",
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Too Far Away!",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, color: Colors.red, size: 80),
                const SizedBox(height: 16),
                Text(
                  "Aap office se bahar hain.\nDistance: ${distance.toStringAsFixed(0)} meter\n(Allowed: $maxAllowedRadius m)",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _resetScanning();
                },
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Error"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetScanning();
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  void _resetScanning() {
    setState(() {
      isScanning = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Office Attendance QR Scan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processScan(barcode);
                  break;
                }
              }
            },
          ),
          if (!isScanning) const Center(child: CircularProgressIndicator()),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                isScanning ? "Scan QR to mark attendance" : "Processing...",
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    flutterTts.stop();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanSpeakScreen extends StatefulWidget {
  const QrScanSpeakScreen({super.key});

  @override
  State<QrScanSpeakScreen> createState() => _QrScanSpeakScreenState();
}

class _QrScanSpeakScreenState extends State<QrScanSpeakScreen> {
  bool scanned = false;
  final FlutterTts flutterTts = FlutterTts();

  static const double allowedDistance = 5.0; // meters
  static const double maxAccuracy = 15.0; // meters

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
  }

  Future<Position?> _getAccurateLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception("Location services disabled");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied forever.");
    }

    Position? bestPosition;
    double bestAccuracy = double.infinity;
    for (int i = 0; i < 5; i++) {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 15),
        ),
      );

      debugPrint("Attempt ${i + 1}: Accuracy ${pos.accuracy} m");

      if (pos.isMocked) {
        throw Exception("Fake GPS detected");
      }

      if (pos.accuracy < bestAccuracy) {
        bestAccuracy = pos.accuracy;
        bestPosition = pos;
      }

      if (pos.accuracy <= maxAccuracy) {
        return pos;
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    if (bestAccuracy > maxAccuracy) {
      throw Exception("Location not accurate enough");
    }

    return bestPosition!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      appBar: AppBar(title: const Text("Scan QR Location")),
      body: Column(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
              backgroundColor: Colors.amber.shade300,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              scanned = false;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _scannerView()),
              );
            },
            child: const Text("Gemini"),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
              backgroundColor: Colors.amber.shade300,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              scanned = false;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _scannerView()),
              );
            },
            child: const Text("Scan QR"),
          ),
        ],
      ),
    );
  }

  Widget _scannerView() {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade500,
      appBar: AppBar(title: const Text("Scanning QR Code...")),
      body: MobileScanner(
        onDetect: (capture) async {
          if (scanned) return;
          scanned = true;

          final raw = capture.barcodes.first.rawValue;
          if (raw == null || !raw.contains(",")) {
            _showResult("Invalid QR Code", 0, false);
            return;
          }

          try {
            final parts = raw.split(",");
            final double qrLat = double.parse(parts[0].trim());
            final double qrLng = double.parse(parts[1].trim());

            final userPos = await _getAccurateLocation();

            final distance = Geolocator.distanceBetween(
              userPos!.latitude,
              userPos.longitude,
              qrLat,
              qrLng,
            );

            debugPrint("QR Location: $qrLat, $qrLng");
            debugPrint(
              "Your Location: ${userPos.latitude}, ${userPos.longitude}",
            );
            debugPrint("Accuracy: ${userPos.accuracy} m");
            debugPrint("Distance: ${distance.toStringAsFixed(2)} m");

            final bool isPresent =
                userPos.accuracy <= maxAccuracy && distance <= allowedDistance;

            final message = isPresent ? "Hello" : "Too far away";
            await flutterTts.speak(message);

            _showResult(message, distance, isPresent);
          } catch (e) {
            debugPrint("Error: $e");
            await flutterTts.speak("Error: $e");
            _showResult("Error", -1, false);
          }
        },
      ),
    );
  }

  // ---------------- RESULT ----------------
  void _showResult(String message, double distance, bool success) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                  size: 80,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                if (distance >= 0)
                  Text(
                    "Distance: ${distance.toStringAsFixed(1)} meters",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  const Text(
                    "Distance unavailable (low GPS accuracy)",
                    style: TextStyle(fontSize: 16),
                  ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // bottom sheet
                    Navigator.pop(context); // scanner
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          ),
    );
  }
}

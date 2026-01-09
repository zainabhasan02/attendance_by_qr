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

  static const double allowedRadius = 30.0; // Fixed 30 meters

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
  }

  Future<Position> _getBestLocation() async {
    // ... (same as previous code - permission checks, multiple attempts, etc.)
    // मैंने previous वाला _getBestLocation() same रखा है accuracy के लिए

    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception("Location services are disabled.");

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied forever.");
    }

    LocationSettings locationSettings;
    locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
    );
    /*if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 2),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.other,
      );
    } else {
      locationSettings = const LocationSettings(accuracy: LocationAccuracy.bestForNavigation);
    }*/

    Position? bestPosition;
    double bestAccuracy = double.infinity;

    for (int i = 0; i < 5; i++) {
      try {
        final Position position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings,
          timeLimit: const Duration(seconds: 15),
        );

        if (position.isMocked) {
          throw Exception("Fake GPS detected!");
        }

        debugPrint("Attempt ${i + 1}: Accuracy ${position.accuracy}m");

        if (position.accuracy < bestAccuracy) {
          bestAccuracy = position.accuracy;
          bestPosition = position;
        }

        if (position.accuracy <= 20.0) {
          return position;
        }
      } catch (e) {
        debugPrint("Attempt ${i + 1} failed: $e");
      }

      if (i < 4) await Future.delayed(const Duration(seconds: 3));
    }

    if (bestPosition == null) {
      throw Exception("Failed to get reliable location.");
    }

    return bestPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Location")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            scanned = false;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _scannerView()),
            );
          },
          child: const Text("Scan QR"),
        ),
      ),
    );
  }

  Widget _scannerView() {
    return Scaffold(
      appBar: AppBar(title: const Text("Scanning QR Code...")),
      body: MobileScanner(
        onDetect: (capture) async {
          if (scanned) return;
          scanned = true;

          final raw = capture.barcodes.first.rawValue;
          if (raw == null || !raw.contains(",")) {
            _showResult("Invalid QR Code", "N/A", "N/A", 0, false);
            return;
          }

          try {
            final parts = raw.split(",");
            final double qrLat = double.parse(parts[0].trim());
            final double qrLng = double.parse(parts[1].trim());

            final userPos = await _getBestLocation();

            final distance = Geolocator.distanceBetween(
              userPos.latitude,
              userPos.longitude,
              qrLat,
              qrLng,
            );

            final effectiveRadius = allowedRadius + userPos.accuracy;

            debugPrint("QR Location: $qrLat, $qrLng");
            debugPrint(
              "Your Location: ${userPos.latitude}, ${userPos.longitude}",
            );
            debugPrint("Distance: ${distance.toStringAsFixed(2)} m");
            debugPrint(
              "Effective Radius: ${effectiveRadius.toStringAsFixed(2)} m",
            );

            final bool isPresent = distance <= effectiveRadius;

            String message =
                isPresent ? "You are present!" : "You are too far away!";
            await flutterTts.speak(message);

            _showResult(
              message,
              "${qrLat.toStringAsFixed(6)}, ${qrLng.toStringAsFixed(6)}",
              "${userPos.latitude.toStringAsFixed(6)}, ${userPos.longitude.toStringAsFixed(6)}",
              distance,
              isPresent,
            );
          } catch (e) {
            debugPrint("Error: $e");
            _showResult("Error: Unable to process", "N/A", "N/A", 0, false);
          }
        },
      ),
    );
  }

  void _showResult(
    String message,
    String qrLocation,
    String userLocation,
    double distance,
    bool success,
  ) {
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
                const SizedBox(height: 20),
                Text(
                  "QR Location:\n$qrLocation",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  "Your Location:\n$userLocation",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  "Distance: ${distance.toStringAsFixed(1)} meters",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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

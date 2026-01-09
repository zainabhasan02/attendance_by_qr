import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

class TestQrScreen extends StatefulWidget {
  const TestQrScreen({super.key});

  @override
  State<TestQrScreen> createState() => _TestQrScreenState();
}

class _TestQrScreenState extends State<TestQrScreen> {
  MobileScannerController controller = MobileScannerController();
  FlutterTts flutterTts = FlutterTts();
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("En-IN");
    await flutterTts.setSpeechRate(0.9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner - Attendance'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (!isScanning) return;
              isScanning = false;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  _processScannedCode(code);
                  break;
                }
              }
            },
          ),
          // Overlay for better UX
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _processScannedCode(String code) {
    print("Scanned: $code");

    code = code.trim();

    // ────────────────────────────────────────────────
    // 1. Plain coordinates → welcome popup
    // ────────────────────────────────────────────────
    final RegExp coordRegex = RegExp(
      r'^[-+]?[0-9]{1,3}\.[0-9]+[,\s]+[-+]?[0-9]{1,3}\.[0-9]+$',
      multiLine: false,
      caseSensitive: false,
    );

    final plainMatch = coordRegex.firstMatch(code);
    if (plainMatch != null) {
      final parts = code.split(RegExp(r'[,\s]+'));
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) {
          print("Detected plain coordinates → showing welcome");
          _showWelcomeDialog(lat, lng);
          return;
        }
      }
    }

    // ────────────────────────────────────────────────
    // 2. Looks like a maps link → open in map app/browser
    // ────────────────────────────────────────────────
    final lower = code.toLowerCase();

    if (lower.contains('maps.google') ||
        lower.contains('maps.app.goo.gl') ||
        lower.contains('google.com/maps') ||
        lower.contains('@') &&
            lower.contains(',') &&
            lower.contains('google')) {
      print("Detected map link → opening externally");
      _openExternalUrl(code);
      return;
    }

    // Alternative: contains typical coordinate pattern inside URL
    final urlCoordMatch = RegExp(
      r'[@!][-,+]?[0-9]{1,3}\.[0-9]+[,!][-,+]?[0-9]{1,3}\.[0-9]+',
    ).firstMatch(code);
    if (urlCoordMatch != null) {
      print("Detected coordinates inside URL → treating as map link");
      _openExternalUrl(code);
      return;
    }

    // ────────────────────────────────────────────────
    // 3. Looks like normal website URL → open browser
    // ────────────────────────────────────────────────
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      print("Detected website URL → opening in browser");
      _openExternalUrl(code);
      return;
    }

    // ────────────────────────────────────────────────
    // Fallback: unknown format
    // ────────────────────────────────────────────────
    _showErrorDialog("Unsupported QR content.\n\nScanned:\n$code");
  }

  /*void _processScannedCode(String code) {
    print("Scanned: $code");

    // Try to extract lat,lng from different formats
    double? lat;
    double? lng;

    // Case 1: Plain "lat,lng" or "lat lng"
    final RegExp plainRegex = RegExp(
      r'([-+]?[0-9]*\.?[0-9]+)[,\s]+([-+]?[0-9]*\.?[0-9]+)',
    );
    final plainMatch = plainRegex.firstMatch(code);
    if (plainMatch != null) {
      lat = double.tryParse(plainMatch.group(1)!);
      lng = double.tryParse(plainMatch.group(2)!);
      print("CASE 1: Plain lat,lng detected");
    }

    // Case 2: Google Maps short link like https://maps.app.goo.gl/xxxx
    if (lat == null || lng == null) {
      final RegExp shortLinkRegex = RegExp(
        r'maps\.app\.goo\.gl/([a-zA-Z0-9]+)',
      );
      final shortMatch = shortLinkRegex.firstMatch(code);
      if (shortMatch != null) {
        // For real app, you would need to resolve short link
        // Here assuming QR contains actual coordinates
      }
    }

    // Case 3: Full Google Maps URL with @lat,lng
    if (lat == null || lng == null) {
      final RegExp fullUrlRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
      final fullMatch = fullUrlRegex.firstMatch(code);
      if (fullMatch != null) {
        lat = double.tryParse(fullMatch.group(1)!);
        lng = double.tryParse(fullMatch.group(2)!);
        print("CASE 3: Full URL @lat,lng detected");
      }
    }

    if (lat != null && lng != null) {
      _showWelcomeDialog(lat, lng);
    } else {
      _showErrorDialog("Invalid QR code! Could not find location.");
    }
  }*/

  // Open any URL externally (maps or website)
  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode:
            LaunchMode
                .externalApplication, // ← important: open in Chrome/Maps app
      );
    } else {
      if (mounted) {
        _showErrorDialog("Could not open link:\n$url");
      }
    }
  }

  void _showWelcomeDialog(double lat, double lng) async {
    // Get current location (just for display, not for checking)
    Position? currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
    } catch (e) {
      print("Location permission error: $e");
    }

    // Speak welcome
    await flutterTts.speak("Welcome! आपका स्वागत है।");

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text("Welcome!", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "You are successfully logged in.",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Text(
                  "Scanned Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}",
                ),
                if (currentPosition != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Your Location: ${currentPosition.latitude.toStringAsFixed(6)}, ${currentPosition.longitude.toStringAsFixed(6)}",
                  ),
                ],
                const SizedBox(height: 20),
                const Text("Thank you for being on time! 😊"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Reset scanner for next scan
                  Future.delayed(const Duration(milliseconds: 500), () {
                    isScanning = true;
                  });
                },
                child: const Text("OK", style: TextStyle(fontSize: 18)),
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
                  isScanning = true;
                },
                child: const Text("Retry"),
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

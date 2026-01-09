import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/service/location_service/location_service.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  // 🔒 Proftcode Office Fixed Location
  static const double proftLat = 26.87624387577325;
  static const double proftLong = 75.72635815350088;
  static const double allowedRadius = 30.0; // meters

  bool isScanned = false;
  String msg = '';

  String? currentLatLong;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.5);
  }

  // 📍 QR Scan + Location Validation
  void _onDetect(BarcodeCapture capture) async {
    if (isScanned) return;

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null) return;

    const String validQr = 'LAT:26.87624387577325,LNG:75.72635815350088';

    // 🔒 QR DATA STRICT MATCH
    if (rawValue != validQr) {
      isScanned = true;
      msg = "Invalid QR code. This QR is not for Proftcode.";
      flutterTts.speak(msg);
      setState(() {});
      _showResultPopup();
      return;
    }

    // ✅ Only Proftcode QR reaches here
    final position = await LocationService.getCurrentLocation();

    final double distance = Geolocator.distanceBetween(
      proftLat,
      proftLong,
      position.latitude,
      position.longitude,
    );

    if (distance <= allowedRadius) {
      msg = "Welcome to Proftcode Private Limited";
      flutterTts.speak(msg);
    } else {
      msg = "You are far away from Proftcode office";
      flutterTts.speak(msg);
    }

    isScanned = true;
    setState(() {});
    _showResultPopup();
  }

  void _showResultPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text("QR Scanned!"),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  isScanned = false;
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  Future<void> _getCurrentLocation() async {
    final position = await LocationService.getCurrentLocation();

    // QR data (lat,long)
    currentLatLong = "LAT:${position.latitude},LNG:${position.longitude}";
    setState(() {});
    debugPrint('currentLatLong: $currentLatLong');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: Column(
        children: [
          Expanded(child: MobileScanner(onDetect: _onDetect)),
          SizedBox(height: 20),
          Text(
            msg,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: QRScanScreen(),
    );
  }
}

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool scanned = false;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Location")),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
            backgroundColor: Colors.amber.shade300,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) {
                  return MobileScanner(
                    onDetect: (capture) async {
                      if (scanned) return;
                      scanned = true;
                      final String? raw = capture.barcodes.first.rawValue;
                      if (raw == null) {
                        scanned = false;
                        return;
                      }

                      /// CASE 1: Direct Google Maps URL
                      if (raw.startsWith("http")) {
                        await flutterTts.speak(
                          "Hello Proftcode Private Limited",
                        );
                        final uri = Uri.parse(raw);
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        return;
                      }

                      /// CASE 2: geo:lat,lng format
                      if (raw.startsWith("geo:")) {
                        await flutterTts.speak("Hello Proftcode Pvt. Ltd.");
                        final coords = raw.replaceFirst("geo:", "");
                        final mapUrl = Uri.parse(
                          "https://www.google.com/maps/search/?api=1&query=$coords",
                        );
                        await launchUrl(
                          mapUrl,
                          mode: LaunchMode.externalApplication,
                        );
                        return;
                      }

                      /// Fallback
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Invalid QR Code")),
                      );
                      scanned = false;
                    },
                  );
                },
              ),
            );
          },
          child: Text('Scan Me for your location'),
        ),
      ),
    );
  }
}

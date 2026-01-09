import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/service/location_service/location_service.dart';

class GenerateQrScreen extends StatefulWidget {
  const GenerateQrScreen({super.key});

  @override
  State<GenerateQrScreen> createState() => _GenerateQrScreenState();
}

class _GenerateQrScreenState extends State<GenerateQrScreen> {
  String? qrData;

  @override
  void initState() {
    super.initState();
    _generateQR();
  }

  Future<void> _generateQR() async {
    final position = await LocationService.getCurrentLocation();

    // QR data (lat,long)
    qrData = "LAT:${position.latitude},LNG:${position.longitude}";
    setState(() {});
    debugPrint('QR Data: $qrData');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate QR')),
      body: Center(
        child: qrData == null
            ? const CircularProgressIndicator()
            : QrImageView(
          data: qrData!,
          size: 250,
        ),
      ),
    );
  }
}

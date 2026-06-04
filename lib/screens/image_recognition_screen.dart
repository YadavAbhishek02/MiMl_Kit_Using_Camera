// lib/screens/image_recognition_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../service/ml_kit_service.dart';

enum RecognitionMode { labels, text, barcode }

class ImageRecognitionScreen extends StatefulWidget {
  const ImageRecognitionScreen({super.key});
  @override
  State<ImageRecognitionScreen> createState() => _ImageRecognitionScreenState();
}

class _ImageRecognitionScreenState extends State<ImageRecognitionScreen> {
  final _mlKit = MLKitService();
  final _picker = ImagePicker();

  String? _imagePath;
  List<ImageLabel> _labels = [];
  String _extractedText = '';
  String _barcodeResult = '';
  bool _isProcessing = false;
  RecognitionMode _mode = RecognitionMode.labels;

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final img = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
    );
    if (img == null) return;

    setState(() {
      _imagePath = img.path;
      _isProcessing = true;
      _labels = [];
      _extractedText = '';
      _barcodeResult = '';
    });

    try {
      switch (_mode) {
        case RecognitionMode.labels:
          final labels = await _mlKit.detectLabels(img.path);
          setState(() => _labels = labels);
          break;
        case RecognitionMode.text:
          final text = await _mlKit.extractText(img.path);
          setState(
              () => _extractedText = text.isEmpty ? 'No text found' : text);
          break;
        case RecognitionMode.barcode:
          final barcodes = await _mlKit.scanBarcodes(img.path);
          setState(() => _barcodeResult = barcodes.isEmpty
              ? 'No barcode found'
              : barcodes
                  .map((b) => '${b.format.name}: ${b.displayValue}')
                  .join('\n'));
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Image Recognition',
            style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Mode selector
          _buildModeSelector(),
          // Image preview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildImagePreview(),
                  const SizedBox(height: 16),
                  if (_isProcessing)
                    const CircularProgressIndicator(color: Color(0xFF4A9EFF))
                  else
                    _buildResults(),
                ],
              ),
            ),
          ),
          // Action buttons
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: RecognitionMode.values.map((mode) {
          final labels = {
            RecognitionMode.labels: ('Labels', Icons.label_outline),
            RecognitionMode.text: ('OCR', Icons.text_fields),
            RecognitionMode.barcode: ('Barcode', Icons.qr_code),
          };
          final isSelected = _mode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _mode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isSelected ? const Color(0xFF4A9EFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(labels[mode]!.$2,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.white38),
                    const SizedBox(width: 6),
                    Text(labels[mode]!.$1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white38,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imagePath == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 40, color: Colors.white24),
              SizedBox(height: 8),
              Text('Pick or capture an image',
                  style: TextStyle(color: Colors.white30, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(File(_imagePath!),
          width: double.infinity, height: 240, fit: BoxFit.cover),
    );
  }

  Widget _buildResults() {
    if (_imagePath == null) return const SizedBox.shrink();

    switch (_mode) {
      case RecognitionMode.labels:
        if (_labels.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detected objects',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            ..._labels.take(8).map((label) => _buildLabelRow(label)),
          ],
        );

      case RecognitionMode.text:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_extractedText,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.6)),
        );

      case RecognitionMode.barcode:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_barcodeResult,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        );
    }
  }

  Widget _buildLabelRow(ImageLabel label) {
    final confidence = (label.confidence * 100).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label.label,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: label.confidence,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(
                  confidence > 85
                      ? const Color(0xFF4CAF50)
                      : confidence > 65
                          ? const Color(0xFF4A9EFF)
                          : Colors.white30,
                ),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$confidence%',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      color: const Color(0xFF1A1A1A),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _pickAndAnalyze(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2A2A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _pickAndAnalyze(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A9EFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mlKit.dispose();
    super.dispose();
  }
}

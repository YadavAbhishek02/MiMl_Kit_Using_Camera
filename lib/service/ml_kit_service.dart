// lib/services/ml_kit_service.dart
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class MLKitService {
  // Image labeling — "what's in this photo?"
  final _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.6),
  );

  // Text recognition — OCR
  final _textRecognizer = TextRecognizer();

  // Barcode / QR scanner
  final _barcodeScanner = BarcodeScanner();

  // Detect objects/labels in an image
  Future<List<ImageLabel>> detectLabels(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final labels = await _labeler.processImage(inputImage);
    // Sort by confidence descending
    labels.sort((a, b) => b.confidence.compareTo(a.confidence));
    return labels;
  }

  // Extract text from image (receipts, documents, signs)
  Future<String> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _textRecognizer.processImage(inputImage);
    return recognized.text;
  }

  // Scan barcodes and QR codes
  Future<List<Barcode>> scanBarcodes(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    return await _barcodeScanner.processImage(inputImage);
  }

  void dispose() {
    _labeler.close();
    _textRecognizer.close();
    _barcodeScanner.close();
  }
}

// lib/core/parser/services/pdf_extractor_service.dart

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ExtractedPdfDocument {
  final String text;
  final String sha256Hash;
  final int pageCount;

  const ExtractedPdfDocument({
    required this.text,
    required this.sha256Hash,
    required this.pageCount,
  });
}

class PdfExtractorService {
  /// Cihazdan okunan bayt dizisinden (Uint8List) metin katmanını ve SHA256 özetini çıkarır.
  /// İşlem tamamen yereldir, hiçbir dış sunucuya gitmez.
  static ExtractedPdfDocument extractTextFromBytes(Uint8List bytes) {
    // 1. Dosya bütünlüğü ve tekillik kontrolü için SHA256 hash hesapla
    final digest = sha256.convert(bytes);
    final hashString = digest.toString();

    // 2. Syncfusion PDF motoru ile metin katmanını tara
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final String extractedText = extractor.extractText();
    final int pageCount = document.pages.count;

    // 3. Belleği serbest bırak
    document.dispose();

    return ExtractedPdfDocument(
      text: extractedText,
      sha256Hash: hashString,
      pageCount: pageCount,
    );
  }
}

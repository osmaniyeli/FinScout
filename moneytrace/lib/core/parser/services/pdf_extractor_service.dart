// lib/core/parser/services/pdf_extractor_service.dart

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import '../layout/statement_layout.dart';

class ExtractedPdfDocument {
  final StatementLayout layout;
  final String sha256Hash;

  const ExtractedPdfDocument({
    required this.layout,
    required this.sha256Hash,
  });

  /// Satır yapısı korunmuş düz metin (banka tespiti ve PII maskeleme için).
  String get text => layout.plainText;
  int get pageCount => layout.pageCount;
}

class PdfPasswordRequiredException implements Exception {
  final bool wasPasswordWrong;
  const PdfPasswordRequiredException({this.wasPasswordWrong = false});

  @override
  String toString() => wasPasswordWrong
      ? 'PDF şifresi hatalı. Lütfen tekrar deneyin.'
      : 'Bu ekstre şifre korumalı. Lütfen bankanızın belirlediği PDF şifresini girin.';
}

class PdfNoTextLayerException implements Exception {
  const PdfNoTextLayerException();

  @override
  String toString() =>
      'Bu PDF metin içermiyor (taranmış görüntü). Lütfen bankanızın internet/mobil şubesinden indirdiğiniz orijinal e-ekstreyi yükleyin.';
}

class PdfExtractorService {
  /// PDF baytlarından koordinat tabanlı satır/sütun yapısını ve SHA256 özetini çıkarır.
  /// PDFium (pdfrx) kullanır; işlem tamamen cihaz üzerindedir, hiçbir dış sunucuya gitmez.
  ///
  /// Uygulamada `pdfrxFlutterInitialize()`, testlerde `pdfrxInitialize()` önceden çağrılmış olmalıdır.
  static Future<ExtractedPdfDocument> extract(Uint8List bytes, {String? password}) async {
    final hashString = sha256.convert(bytes).toString();

    final PdfDocument document;
    try {
      document = await PdfDocument.openData(
        bytes,
        passwordProvider: password == null ? null : () => password,
        firstAttemptByEmptyPassword: password == null,
      );
    } on PdfPasswordException {
      throw PdfPasswordRequiredException(wasPasswordWrong: password != null);
    }

    final fragments = <RawTextFragment>[];
    try {
      for (final page in document.pages) {
        final pageText = await page.loadStructuredText();
        for (final fragment in pageText.fragments) {
          final text = fragment.text;
          if (text.trim().isEmpty) continue;
          final b = fragment.bounds;
          // Kenar boşluğundaki döndürülmüş yazılar (seri no, vergi dairesi vb.) tablo satırlarına karışmasın
          final isVertical = fragment.direction == PdfTextDirection.vrtl ||
              (text.trim().length >= 3 && b.height > b.width * 2.5);
          if (isVertical) continue;
          fragments.add(RawTextFragment(
            page: page.pageNumber,
            left: b.left,
            right: b.right,
            top: b.top,
            bottom: b.bottom,
            text: text,
          ));
        }
      }
    } finally {
      await document.dispose();
    }

    if (fragments.isEmpty) {
      throw const PdfNoTextLayerException();
    }

    return ExtractedPdfDocument(
      layout: StatementLayout.fromFragments(fragments, pageCount: document.pages.length),
      sha256Hash: hashString,
    );
  }
}

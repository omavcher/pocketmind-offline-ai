import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:excel/excel.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';

class FileParser {
  static Future<String> extractText(String path) async {
    final file = File(path);
    if (!await file.exists()) return '';

    final extension = path.split('.').last.toLowerCase();

    try {
      switch (extension) {
        case 'pdf':
          return await _parsePdf(file);
        case 'docx':
          return await _parseDocx(file);
        case 'xlsx':
        case 'xls':
          return await _parseExcel(file);
        case 'jpg':
        case 'jpeg':
        case 'png':
          return await _parseImage(path);
        default:
          return 'Unsupported file type: $extension';
      }
    } catch (e) {
      debugPrint('Error parsing $extension: $e');
      return 'Error extracting text from $extension file.';
    }
  }

  static Future<String> _parsePdf(File file) async {
    final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
    String text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  static Future<String> _parseDocx(File file) async {
    final bytes = await file.readAsBytes();
    return docxToText(bytes);
  }

  static Future<String> _parseExcel(File file) async {
    final bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);
    StringBuffer sb = StringBuffer();
    for (var table in excel.tables.keys) {
      sb.writeln('Sheet: $table');
      for (var row in excel.tables[table]!.rows) {
        sb.writeln(row.map((e) => e?.value?.toString() ?? '').join(' | '));
      }
    }
    return sb.toString();
  }

  static Future<String> _parseImage(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    String text = recognizedText.text;
    await textRecognizer.close();
    return text;
  }
}

import 'dart:io';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DiffSegment {
  final String text;
  final String type; // 'same', 'added', 'removed'

  const DiffSegment({required this.text, required this.type});
}

class PdfComparisonResult {
  final String file1Name;
  final String file2Name;
  final int file1Pages;
  final int file2Pages;
  final int file1Words;
  final int file2Words;
  final double similarityScore; // 0.0 to 100.0
  final int addedCount;
  final int removedCount;
  final List<DiffSegment> diffSegments;
  final String summaryText;

  const PdfComparisonResult({
    required this.file1Name,
    required this.file2Name,
    required this.file1Pages,
    required this.file2Pages,
    required this.file1Words,
    required this.file2Words,
    required this.similarityScore,
    required this.addedCount,
    required this.removedCount,
    required this.diffSegments,
    required this.summaryText,
  });
}

class PdfComparisonService {
  static final PdfComparisonService _instance =
      PdfComparisonService._internal();
  factory PdfComparisonService() => _instance;
  PdfComparisonService._internal();

  /// Compares text and structural differences between two PDF documents
  Future<PdfComparisonResult> comparePdfs({
    required String file1Path,
    required String file2Path,
  }) async {
    final doc1Bytes = await File(file1Path).readAsBytes();
    final doc2Bytes = await File(file2Path).readAsBytes();

    final doc1 = PdfDocument(inputBytes: doc1Bytes);
    final doc2 = PdfDocument(inputBytes: doc2Bytes);

    final text1 = PdfTextExtractor(doc1).extractText().trim();
    final text2 = PdfTextExtractor(doc2).extractText().trim();

    final file1Name = file1Path.split(Platform.pathSeparator).last;
    final file2Name = file2Path.split(Platform.pathSeparator).last;

    final p1 = doc1.pages.count;
    final p2 = doc2.pages.count;

    doc1.dispose();
    doc2.dispose();

    final words1 = text1.isEmpty ? <String>[] : text1.split(RegExp(r'\s+'));
    final words2 = text2.isEmpty ? <String>[] : text2.split(RegExp(r'\s+'));

    // Compute simple word-level LCS diff
    final segments = <DiffSegment>[];
    final set1 = words1.toSet();
    final set2 = words2.toSet();

    int added = 0;
    int removed = 0;
    int matched = 0;

    // Walk through words2 and compare with words1
    int i = 0;
    int j = 0;
    while (i < words1.length || j < words2.length) {
      if (i < words1.length && j < words2.length && words1[i] == words2[j]) {
        segments.add(DiffSegment(text: '${words1[i]} ', type: 'same'));
        matched++;
        i++;
        j++;
      } else if (j < words2.length && !set1.contains(words2[j])) {
        segments.add(DiffSegment(text: '${words2[j]} ', type: 'added'));
        added++;
        j++;
      } else if (i < words1.length && !set2.contains(words1[i])) {
        segments.add(DiffSegment(text: '${words1[i]} ', type: 'removed'));
        removed++;
        i++;
      } else if (j < words2.length) {
        segments.add(DiffSegment(text: '${words2[j]} ', type: 'added'));
        added++;
        j++;
      } else if (i < words1.length) {
        segments.add(DiffSegment(text: '${words1[i]} ', type: 'removed'));
        removed++;
        i++;
      }
    }

    final totalComparisonWords = max(words1.length, words2.length);
    final similarity = totalComparisonWords > 0
        ? ((matched / totalComparisonWords) * 100).clamp(0.0, 100.0)
        : 100.0;

    final summary = StringBuffer();
    summary.writeln('Comparison between "$file1Name" and "$file2Name":');
    summary.writeln('• Similarity Match: ${similarity.toStringAsFixed(1)}%');
    summary.writeln('• Original pages: $p1, Modified pages: $p2');
    summary.writeln('• Words added: $added, Words removed: $removed');
    if (added == 0 && removed == 0 && p1 == p2) {
      summary.writeln('• Identical Content: No textual differences detected.');
    } else {
      summary.writeln('• Content changes detected across documents.');
    }

    return PdfComparisonResult(
      file1Name: file1Name,
      file2Name: file2Name,
      file1Pages: p1,
      file2Pages: p2,
      file1Words: words1.length,
      file2Words: words2.length,
      similarityScore: similarity,
      addedCount: added,
      removedCount: removed,
      diffSegments: segments,
      summaryText: summary.toString(),
    );
  }
}

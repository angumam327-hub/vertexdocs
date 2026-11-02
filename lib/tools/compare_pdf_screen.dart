import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_comparison_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';

class ComparePdfScreen extends StatefulWidget {
  final File? initialFile;

  const ComparePdfScreen({super.key, this.initialFile});

  @override
  State<ComparePdfScreen> createState() => _ComparePdfScreenState();
}

class _ComparePdfScreenState extends State<ComparePdfScreen> {
  File? _file1;
  File? _file2;
  bool _isProcessing = false;
  PdfComparisonResult? _comparisonResult;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _file1 = widget.initialFile;
    }
  }

  Future<void> _pickFile(int slot) async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      setState(() {
        if (slot == 1) {
          _file1 = file;
        } else {
          _file2 = file;
        }
        _comparisonResult = null;
      });
    }
  }

  Future<void> _processCompare() async {
    if (_file1 == null || _file2 == null) return;

    setState(() => _isProcessing = true);

    try {
      final res = await PdfComparisonService().comparePdfs(
        file1Path: _file1!.path,
        file2Path: _file2!.path,
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _comparisonResult = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Comparison error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare PDF'),
        actions: [
          if (_comparisonResult != null)
            IconButton(
              icon: const Icon(Icons.share_outlined, color: AppColors.primary),
              tooltip: 'Share Report',
              onPressed: () {
                ShareService.shareFile('',
                    text: _comparisonResult!.summaryText);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Slot 1: Original Document
            _buildFileSlot(
              title: 'Original Document (A)',
              file: _file1,
              onTap: () => _pickFile(1),
            ),
            const SizedBox(height: 14),

            // Slot 2: Modified Document
            _buildFileSlot(
              title: 'Modified Document (B)',
              file: _file2,
              onTap: () => _pickFile(2),
            ),
            const SizedBox(height: 20),

            if (_comparisonResult == null)
              GradientButton(
                text: 'Compare Differences',
                icon: Icons.compare_arrows_rounded,
                isLoading: _isProcessing,
                onPressed:
                    (_file1 != null && _file2 != null) ? _processCompare : null,
              ),

            // Comparison Results View
            if (_comparisonResult != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Similarity Match',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_comparisonResult!.similarityScore.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Added / Removed Stats
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text('+${_comparisonResult!.addedCount}',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        color: AppColors.success)),
                                Text('Added Words',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.success)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text('-${_comparisonResult!.removedCount}',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        color: AppColors.error)),
                                Text('Removed Words',
                                    style: GoogleFonts.inter(
                                        fontSize: 11, color: AppColors.error)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Detailed Visual Diff View
              Text('Detailed Content Diff',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Green = added in B, Red = deleted from A',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textTertiary)),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: RichText(
                  text: TextSpan(
                    children: _comparisonResult!.diffSegments.map((seg) {
                      Color? bg;
                      Color textCol = AppColors.textPrimary;
                      if (seg.type == 'added') {
                        bg = const Color(0xFFBBF7D0);
                        textCol = const Color(0xFF166534);
                      } else if (seg.type == 'removed') {
                        bg = const Color(0xFFFECDD3);
                        textCol = const Color(0xFF9F1239);
                      }
                      return TextSpan(
                        text: seg.text,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.6,
                          backgroundColor: bg,
                          color: textCol,
                          decoration: seg.type == 'removed'
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileSlot({
    required String title,
    required File? file,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: file != null ? AppColors.primary : AppColors.cardBorder,
            width: file != null ? 1.5 : 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  file != null ? AppColors.secondary : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              color: file != null ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  file != null
                      ? file.path.split(Platform.pathSeparator).last
                      : 'No document selected',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: file != null
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (file != null)
                  Text(FileUtils.formatBytes(file.lengthSync()),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(60, 36),
            ),
            onPressed: onTap,
            child: Text(file != null ? 'Change' : 'Select'),
          ),
        ],
      ),
    );
  }
}

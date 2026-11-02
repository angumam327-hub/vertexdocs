import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_ocr_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class RepairPdfScreen extends StatefulWidget {
  final File? initialFile;

  const RepairPdfScreen({super.key, this.initialFile});

  @override
  State<RepairPdfScreen> createState() => _RepairPdfScreenState();
}

class _RepairPdfScreenState extends State<RepairPdfScreen> {
  File? _selectedFile;
  bool _isProcessing = false;
  RepairResult? _result;
  final TextEditingController _outputNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _selectFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  void _selectFile(File file) {
    setState(() {
      _selectedFile = file;
      _result = null;
      _outputNameController.text =
          'Repaired_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      _selectFile(file);
    }
  }

  Future<void> _processRepair() async {
    if (_selectedFile == null) return;

    setState(() {
      _isProcessing = true;
      _result = null;
    });

    try {
      final res = await PdfOcrService().repairPdf(
        filePath: _selectedFile!.path,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _result = res;
      });

      if (res.isSuccess && res.repairedFile != null) {
        ToolResultModal.showSuccess(
          context: context,
          title: 'PDF Repaired Successfully!',
          filePath: res.repairedFile!.path,
          subtitle: res.report,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _result = RepairResult(
          isSuccess: false,
          report: 'Failed to reconstruct PDF: $e',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repair PDF'),
      ),
      body: _selectedFile == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.build_circle_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Fix Damaged PDF Documents',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reconstruct broken cross-reference tables, fix corrupted trailer offsets, and recover readable pages.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Select PDF to Repair',
                      icon: Icons.file_upload_outlined,
                      onPressed: _pickFile,
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFile!.path
                                    .split(Platform.pathSeparator)
                                    .last,
                                style: GoogleFonts.poppins(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                FileUtils.formatBytes(
                                    _selectedFile!.lengthSync()),
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                            onPressed: _pickFile, child: const Text('Change')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Diagnostics Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.secondaryBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Repair Engine Scope',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Magic Byte Recovery (%PDF- standard header detection)\n'
                          '• EOF Trailer Reconstruction (fixes truncated files)\n'
                          '• Clean Object Stream Re-indexing & Xref Table Rebuilding',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_result != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _result!.isSuccess
                            ? AppColors.successLight
                            : AppColors.errorLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _result!.isSuccess
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _result!.isSuccess
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline_rounded,
                                color: _result!.isSuccess
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _result!.isSuccess
                                    ? 'Repair Completed'
                                    : 'Unsuccessful Repair',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: _result!.isSuccess
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _result!.report,
                            style: GoogleFonts.inter(fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  TextField(
                    controller: _outputNameController,
                    decoration: const InputDecoration(
                      labelText: 'Output File Name',
                      prefixIcon: Icon(Icons.edit_outlined,
                          color: AppColors.primary, size: 20),
                      suffixText: '.pdf',
                    ),
                  ),
                  const SizedBox(height: 28),

                  GradientButton(
                    text: 'Analyze & Repair Document',
                    icon: Icons.build_rounded,
                    isLoading: _isProcessing,
                    onPressed: _processRepair,
                  ),
                ],
              ),
            ),
    );
  }
}

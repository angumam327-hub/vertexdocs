import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pdf_file_model.dart';
import '../screens/pdf_preview_screen.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';

class SplitPdfScreen extends StatefulWidget {
  final File? initialFile;

  const SplitPdfScreen({super.key, this.initialFile});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  int _startPage = 1;
  int _endPage = 1;
  bool _isLoadingInfo = false;
  bool _isProcessing = false;
  final TextEditingController _outputNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPdf(File file) async {
    setState(() {
      _selectedFile = file;
      _isLoadingInfo = true;
    });

    final info = await PdfService().getPdfInfo(file.path);
    if (!mounted) return;

    setState(() {
      _pdfInfo = info;
      _startPage = 1;
      _endPage = info.pageCount > 0 ? info.pageCount : 1;
      _outputNameController.text =
          'Split_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
      _isLoadingInfo = false;
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processSplit() async {
    if (_selectedFile == null || _pdfInfo == null) return;

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfService().splitPdf(
        filePath: _selectedFile!.path,
        startPage: _startPage,
        endPage: _endPage,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      _showSuccessDialog(resultModel);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Error splitting PDF: $e'),
        ),
      );
    }
  }

  void _showSuccessDialog(PdfFileModel result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'PDF Split Successfully!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Extracted pages $_startPage to $_endPage (${result.formattedSize})',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Preview Extracted PDF',
              icon: Icons.visibility_outlined,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfPreviewScreen(
                      filePath: result.path,
                      title: result.name,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                    onPressed: () => ShareService.shareFile(result.path),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open External'),
                    onPressed: () => ShareService.openFile(result.path),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
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
                      child: const Icon(
                        Icons.call_split_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Extract Specific Pages',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a PDF file and choose the exact page range to extract into a separate document.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Select PDF File',
                      icon: Icons.file_upload_outlined,
                      onPressed: _pickFile,
                    ),
                  ],
                ),
              ),
            )
          : _isLoadingInfo
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Selected file card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.picture_as_pdf_rounded,
                                  color: AppColors.primary),
                            ),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_pdfInfo?.pageCount ?? 0} Pages • ${FileUtils.formatBytes(_selectedFile!.lengthSync())}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _pickFile,
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Select Page Range',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('From Page',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$_startPage',
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: AppColors.textTertiary),
                                Column(
                                  children: [
                                    Text('To Page',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$_endPage',
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if ((_pdfInfo?.pageCount ?? 1) > 1)
                              RangeSlider(
                                values: RangeValues(
                                  _startPage.toDouble(),
                                  _endPage.toDouble(),
                                ),
                                min: 1,
                                max: (_pdfInfo?.pageCount ?? 1).toDouble(),
                                divisions: (_pdfInfo?.pageCount ?? 1) - 1,
                                activeColor: AppColors.primary,
                                inactiveColor: AppColors.secondary,
                                labels: RangeLabels('$_startPage', '$_endPage'),
                                onChanged: (RangeValues values) {
                                  setState(() {
                                    _startPage = values.start.round();
                                    _endPage = values.end.round();
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

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
                        text: 'Extract Pages $_startPage - $_endPage',
                        icon: Icons.call_split_rounded,
                        isLoading: _isProcessing,
                        onPressed: _processSplit,
                      ),
                    ],
                  ),
                ),
    );
  }
}

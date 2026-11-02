import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_conversion_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class PdfToPdfaScreen extends StatefulWidget {
  final File? initialFile;

  const PdfToPdfaScreen({super.key, this.initialFile});

  @override
  State<PdfToPdfaScreen> createState() => _PdfToPdfaScreenState();
}

class _PdfToPdfaScreenState extends State<PdfToPdfaScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  String _conformance = 'PDF/A-1b';
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
    setState(() => _selectedFile = file);
    final info = await PdfService().getPdfInfo(file.path);
    if (!mounted) return;

    setState(() {
      _pdfInfo = info;
      _outputNameController.text =
          'Archival_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processConversion() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfConversionService().pdfToPdfA(
        filePath: _selectedFile!.path,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.showSuccess(
        context: context,
        title: 'Converted to $_conformance!',
        filePath: resultModel.path,
        subtitle:
            'ISO 19005 compliant archival PDF generated (${resultModel.pageCount} pages)',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Conversion error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to PDF/A'),
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
                      child: const Icon(Icons.archive_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ISO Archival Preservation',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Convert your standard PDF into a certified PDF/A compliant document for long-term legal and historical preservation.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary),
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
                                '${_pdfInfo?.pageCount ?? 0} Pages • ${FileUtils.formatBytes(_selectedFile!.lengthSync())}',
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

                  // Conformance standards card
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
                        Text('Archival Standard Selection',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children:
                              ['PDF/A-1b', 'PDF/A-2b', 'PDF/A-3b'].map((std) {
                            final isSel = _conformance == std;
                            return ChoiceChip(
                              label: Text(std),
                              selected: isSel,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                  color:
                                      isSel ? Colors.white : AppColors.primary),
                              onSelected: (val) {
                                if (val) setState(() => _conformance = std);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ISO 19005-1 (PDF/A-1b) embeds device-independent color spaces, removes external font dependencies, and guarantees readability across decades.',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.4),
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
                    text: 'Convert to $_conformance',
                    icon: Icons.archive_rounded,
                    isLoading: _isProcessing,
                    onPressed: _processConversion,
                  ),
                ],
              ),
            ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_ocr_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

class OcrPdfScreen extends StatefulWidget {
  final File? initialFile;

  const OcrPdfScreen({super.key, this.initialFile});

  @override
  State<OcrPdfScreen> createState() => _OcrPdfScreenState();
}

class _OcrPdfScreenState extends State<OcrPdfScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  String _recognizedText = '';
  bool _isProcessing = false;
  String _language = 'en'; // 'en' or 'ta'
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPdf(File file) async {
    setState(() {
      _selectedFile = file;
      _recognizedText = '';
    });
    final info = await PdfService().getPdfInfo(file.path);
    if (!mounted) return;
    setState(() => _pdfInfo = info);
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processOcr() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final text = await PdfOcrService().recognizeText(
        filePath: _selectedFile!.path,
        language: _language,
      );

      if (!mounted) return;
      setState(() {
        _recognizedText = text;
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('OCR recognition completed!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.error, content: Text('OCR error: $e')),
      );
    }
  }

  void _copyText() {
    if (_recognizedText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _recognizedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Copied to clipboard!')),
    );
  }

  Future<void> _saveAsTxt() async {
    if (_recognizedText.isEmpty || _selectedFile == null) return;
    final base = _selectedFile!.path
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.pdf', '');
    final file =
        await FileService().saveTextFile(_recognizedText, 'OCR_$base.txt');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content:
            Text('Saved as ${file.path.split(Platform.pathSeparator).last}'),
        action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () => ShareService.shareFile(file.path)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _recognizedText.isEmpty
        ? 0
        : _recognizedText.split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR PDF'),
        actions: [
          if (_recognizedText.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
              tooltip: 'Copy',
              onPressed: _copyText,
            ),
            IconButton(
              icon: const Icon(Icons.save_alt_rounded),
              tooltip: 'Save Text',
              onPressed: _saveAsTxt,
            ),
          ],
        ],
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
                      child: const Icon(Icons.document_scanner_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Optical Character Recognition',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Extract selectable, searchable text from scanned PDF documents with support for English and தமிழ்.',
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
          : Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 12),
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
                              '${_pdfInfo?.pageCount ?? 0} Pages • $wordCount Words recognized',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                          onPressed: _pickFile, child: const Text('Change')),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Language Selector
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('Recognition Language: ',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('English'),
                        selected: _language == 'en',
                        selectedColor: AppColors.secondary,
                        onSelected: (val) {
                          if (val) setState(() => _language = 'en');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('தமிழ் (Tamil)'),
                        selected: _language == 'ta',
                        selectedColor: AppColors.secondary,
                        onSelected: (val) {
                          if (val) setState(() => _language = 'ta');
                        },
                      ),
                    ],
                  ),
                ),

                if (_recognizedText.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GradientButton(
                      text: 'Run OCR on ${_pdfInfo?.pageCount ?? 0} Pages',
                      icon: Icons.document_scanner_rounded,
                      isLoading: _isProcessing,
                      onPressed: _processOcr,
                    ),
                  ),

                if (_recognizedText.isNotEmpty) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(
                          () => _searchFilter = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search inside OCR text...',
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchFilter = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _searchFilter.isEmpty
                              ? _recognizedText
                              : _recognizedText
                                  .split('\n')
                                  .where((l) =>
                                      l.toLowerCase().contains(_searchFilter))
                                  .join('\n'),
                          style: GoogleFonts.sourceCodePro(
                              fontSize: 13, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

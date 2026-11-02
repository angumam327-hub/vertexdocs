import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/ai_assistant_screen.dart';
import '../services/ai_assistant_service.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

class OcrScreen extends StatefulWidget {
  final File? initialFile;

  const OcrScreen({super.key, this.initialFile});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  String _extractedText = '';
  bool _isExtracting = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
      _extractedText = '';
    });

    final info = await PdfService().getPdfInfo(file.path);
    if (!mounted) return;
    setState(() => _pdfInfo = info);

    await _processExtract(file);
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processExtract(File file) async {
    setState(() => _isExtracting = true);

    try {
      final text = await PdfService().extractText(filePath: file.path);
      if (!mounted) return;
      setState(() {
        _extractedText = text.trim();
        _isExtracting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Error extracting text: $e'),
        ),
      );
    }
  }

  void _copyToClipboard() {
    if (_extractedText.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _extractedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('Text copied to clipboard!'),
      ),
    );
  }

  Future<void> _saveAsTxtFile() async {
    if (_extractedText.isEmpty || _selectedFile == null) return;
    final base = _selectedFile!.path
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.pdf', '');
    final name = 'Extracted_$base.txt';
    final savedFile = await FileService().saveTextFile(_extractedText, name);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text(
            'Saved to ${savedFile.path.split(Platform.pathSeparator).last}'),
        action: SnackBarAction(
          label: 'Share',
          textColor: Colors.white,
          onPressed: () => ShareService.shareFile(savedFile.path),
        ),
      ),
    );
  }

  void _sendToAiAssistant() async {
    if (_selectedFile == null) return;
    await AiAssistantService().loadPdf(_selectedFile!.path);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiAssistantScreen(initialPdfPath: _selectedFile!.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _extractedText.isEmpty
        ? 0
        : _extractedText
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR & Extract Text'),
        actions: [
          if (_extractedText.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
              tooltip: 'Copy Text',
              onPressed: _copyToClipboard,
            ),
            IconButton(
              icon: const Icon(Icons.save_alt_rounded,
                  color: AppColors.textPrimary),
              tooltip: 'Save as .txt',
              onPressed: _saveAsTxtFile,
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
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Extract Text from PDF',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Extract all text content from PDF pages with high precision. Copy, save, or send directly to VertexDocs AI.',
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
          : Column(
              children: [
                // Top doc header
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded,
                            color: AppColors.primary, size: 22),
                      ),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_pdfInfo?.pageCount ?? 0} Pages • $wordCount Words • ${_extractedText.length} Chars',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                          onPressed: _pickFile, child: const Text('Change')),
                    ],
                  ),
                ),

                // Search inside extracted text
                if (_extractedText.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(
                          () => _searchQuery = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search within extracted text...',
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),

                Expanded(
                  child: _isExtracting
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: AppColors.primary),
                              SizedBox(height: 16),
                              Text('Extracting text from PDF...'),
                            ],
                          ),
                        )
                      : _extractedText.isEmpty
                          ? Center(
                              child: Text(
                                'No selectable text found in this PDF.\n(It may consist of scanned photos or flat artwork)',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                            )
                          : Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  _searchQuery.isEmpty
                                      ? _extractedText
                                      : _extractedText
                                          .split('\n')
                                          .where((line) => line
                                              .toLowerCase()
                                              .contains(_searchQuery))
                                          .join('\n'),
                                  style: GoogleFonts.sourceCodePro(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                ),

                // Bottom actions
                if (_extractedText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(top: BorderSide(color: AppColors.cardBorder)),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('Copy All'),
                              onPressed: _copyToClipboard,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GradientButton(
                              text: 'Ask AI Assistant',
                              icon: Icons.auto_awesome_rounded,
                              height: 48,
                              onPressed: _sendToAiAssistant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

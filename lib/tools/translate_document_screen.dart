import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/share_service.dart';
import '../services/translation_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class TranslateDocumentScreen extends StatefulWidget {
  final File? initialFile;

  const TranslateDocumentScreen({super.key, this.initialFile});

  @override
  State<TranslateDocumentScreen> createState() =>
      _TranslateDocumentScreenState();
}

class _TranslateDocumentScreenState extends State<TranslateDocumentScreen> {
  final TranslationService _translationService = TranslationService();

  File? _selectedFile;
  SupportedLanguage _sourceLang =
      TranslationService.supportedLanguages[0]; // Auto Detect
  SupportedLanguage _targetLang =
      TranslationService.supportedLanguages[2]; // Tamil

  bool _isTranslating = false;
  double _progress = 0.0;
  String _statusMessage = '';

  TranslationResult? _result;
  int _selectedPreviewTab = 1; // 0 = Original, 1 = Translated

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _selectedFile = widget.initialFile;
    }
  }

  Future<void> _pickDocument() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );
    if (res != null && res.files.single.path != null) {
      setState(() {
        _selectedFile = File(res.files.single.path!);
        _result = null;
        _progress = 0;
        _statusMessage = '';
      });
    }
  }

  void _swapLanguages() {
    if (_sourceLang.code == 'auto') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.warning,
          content: Text(
              'Cannot swap when source is set to "Auto Detect". Choose a specific source language first.'),
        ),
      );
      return;
    }
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
    });
  }

  void _showLanguagePicker({required bool isSource}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final list = TranslationService.supportedLanguages.where((l) {
              if (!isSource && l.code == 'auto') return false;
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return l.name.toLowerCase().contains(q) ||
                  l.nativeName.toLowerCase().contains(q) ||
                  l.code.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isSource
                        ? 'Select Source Language'
                        : 'Select Target Language',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (val) {
                      setModalState(() => query = val.trim());
                    },
                    decoration: InputDecoration(
                      hintText: 'Search language (e.g. Tamil, French)...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.primary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final lang = list[index];
                        final isSelected = isSource
                            ? _sourceLang.code == lang.code
                            : _targetLang.code == lang.code;

                        return ListTile(
                          title: Text(
                            lang.name,
                            style: GoogleFonts.inter(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            lang.nativeName,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary)
                              : null,
                          onTap: () {
                            setState(() {
                              if (isSource) {
                                _sourceLang = lang;
                              } else {
                                _targetLang = lang;
                              }
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleTranslate() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Please select a PDF, DOCX, or TXT document first.'),
        ),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
      _progress = 0.05;
      _statusMessage = 'Reading document content...';
      _result = null;
    });

    try {
      final res = await _translationService.translateDocument(
        filePath: _selectedFile!.path,
        sourceCode: _sourceLang.code,
        targetCode: _targetLang.code,
        onProgress: (p, msg) {
          if (mounted) {
            setState(() {
              _progress = p;
              _statusMessage = msg;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _isTranslating = false;
        _result = res;
        _selectedPreviewTab = 1; // Show translated by default
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
              'Document successfully translated into ${_targetLang.name}!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTranslating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Translation error: $e'),
        ),
      );
    }
  }

  Future<void> _exportAsPdf() async {
    if (_result == null) return;
    try {
      final pdf = await _translationService.exportTranslatedPdf(
        translatedText: _result!.translatedText,
        originalFileName: _result!.sourceFileName,
        targetLanguage: _targetLang.name,
      );

      if (!mounted) return;
      ToolResultModal.show(
        context: context,
        result: pdf,
        toolTitle: 'Document Translation',
        onDismiss: () {},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Export error: $e')),
      );
    }
  }

  Future<void> _saveAsTxt() async {
    if (_result == null) return;
    try {
      final file = await _translationService.saveAsTxt(
        translatedText: _result!.translatedText,
        originalFileName: _result!.sourceFileName,
        targetLanguage: _targetLang.name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
              'Saved translated text to ${file.path.split(Platform.pathSeparator).last}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.error, content: Text('Save error: $e')),
      );
    }
  }

  void _copyToClipboard() {
    if (_result == null) return;
    final text = _selectedPreviewTab == 1
        ? _result!.translatedText
        : _result!.originalText;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.success,
        content: Text('Copied text to clipboard!'),
      ),
    );
  }

  void _shareContent() {
    if (_result == null) return;
    ShareService.shareFile('', text: _result!.translatedText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Translate Documents',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_result != null) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
              tooltip: 'Copy',
              onPressed: _copyToClipboard,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: AppColors.primary),
              tooltip: 'Share',
              onPressed: _shareContent,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tool Header Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.translate_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multi-Language Document Translation',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Convert PDF, DOCX, and TXT files seamlessly across 40+ languages.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Select Document Section
            if (_selectedFile == null) ...[
              GestureDetector(
                onTap: _pickDocument,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.file_upload_outlined,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Select Document to Translate',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports PDF, DOCX, and TXT files',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Selected File Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
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
                      child: Icon(
                        _getFileIcon(_selectedFile!.path),
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FileUtils.getFileName(_selectedFile!.path),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            FileUtils.formatFileSize(
                                _selectedFile!.lengthSync()),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDocument,
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),

            // Language Selection Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Translation Languages',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Source Language Selector
                      Expanded(
                        child: InkWell(
                          onTap: () => _showLanguagePicker(isSource: true),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'From',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _sourceLang.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down_rounded,
                                        color: AppColors.primary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Swap Button
                      IconButton.filled(
                        onPressed: _swapLanguages,
                        icon: const Icon(Icons.swap_horiz_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        tooltip: 'Swap Languages',
                      ),
                      const SizedBox(width: 8),

                      // Target Language Selector
                      Expanded(
                        child: InkWell(
                          onTap: () => _showLanguagePicker(isSource: false),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'To',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _targetLang.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down_rounded,
                                        color: AppColors.primary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Translate Action Button
            GradientButton(
              text: 'Translate to ${_targetLang.name}',
              icon: Icons.g_translate_rounded,
              isLoading: _isTranslating,
              onPressed: _selectedFile != null && !_isTranslating
                  ? _handleTranslate
                  : null,
            ),

            // Live Progress Bar
            if (_isTranslating) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _statusMessage,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: AppColors.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Translation Result Preview & Export Options
            if (_result != null) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dual Preview Tab bar
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                            value: 1,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 16),
                            label: Text('Translated (${_targetLang.name})'),
                          ),
                          const ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.source_outlined, size: 16),
                            label: Text('Original Text'),
                          ),
                        ],
                        selected: {_selectedPreviewTab},
                        onSelectionChanged: (set) =>
                            setState(() => _selectedPreviewTab = set.first),
                        style: const ButtonStyle(
                            visualDensity: VisualDensity.compact),
                      ),
                    ),
                    const Divider(height: 1),

                    // Preview Text Box
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _selectedPreviewTab == 1
                              ? _result!.translatedText
                              : _result!.originalText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            height: 1.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),

                    // Action Buttons (Export PDF, Save TXT, Copy, Share)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saveAsTxt,
                            icon: const Icon(Icons.save_as_outlined,
                                size: 16, color: AppColors.textPrimary),
                            label: const Text('Save TXT'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy_rounded,
                                size: 16, color: AppColors.textPrimary),
                            label: const Text('Copy'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _exportAsPdf,
                            icon: const Icon(Icons.picture_as_pdf_rounded,
                                size: 16),
                            label: const Text('Export as PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.docx')) return Icons.description_rounded;
    return Icons.text_snippet_rounded;
  }
}

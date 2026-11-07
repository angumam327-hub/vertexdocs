import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/compression_service.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';

class CompressPdfScreen extends StatefulWidget {
  final File? initialFile;

  const CompressPdfScreen({super.key, this.initialFile});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  final FileService _fileService = FileService();
  final CompressionService _compressionService = CompressionService();

  File? _selectedFile;
  PdfInfo? _pdfInfo;
  int _originalSizeBytes = 0;
  bool _isProcessing = false;
  String _processingStatus = 'Compressing file...';

  // Format selection: 'PDF' or 'JPG'
  String _selectedFormat = 'PDF';

  // Target size in KB: default 200 KB (from reference)
  int _targetSizeKb = 200;
  bool _isCustomSize = false;
  final TextEditingController _customSizeController =
      TextEditingController(text: '150');

  // Black & white toggle
  bool _isBlackAndWhite = false;

  // Predefined sizes from reference image
  static const List<int> _presetSizes = [
    50, // 50 KB
    100, // 100 KB
    200, // 200 KB
    500, // 500 KB
    1024, // 1 MB
    2048, // 2 MB
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadPdf(File file) async {
    final size = await file.length();
    final info = await PdfService().getPdfInfo(file.path);
    if (!mounted) return;
    setState(() {
      _selectedFile = file;
      _originalSizeBytes = size;
      _pdfInfo = info;
    });
  }

  Future<void> _pickFile() async {
    final file = await _fileService.pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  void _showCustomSizeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Custom Size Limit',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter target file size limit in Kilobytes (KB):',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customSizeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                suffixText: 'KB',
                hintText: 'e.g. 150',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final val = int.tryParse(_customSizeController.text.trim());
              if (val != null && val > 10) {
                setState(() {
                  _targetSizeKb = val;
                  _isCustomSize = true;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Apply Size'),
          ),
        ],
      ),
    );
  }

  Future<void> _processMakeFile() async {
    if (_selectedFile == null) {
      _pickFile();
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Optimizing and resizing document...';
    });

    try {
      if (_selectedFormat == 'JPG') {
        // Render first page or full document as JPG
        final res = await _compressionService.compressToTargetSize(
          filePath: _selectedFile!.path,
          targetSizeKb: _targetSizeKb,
          onProgress: (p, s) {
            if (mounted) setState(() => _processingStatus = s);
          },
        );

        if (!mounted) return;
        setState(() => _isProcessing = false);

        _showSuccessSheet(
          outputPath: res.compressedPath,
          outputName: res.outputName,
          originalSize: res.originalSize,
          compressedSize: res.compressedSize,
          isImage: true,
        );
      } else {
        // PDF format compression
        final res = await _compressionService.compressToTargetSize(
          filePath: _selectedFile!.path,
          targetSizeKb: _targetSizeKb,
          onProgress: (p, s) {
            if (mounted) setState(() => _processingStatus = s);
          },
        );

        if (!mounted) return;
        setState(() => _isProcessing = false);

        _showSuccessSheet(
          outputPath: res.compressedPath,
          outputName: res.outputName,
          originalSize: res.originalSize,
          compressedSize: res.compressedSize,
          isImage: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Compression failed: $e'),
        ),
      );
    }
  }

  void _showSuccessSheet({
    required String outputPath,
    required String outputName,
    required int originalSize,
    required int compressedSize,
    required bool isImage,
  }) {
    final savedBytes = originalSize - compressedSize;
    final savedPercent = originalSize > 0 && savedBytes > 0
        ? ((savedBytes / originalSize) * 100).toStringAsFixed(1)
        : '0';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Successfully Created!',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        outputName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Size comparison card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Original Size',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        FileUtils.formatBytes(originalSize),
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: AppColors.textTertiary),
                  Column(
                    children: [
                      Text('Compressed Size',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.primary)),
                      const SizedBox(height: 4),
                      Text(
                        FileUtils.formatBytes(compressedSize),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-$savedPercent%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions: Open & Share
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ShareService.openFile(outputPath);
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Open'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ShareService.shareFile(outputPath);
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSizeLabel(int kb) {
    if (kb >= 1024) {
      final mb = (kb / 1024).toStringAsFixed(kb % 1024 == 0 ? 0 : 1);
      return '$mb MB';
    }
    return '$kb KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFF1E2022),
                ),
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: InkWell(
                onTap: () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF1E2022),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isProcessing
            ? _buildProcessingView()
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Make it smaller
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.open_in_full_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Make it smaller',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'For websites that limit file size',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Selected file card
                    _buildSelectedFileCard(),
                    const SizedBox(height: 24),

                    // Format Section: [ JPG ] [ PDF ]
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Format',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Use what the website asks for',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildFormatSelector(),
                    const SizedBox(height: 6),
                    Text(
                      _selectedFormat == 'JPG'
                          ? 'A picture. Most photo and ID uploads ask for this.'
                          : 'PDF document. Keeps pages and document layout intact.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Size Limit Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Size limit',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'The biggest file it accepts',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSizeLimitGrid(),
                    const SizedBox(height: 24),

                    // Black & White Toggle Card
                    _buildBlackAndWhiteCard(),
                    const SizedBox(height: 32),

                    // Make File Button
                    GradientButton(
                      text: 'Make file',
                      icon: Icons.open_in_full_rounded,
                      onPressed: _processMakeFile,
                    ),
                    const SizedBox(height: 12),

                    // Privacy badge footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Made on this device. Nothing is uploaded.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  // Selected File Card
  Widget _buildSelectedFileCard() {
    if (_selectedFile == null) {
      return InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.file_upload_outlined,
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
                      'Choose PDF or Image to Compress',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Tap to select a document from your storage',
                      style: GoogleFonts.inter(
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
      );
    }

    final filename =
        _selectedFile!.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '');
    final pageStr = _pdfInfo?.pageCount != null
        ? '${_pdfInfo!.pageCount} ${_pdfInfo!.pageCount == 1 ? 'page' : 'pages'}'
        : '1 page';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          // Document Thumbnail Badge
          Container(
            width: 44,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // File name & Meta Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Original Size capsule
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Original ${FileUtils.formatBytes(_originalSizeBytes)}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Page Count capsule
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Text(
                        pageStr,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Change button
          TextButton(
            onPressed: _pickFile,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Change',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Format Selector: [ JPG ] [ PDF ]
  Widget _buildFormatSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF3),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildFormatPill(
              format: 'JPG',
              icon: Icons.image_outlined,
            ),
          ),
          Expanded(
            child: _buildFormatPill(
              format: 'PDF',
              icon: Icons.picture_as_pdf_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatPill({required String format, required IconData icon}) {
    final isSelected = _selectedFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              format,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Size limit pills: 50 KB, 100 KB, 200 KB, 500 KB, 1 MB, 2 MB, Other size
  Widget _buildSizeLimitGrid() {
    return Column(
      children: [
        // Row 1: 50 KB, 100 KB, 200 KB, 500 KB
        Row(
          children: [
            for (final kb in _presetSizes.take(4)) ...[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSizePill(kb),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: 1 MB, 2 MB, Other size
        Row(
          children: [
            for (final kb in _presetSizes.skip(4)) ...[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSizePill(kb),
                ),
              ),
            ],
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildOtherSizePill(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSizePill(int kb) {
    final isSelected = !_isCustomSize && _targetSizeKb == kb;
    return InkWell(
      onTap: () {
        setState(() {
          _targetSizeKb = kb;
          _isCustomSize = false;
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            _formatSizeLabel(kb),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtherSizePill() {
    final isSelected = _isCustomSize;
    return InkWell(
      onTap: _showCustomSizeDialog,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_outlined,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              isSelected ? '$_targetSizeKb KB' : 'Other size',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Black & white toggle card
  Widget _buildBlackAndWhiteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.filter_b_and_w_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Black & white',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Smaller file. Text stays clear.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isBlackAndWhite,
            activeTrackColor: AppColors.secondary,
            thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return Colors.white;
            }),
            onChanged: (val) {
              setState(() => _isBlackAndWhite = val);
            },
          ),
        ],
      ),
    );
  }

  // Processing loader
  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            _processingStatus,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Targeting ${_formatSizeLabel(_targetSizeKb)} limit...',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

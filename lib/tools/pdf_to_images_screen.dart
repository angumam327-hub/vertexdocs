import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';

class PdfToImagesScreen extends StatefulWidget {
  final File? initialFile;

  const PdfToImagesScreen({super.key, this.initialFile});

  @override
  State<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends State<PdfToImagesScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isConverting = false;
  List<String> _convertedImagePaths = [];
  String _selectedFormat = 'PNG'; // 'PNG' or 'JPG'

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  Future<void> _loadPdf(File file) async {
    setState(() {
      _selectedFile = file;
      _convertedImagePaths = [];
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

  Future<void> _processConvert() async {
    if (_selectedFile == null) return;

    setState(() => _isConverting = true);

    try {
      final format = _selectedFormat == 'PNG'
          ? pdfx.PdfPageImageFormat.png
          : pdfx.PdfPageImageFormat.jpeg;

      final imagePaths = await PdfService().pdfToImages(
        filePath: _selectedFile!.path,
        format: format,
        scale: 2.0,
      );

      if (!mounted) return;
      setState(() {
        _convertedImagePaths = imagePaths;
        _isConverting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content:
              Text('Successfully extracted ${imagePaths.length} page images!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConverting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Error extracting images: $e'),
        ),
      );
    }
  }

  void _showImagePreview(String imagePath, int pageIndex) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                      height: 400,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Page $pageIndex',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_outlined,
                                  color: AppColors.primary),
                              onPressed: () =>
                                  ShareService.shareFile(imagePath),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded),
                              onPressed: () => ShareService.openFile(imagePath),
                            ),
                          ],
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Images'),
        actions: [
          if (_convertedImagePaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined, color: AppColors.primary),
              tooltip: 'Share All Images',
              onPressed: () =>
                  ShareService.shareMultipleFiles(_convertedImagePaths),
            ),
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
                        Icons.photo_library_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Convert PDF to Pictures',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Turn all pages of your PDF document into high-resolution PNG or JPG image files.',
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
                            onPressed: _pickFile, child: const Text('Change')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Format selection
                  Row(
                    children: [
                      Text(
                        'Image Format: ',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('PNG (Lossless)'),
                        selected: _selectedFormat == 'PNG',
                        selectedColor: AppColors.secondary,
                        onSelected: (val) {
                          if (val) setState(() => _selectedFormat = 'PNG');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('JPG (Compact)'),
                        selected: _selectedFormat == 'JPG',
                        selectedColor: AppColors.secondary,
                        onSelected: (val) {
                          if (val) setState(() => _selectedFormat = 'JPG');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_convertedImagePaths.isEmpty)
                    GradientButton(
                      text:
                          'Convert ${_pdfInfo?.pageCount ?? 0} Pages to Images',
                      icon: Icons.photo_library_rounded,
                      isLoading: _isConverting,
                      onPressed: _processConvert,
                    ),

                  if (_convertedImagePaths.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Extracted Images (${_convertedImagePaths.length})',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.share_outlined, size: 16),
                          label: const Text('Share All'),
                          onPressed: () => ShareService.shareMultipleFiles(
                              _convertedImagePaths),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _convertedImagePaths.length,
                      itemBuilder: (ctx, index) {
                        final path = _convertedImagePaths[index];
                        return InkWell(
                          onTap: () => _showImagePreview(path, index + 1),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14)),
                                    child: Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Page ${index + 1}',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.share_outlined,
                                            size: 16, color: AppColors.primary),
                                        onPressed: () =>
                                            ShareService.shareFile(path),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

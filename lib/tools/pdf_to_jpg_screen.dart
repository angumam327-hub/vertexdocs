import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_conversion_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';

class PdfToJpgScreen extends StatefulWidget {
  final File? initialFile;

  const PdfToJpgScreen({super.key, this.initialFile});

  @override
  State<PdfToJpgScreen> createState() => _PdfToJpgScreenState();
}

class _PdfToJpgScreenState extends State<PdfToJpgScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  double _quality = 85;
  bool _isProcessing = false;
  List<String> _jpgPaths = [];

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
      _jpgPaths = [];
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

    setState(() => _isProcessing = true);

    try {
      final paths = await PdfConversionService().pdfToJpg(
        filePath: _selectedFile!.path,
        quality: _quality.toInt(),
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _jpgPaths = paths;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Generated ${paths.length} JPG images!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.error, content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to JPG'),
        actions: [
          if (_jpgPaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined, color: AppColors.primary),
              tooltip: 'Share All JPGs',
              onPressed: () => ShareService.shareMultipleFiles(_jpgPaths),
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
                      child: const Icon(Icons.image_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Extract Pages as JPG Pictures',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Convert each PDF page into high-clarity JPEG pictures with custom compression settings.',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('JPG Quality: ${_quality.toInt()}%',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(_quality > 85 ? 'High Clarity' : 'Compressed Size',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                  Slider(
                    value: _quality,
                    min: 50,
                    max: 100,
                    divisions: 10,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.secondary,
                    onChanged: (val) => setState(() => _quality = val),
                  ),
                  const SizedBox(height: 20),
                  if (_jpgPaths.isEmpty)
                    GradientButton(
                      text: 'Convert ${_pdfInfo?.pageCount ?? 0} Pages to JPG',
                      icon: Icons.image_rounded,
                      isLoading: _isProcessing,
                      onPressed: _processConvert,
                    ),
                  if (_jpgPaths.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Generated Images (${_jpgPaths.length})',
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        TextButton.icon(
                          icon: const Icon(Icons.share_outlined, size: 16),
                          label: const Text('Share All'),
                          onPressed: () =>
                              ShareService.shareMultipleFiles(_jpgPaths),
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
                      itemCount: _jpgPaths.length,
                      itemBuilder: (ctx, index) {
                        final path = _jpgPaths[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(14)),
                                  child:
                                      Image.file(File(path), fit: BoxFit.cover),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Page ${index + 1}.jpg',
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
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

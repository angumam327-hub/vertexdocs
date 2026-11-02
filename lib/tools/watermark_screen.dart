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

class WatermarkScreen extends StatefulWidget {
  final File? initialFile;

  const WatermarkScreen({super.key, this.initialFile});

  @override
  State<WatermarkScreen> createState() => _WatermarkScreenState();
}

class _WatermarkScreenState extends State<WatermarkScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  final TextEditingController _watermarkController = TextEditingController(
    text: 'CONFIDENTIAL',
  );
  final TextEditingController _outputNameController = TextEditingController();
  double _opacity = 0.35;
  double _fontSize = 42;
  bool _isDiagonal = true;
  Color _selectedColor = AppColors.primary;
  bool _isProcessing = false;

  final List<Color> _availableColors = const [
    AppColors.primary,
    Color(0xFFE11D48),
    Color(0xFF2563EB),
    Color(0xFF4B5563),
    Color(0xFF1E293B),
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
    _watermarkController.dispose();
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
          'Watermarked_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processWatermark() async {
    if (_selectedFile == null) return;
    final text = _watermarkController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter watermark text.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfService().addWatermark(
        filePath: _selectedFile!.path,
        watermarkText: text,
        opacity: _opacity,
        fontSize: _fontSize,
        color: _selectedColor,
        isDiagonal: _isDiagonal,
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
          content: Text('Error adding watermark: $e'),
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
              'Watermark Added Successfully!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${result.name} (${result.formattedSize})',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Preview Watermarked PDF',
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
        title: const Text('Add Watermark'),
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
                        Icons.branding_watermark_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Protect with Watermark',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stamp custom text like "CONFIDENTIAL", your brand name, or draft notices onto every page.',
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

                  // Live Preview Box
                  Center(
                    child: Container(
                      width: 180,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.cardBorder, width: 2),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(
                                6,
                                (i) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  height: 8,
                                  width: (i % 2 == 0) ? 140 : 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: _isDiagonal ? -0.785 : 0, // -45 deg or 0
                            child: Opacity(
                              opacity: _opacity,
                              child: Text(
                                _watermarkController.text.isEmpty
                                    ? 'SAMPLE'
                                    : _watermarkController.text,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: _fontSize * 0.45,
                                  fontWeight: FontWeight.w800,
                                  color: _selectedColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Watermark text input
                  TextField(
                    controller: _watermarkController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Watermark Text',
                      prefixIcon: Icon(Icons.text_fields_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Diagonal vs Horizontal
                  Row(
                    children: [
                      Text('Orientation: ',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Diagonal'),
                        selected: _isDiagonal,
                        selectedColor: AppColors.secondary,
                        onSelected: (val) {
                          if (val) setState(() => _isDiagonal = true);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Horizontal'),
                        selected: !_isDiagonal,
                        selectedColor: AppColors.secondary,
                        onSelected: (val) {
                          if (val) setState(() => _isDiagonal = false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Color Picker
                  Row(
                    children: [
                      Text('Color: ',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      ..._availableColors.map((color) {
                        final isSel = _selectedColor == color;
                        return InkWell(
                          onTap: () => setState(() => _selectedColor = color),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel
                                    ? AppColors.textPrimary
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Opacity Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Opacity',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('${(_opacity * 100).toInt()}%',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                  Slider(
                    value: _opacity,
                    min: 0.1,
                    max: 0.9,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.secondary,
                    onChanged: (val) => setState(() => _opacity = val),
                  ),

                  // Font Size Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Font Size',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('${_fontSize.toInt()} pt',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                  Slider(
                    value: _fontSize,
                    min: 20,
                    max: 80,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.secondary,
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                  const SizedBox(height: 12),

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
                    text: 'Apply Watermark',
                    icon: Icons.branding_watermark_rounded,
                    isLoading: _isProcessing,
                    onPressed: _processWatermark,
                  ),
                ],
              ),
            ),
    );
  }
}

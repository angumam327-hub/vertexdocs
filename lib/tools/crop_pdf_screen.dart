import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_organize_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class CropPdfScreen extends StatefulWidget {
  final File? initialFile;

  const CropPdfScreen({super.key, this.initialFile});

  @override
  State<CropPdfScreen> createState() => _CropPdfScreenState();
}

class _CropPdfScreenState extends State<CropPdfScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  double _cropTop = 20.0;
  double _cropBottom = 20.0;
  double _cropLeft = 20.0;
  double _cropRight = 20.0;
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
          'Cropped_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processCrop() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfOrganizeService().cropPdf(
        filePath: _selectedFile!.path,
        cropTop: _cropTop,
        cropBottom: _cropBottom,
        cropLeft: _cropLeft,
        cropRight: _cropRight,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.showSuccess(
        context: context,
        title: 'PDF Cropped Successfully!',
        filePath: resultModel.path,
        subtitle: '${resultModel.name} (${resultModel.pageCount} pages)',
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
        title: const Text('Crop PDF'),
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
                      child: const Icon(Icons.crop_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Crop Document Margins',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Trim unwanted white borders or adjust the visible dimensions across all pages.',
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

                  // Visual crop frame preview
                  Center(
                    child: Container(
                      width: 160,
                      height: 210,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: _cropTop * 0.4,
                            bottom: _cropBottom * 0.4,
                            left: _cropLeft * 0.4,
                            right: _cropRight * 0.4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                    color: AppColors.primary, width: 2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Center(
                                child: Text('Visible Page',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Presets
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ActionChip(
                        label: const Text('Minimal (10pt)'),
                        onPressed: () => setState(() {
                          _cropTop = 10;
                          _cropBottom = 10;
                          _cropLeft = 10;
                          _cropRight = 10;
                        }),
                      ),
                      ActionChip(
                        label: const Text('Regular (25pt)'),
                        onPressed: () => setState(() {
                          _cropTop = 25;
                          _cropBottom = 25;
                          _cropLeft = 25;
                          _cropRight = 25;
                        }),
                      ),
                      ActionChip(
                        label: const Text('Large (40pt)'),
                        onPressed: () => setState(() {
                          _cropTop = 40;
                          _cropBottom = 40;
                          _cropLeft = 40;
                          _cropRight = 40;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildSlider('Top Margin', _cropTop,
                      (v) => setState(() => _cropTop = v)),
                  _buildSlider('Bottom Margin', _cropBottom,
                      (v) => setState(() => _cropBottom = v)),
                  _buildSlider('Left Margin', _cropLeft,
                      (v) => setState(() => _cropLeft = v)),
                  _buildSlider('Right Margin', _cropRight,
                      (v) => setState(() => _cropRight = v)),

                  const SizedBox(height: 16),
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
                    text: 'Crop & Save PDF',
                    icon: Icons.crop_rounded,
                    isLoading: _isProcessing,
                    onPressed: _processCrop,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSlider(
      String label, double val, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            Text('${val.toInt()} pt',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        Slider(
          value: val,
          min: 0,
          max: 100,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.secondary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

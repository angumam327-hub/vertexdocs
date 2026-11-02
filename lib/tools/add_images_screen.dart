import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_service.dart';
import '../services/pdf_edit_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class AddImagesScreen extends StatefulWidget {
  final File? initialFile;

  const AddImagesScreen({super.key, this.initialFile});

  @override
  State<AddImagesScreen> createState() => _AddImagesScreenState();
}

class _AddImagesScreenState extends State<AddImagesScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isProcessing = false;

  Uint8List? _imageBytes;
  String? _imageName;

  int _targetPage = 1;
  double _imgWidth = 150;
  double _imgHeight = 100;
  double _posX = 200;
  double _posY = 300;

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
      _targetPage = 1;
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
      });
    }
  }

  Future<void> _processAddImage() async {
    if (_selectedFile == null) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Please select an image to insert.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await PdfEditService().addImage(
        filePath: _selectedFile!.path,
        pageNumber: _targetPage,
        imageBytes: _imageBytes!,
        position: Offset(_posX, _posY),
        size: Size(_imgWidth, _imgHeight),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.show(
        context: context,
        result: result,
        toolTitle: 'Add Images',
        onDismiss: () => Navigator.of(context).pop(),
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
        title: const Text('Add Images'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tool Header
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
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insert Images & Stamps',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Place company logos, visual seals, diagrams or photos onto any PDF page.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
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

            // File selection
            if (_selectedFile == null) ...[
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded,
                            size: 40, color: AppColors.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select PDF Document',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose the target document to receive images.',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // File Info Card
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded,
                          color: AppColors.primary, size: 28),
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
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_pdfInfo?.pageCount ?? 1} pages • ${FileUtils.formatFileSize(_selectedFile!.lengthSync())}',
                            style: GoogleFonts.plusJakartaSans(
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
              const SizedBox(height: 18),

              // Image Selection Card
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Image to Insert',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon:
                              const Icon(Icons.photo_library_rounded, size: 18),
                          label: Text(
                              _imageBytes == null ? 'Select Image' : 'Replace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_imageBytes != null) ...[
                      Center(
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              Image.memory(_imageBytes!, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _imageName ?? 'image.png',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ] else ...[
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                style: BorderStyle.solid),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.add_photo_alternate_outlined,
                                  color: AppColors.primary, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to choose stamp / logo',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Position & Sizing
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
                    Text('Placement & Dimensions',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Target Page:',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        DropdownButton<int>(
                          value: _targetPage,
                          items: List.generate(
                            _pdfInfo?.pageCount ?? 1,
                            (i) => DropdownMenuItem(
                                value: i + 1, child: Text('Page ${i + 1}')),
                          ),
                          onChanged: (v) {
                            if (v != null) setState(() => _targetPage = v);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text('Width: ${_imgWidth.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _imgWidth,
                      min: 40,
                      max: 400,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _imgWidth = v),
                    ),
                    Text('Height: ${_imgHeight.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _imgHeight,
                      min: 30,
                      max: 400,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _imgHeight = v),
                    ),
                    const Divider(height: 20),
                    Text('X Position: ${_posX.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _posX,
                      min: 10,
                      max: 400,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _posX = v),
                    ),
                    Text('Y Position: ${_posY.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _posY,
                      min: 20,
                      max: 700,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _posY = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              GradientButton(
                text: 'Stamp Image onto Page $_targetPage',
                icon: Icons.check_circle_rounded,
                isLoading: _isProcessing,
                onPressed: _processAddImage,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

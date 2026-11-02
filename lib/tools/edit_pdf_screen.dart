import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_edit_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';
import 'add_annotations_screen.dart';
import 'add_images_screen.dart';
import 'add_shapes_screen.dart';
import 'add_text_screen.dart';
import 'pdf_forms_screen.dart';

class EditPdfScreen extends StatefulWidget {
  final File? initialFile;

  const EditPdfScreen({super.key, this.initialFile});

  @override
  State<EditPdfScreen> createState() => _EditPdfScreenState();
}

class _EditPdfScreenState extends State<EditPdfScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isProcessing = false;

  final TextEditingController _textController =
      TextEditingController(text: 'Reviewed and Approved');
  int _targetPage = 1;
  double _fontSize = 14;
  Color _textColor = AppColors.primary;
  final double _posX = 50;
  double _posY = 100;
  bool _isBold = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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

  Future<void> _processQuickEdit() async {
    if (_selectedFile == null) return;
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Please enter text to add.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await PdfEditService().addText(
        filePath: _selectedFile!.path,
        pageNumber: _targetPage,
        text: _textController.text.trim(),
        position: Offset(_posX, _posY),
        fontSize: _fontSize,
        color: _textColor,
        isBold: _isBold,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.show(
        context: context,
        result: result,
        toolTitle: 'Edit PDF',
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
        title: const Text('Edit PDF'),
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
                    child: const Icon(Icons.edit_note_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDF Editor Studio',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Add text, stamps, signatures, vector shapes, or fill form fields directly on pages.',
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
                        'Select PDF to Edit',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose any document to add content and modifications.',
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
                      onPressed: _pickFile,
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Specialized Editing Mode Shortcuts
              Text(
                'Specialized Edit Modes',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildModeChip(
                      icon: Icons.text_fields_rounded,
                      label: 'Add Text',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                AddTextScreen(initialFile: _selectedFile)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildModeChip(
                      icon: Icons.image_rounded,
                      label: 'Add Image',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                AddImagesScreen(initialFile: _selectedFile)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildModeChip(
                      icon: Icons.category_rounded,
                      label: 'Add Shape',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                AddShapesScreen(initialFile: _selectedFile)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildModeChip(
                      icon: Icons.highlight_rounded,
                      label: 'Annotations',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => AddAnnotationsScreen(
                                initialFile: _selectedFile)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildModeChip(
                      icon: Icons.dynamic_form_rounded,
                      label: 'Fill Forms',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                PdfFormsScreen(initialFile: _selectedFile)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // In-Place Quick Text Editor
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
                      'Quick Text Overlay',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        labelText: 'Text Content',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Font Size: ${_fontSize.toInt()} pt',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12)),
                              Slider(
                                value: _fontSize,
                                min: 10,
                                max: 32,
                                activeColor: AppColors.primary,
                                onChanged: (v) => setState(() => _fontSize = v),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          onPressed: () => setState(() => _isBold = !_isBold),
                          icon: const Icon(Icons.format_bold_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                _isBold ? AppColors.primary : AppColors.surface,
                            foregroundColor:
                                _isBold ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('Color: ',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        ...[
                          Colors.black,
                          AppColors.primary,
                          const Color(0xFF1E3A8A),
                          const Color(0xFF16A34A)
                        ].map((c) => GestureDetector(
                              onTap: () => setState(() => _textColor = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _textColor == c
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Y Position: ${_posY.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _posY,
                      min: 30,
                      max: 750,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _posY = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              GradientButton(
                text: 'Save Edited PDF',
                icon: Icons.check_circle_rounded,
                isLoading: _isProcessing,
                onPressed: _processQuickEdit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class AddTextScreen extends StatefulWidget {
  final File? initialFile;

  const AddTextScreen({super.key, this.initialFile});

  @override
  State<AddTextScreen> createState() => _AddTextScreenState();
}

class _AddTextScreenState extends State<AddTextScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isProcessing = false;

  final TextEditingController _textController =
      TextEditingController(text: 'Confidential & Proprietary');
  final TextEditingController _nameController = TextEditingController();

  int _targetPage = 1;
  double _fontSize = 16;
  bool _isBold = true;
  bool _isItalic = false;
  Color _textColor = AppColors.primary;
  double _posX = 50;
  double _posY = 700;
  String _positionPreset = 'Bottom-Left';

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
    _nameController.dispose();
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

  void _applyPositionPreset(String preset) {
    setState(() {
      _positionPreset = preset;
      switch (preset) {
        case 'Top-Left':
          _posX = 40;
          _posY = 50;
          break;
        case 'Top-Right':
          _posX = 360;
          _posY = 50;
          break;
        case 'Center':
          _posX = 180;
          _posY = 380;
          break;
        case 'Bottom-Left':
          _posX = 40;
          _posY = 720;
          break;
        case 'Bottom-Right':
          _posX = 360;
          _posY = 720;
          break;
      }
    });
  }

  Future<void> _processAddText() async {
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
      final customName = _nameController.text.trim().isNotEmpty
          ? '${_nameController.text.trim()}.pdf'
          : null;

      final result = await PdfEditService().addText(
        filePath: _selectedFile!.path,
        pageNumber: _targetPage,
        text: _textController.text.trim(),
        position: Offset(_posX, _posY),
        fontSize: _fontSize,
        color: _textColor,
        isBold: _isBold,
        isItalic: _isItalic,
        outputName: customName,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.show(
        context: context,
        result: result,
        toolTitle: 'Add Text',
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
        title: const Text('Add Text'),
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
                    child: const Icon(Icons.text_fields_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Custom Text',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Insert typography, headers, disclaimers, or custom notes anywhere on your pages.',
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
                        'Tap to choose a PDF from your device storage.',
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

              // Content & Typography Settings
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
                    Text('Text & Typography',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        labelText: 'Text Content',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.text_format_rounded,
                            color: AppColors.primary),
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
                    const Divider(height: 24),
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
                                max: 40,
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
                          tooltip: 'Bold',
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          onPressed: () =>
                              setState(() => _isItalic = !_isItalic),
                          icon: const Icon(Icons.format_italic_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: _isItalic
                                ? AppColors.primary
                                : AppColors.surface,
                            foregroundColor: _isItalic
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                          tooltip: 'Italic',
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
                          const Color(0xFF16A34A),
                          const Color(0xFFDC2626)
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
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Positioning Card
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
                    Text('Placement Position',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Top-Left',
                        'Top-Right',
                        'Center',
                        'Bottom-Left',
                        'Bottom-Right'
                      ]
                          .map((p) => ChoiceChip(
                                label: Text(p),
                                selected: _positionPreset == p,
                                onSelected: (sel) {
                                  if (sel) _applyPositionPreset(p);
                                },
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    Text('X Offset: ${_posX.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _posX,
                      min: 10,
                      max: 450,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() {
                        _posX = v;
                        _positionPreset = 'Custom';
                      }),
                    ),
                    Text('Y Offset: ${_posY.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _posY,
                      min: 20,
                      max: 760,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() {
                        _posY = v;
                        _positionPreset = 'Custom';
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              GradientButton(
                text: 'Add Text to PDF',
                icon: Icons.check_circle_rounded,
                isLoading: _isProcessing,
                onPressed: _processAddText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

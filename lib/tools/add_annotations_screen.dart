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

class AddAnnotationsScreen extends StatefulWidget {
  final File? initialFile;

  const AddAnnotationsScreen({super.key, this.initialFile});

  @override
  State<AddAnnotationsScreen> createState() => _AddAnnotationsScreenState();
}

class _AddAnnotationsScreenState extends State<AddAnnotationsScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isProcessing = false;

  int _targetPage = 1;
  String _annotationType = 'highlight'; // highlight, underline, strikeout, note
  final TextEditingController _noteController =
      TextEditingController(text: 'Please review paragraph 3 carefully.');

  Color _annotationColor = const Color(0xFFFFEB3B); // Yellow default
  double _posX = 50;
  double _posY = 150;
  double _boxWidth = 300;
  final double _boxHeight = 25;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
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

  Future<void> _processAnnotation() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final bounds = Rect.fromLTWH(
        _posX,
        _posY,
        _boxWidth,
        _annotationType == 'note' ? 70 : _boxHeight,
      );

      final result = await PdfEditService().addAnnotation(
        filePath: _selectedFile!.path,
        pageNumber: _targetPage,
        annotationType: _annotationType,
        bounds: bounds,
        noteText:
            _annotationType == 'note' ? _noteController.text.trim() : null,
        color: _annotationColor,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.show(
        context: context,
        result: result,
        toolTitle: 'Add Annotations',
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
        title: const Text('Add Annotations'),
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
                    child: const Icon(Icons.highlight_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Annotate & Markup',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Highlight text lines, underline, strikeout, or pin sticky notes to any PDF page.',
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
                        'Choose document to add highlights and notes.',
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

              // Annotation Tool Selector
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
                    Text('Annotation Style',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'highlight',
                            icon: Icon(Icons.brush_rounded),
                            label: Text('Highlight')),
                        ButtonSegment(
                            value: 'underline',
                            icon: Icon(Icons.format_underlined_rounded),
                            label: Text('Underline')),
                        ButtonSegment(
                            value: 'strikeout',
                            icon: Icon(Icons.strikethrough_s_rounded),
                            label: Text('Strike')),
                        ButtonSegment(
                            value: 'note',
                            icon: Icon(Icons.note_alt_rounded),
                            label: Text('Note')),
                      ],
                      selected: {_annotationType},
                      onSelectionChanged: (s) =>
                          setState(() => _annotationType = s.first),
                      style: ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                    const Divider(height: 24),
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
                        Text('Color: ',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        ...[
                          const Color(0xFFFFEB3B), // Yellow
                          const Color(0xFFF23882), // Vertex Pink
                          const Color(0xFF4ADE80), // Light Green
                          const Color(0xFF60A5FA), // Light Blue
                          const Color(0xFFC084FC), // Lavender
                        ].map((c) => GestureDetector(
                              onTap: () => setState(() => _annotationColor = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _annotationColor == c
                                        ? Colors.black87
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                    if (_annotationType == 'note') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Sticky Note Message',
                          hintText: 'Type remarks or instructions...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Region / Coordinates Card
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
                    Text('Annotation Region',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
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
                      max: 750,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _posY = v),
                    ),
                    Text('Width: ${_boxWidth.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _boxWidth,
                      min: 40,
                      max: 480,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _boxWidth = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              GradientButton(
                text: 'Apply Annotation to Page $_targetPage',
                icon: Icons.check_circle_rounded,
                isLoading: _isProcessing,
                onPressed: _processAnnotation,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

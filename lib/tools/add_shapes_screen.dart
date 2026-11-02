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

class AddShapesScreen extends StatefulWidget {
  final File? initialFile;

  const AddShapesScreen({super.key, this.initialFile});

  @override
  State<AddShapesScreen> createState() => _AddShapesScreenState();
}

class _AddShapesScreenState extends State<AddShapesScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isProcessing = false;

  int _targetPage = 1;
  String _shapeType = 'rectangle'; // rectangle, circle, line, arrow
  double _strokeWidth = 2.0;
  Color _strokeColor = AppColors.primary;
  String _fillStyle = 'None'; // None, Tint, Solid
  double _posX = 100;
  double _posY = 200;
  double _shapeWidth = 200;
  double _shapeHeight = 100;

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

  Color? _getFillColor() {
    if (_fillStyle == 'None') return null;
    if (_fillStyle == 'Tint') {
      return _strokeColor.withValues(alpha: 0.2);
    }
    return _strokeColor;
  }

  Future<void> _processAddShape() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final bounds = Rect.fromLTWH(_posX, _posY, _shapeWidth, _shapeHeight);
      final result = await PdfEditService().addShape(
        filePath: _selectedFile!.path,
        pageNumber: _targetPage,
        shapeType: _shapeType,
        bounds: bounds,
        strokeColor: _strokeColor,
        fillColor: _getFillColor(),
        strokeWidth: _strokeWidth,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.show(
        context: context,
        result: result,
        toolTitle: 'Add Shapes',
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
        title: const Text('Add Shapes'),
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
                    child: const Icon(Icons.category_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Draw Geometric Shapes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Highlight diagrams and mark sections with clean rectangles, circles, arrows, and lines.',
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

              // Shape Type Selector
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
                    Text('Select Shape Type',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'rectangle',
                            icon: Icon(Icons.crop_square_rounded),
                            label: Text('Box')),
                        ButtonSegment(
                            value: 'circle',
                            icon: Icon(Icons.circle_outlined),
                            label: Text('Circle')),
                        ButtonSegment(
                            value: 'line',
                            icon: Icon(Icons.horizontal_rule_rounded),
                            label: Text('Line')),
                        ButtonSegment(
                            value: 'arrow',
                            icon: Icon(Icons.arrow_forward_rounded),
                            label: Text('Arrow')),
                      ],
                      selected: {_shapeType},
                      onSelectionChanged: (s) =>
                          setState(() => _shapeType = s.first),
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
                    Text(
                        'Line Thickness: ${_strokeWidth.toStringAsFixed(1)} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _strokeWidth,
                      min: 1,
                      max: 8,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _strokeWidth = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Stroke Color: ',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        ...[
                          AppColors.primary,
                          const Color(0xFF1E3A8A),
                          const Color(0xFF16A34A),
                          const Color(0xFFDC2626),
                          Colors.black
                        ].map((c) => GestureDetector(
                              onTap: () => setState(() => _strokeColor = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _strokeColor == c
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                    if (_shapeType == 'rectangle' ||
                        _shapeType == 'circle') ...[
                      const SizedBox(height: 16),
                      Text('Fill Mode:',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'None', label: Text('Transparent')),
                          ButtonSegment(
                              value: 'Tint', label: Text('Light Tint')),
                          ButtonSegment(
                              value: 'Solid', label: Text('Solid Fill')),
                        ],
                        selected: {_fillStyle},
                        onSelectionChanged: (s) =>
                            setState(() => _fillStyle = s.first),
                        style:
                            ButtonStyle(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Dimensions & Position
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
                    Text('Shape Size & Position',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Text('Width: ${_shapeWidth.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _shapeWidth,
                      min: 30,
                      max: 450,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _shapeWidth = v),
                    ),
                    Text('Height: ${_shapeHeight.toInt()} pt',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    Slider(
                      value: _shapeHeight,
                      min: 10,
                      max: 450,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _shapeHeight = v),
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
                text: 'Draw Shape on Page $_targetPage',
                icon: Icons.check_circle_rounded,
                isLoading: _isProcessing,
                onPressed: _processAddShape,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

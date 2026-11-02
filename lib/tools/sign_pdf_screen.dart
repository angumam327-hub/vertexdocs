import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_service.dart';
import '../services/pdf_security_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class SignPdfScreen extends StatefulWidget {
  final File? initialFile;

  const SignPdfScreen({super.key, this.initialFile});

  @override
  State<SignPdfScreen> createState() => _SignPdfScreenState();
}

class _SignPdfScreenState extends State<SignPdfScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isProcessing = false;

  int _targetPage = 1;
  String _positionPreset =
      'Bottom-Right'; // Bottom-Right, Bottom-Left, Center, Custom
  double _customX = 350;
  double _customY = 650;
  final double _sigWidth = 150;
  final double _sigHeight = 60;

  // Drawing state
  final List<List<Offset>> _strokes = [];
  Color _penColor = Colors.black;
  final double _strokeWidth = 3.0;
  Uint8List? _uploadedSigBytes;

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

  Future<void> _pickSignatureImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      setState(() {
        _uploadedSigBytes = bytes;
        _strokes.clear();
      });
    }
  }

  Future<Uint8List?> _renderSignatureToBytes() async {
    if (_uploadedSigBytes != null) {
      return _uploadedSigBytes;
    }

    if (_strokes.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 200));

    final paint = Paint()
      ..color = _penColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(400, 200);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Offset _getCalculatedPosition() {
    switch (_positionPreset) {
      case 'Bottom-Right':
        return const Offset(380, 680);
      case 'Bottom-Left':
        return const Offset(60, 680);
      case 'Center':
        return const Offset(220, 400);
      case 'Custom':
      default:
        return Offset(_customX, _customY);
    }
  }

  Future<void> _processSign() async {
    if (_selectedFile == null) return;

    final sigBytes = await _renderSignatureToBytes();
    if (!mounted) return;
    if (sigBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Please draw or upload a signature first.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pos = _getCalculatedPosition();
      final result = await PdfSecurityService().signPdf(
        filePath: _selectedFile!.path,
        signatureBytes: sigBytes,
        pageNumber: _targetPage,
        position: pos,
        signatureSize: Size(_sigWidth, _sigHeight),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.show(
        context: context,
        result: result,
        toolTitle: 'Sign PDF',
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
        title: const Text('Sign PDF'),
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
                    child: const Icon(Icons.draw_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Electronic Signatures',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Draw your signature or upload an image stamp to sign PDF documents.',
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
                        'Select PDF to Sign',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose any PDF contract, agreement, or form.',
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

              // Signature Canvas Box
              Container(
                padding: const EdgeInsets.all(16),
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
                        Text(
                          'Your Signature',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _strokes.clear();
                                  _uploadedSigBytes = null;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Clear'),
                            ),
                            IconButton(
                              onPressed: _pickSignatureImage,
                              icon: const Icon(Icons.image_outlined,
                                  color: AppColors.primary),
                              tooltip: 'Upload Stamp / Image',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Canvas area
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _uploadedSigBytes != null
                          ? Center(
                              child: Image.memory(
                                _uploadedSigBytes!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : GestureDetector(
                              onPanStart: (details) {
                                setState(() {
                                  _strokes.add([details.localPosition]);
                                });
                              },
                              onPanUpdate: (details) {
                                setState(() {
                                  if (_strokes.isNotEmpty) {
                                    _strokes.last.add(details.localPosition);
                                  }
                                });
                              },
                              child: CustomPaint(
                                painter: _SignaturePainter(
                                  strokes: _strokes,
                                  color: _penColor,
                                  width: _strokeWidth,
                                ),
                                child: _strokes.isEmpty
                                    ? Center(
                                        child: Text(
                                          '✍️ Draw your signature here with finger',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.expand(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Color swatches
                    Row(
                      children: [
                        Text(
                          'Ink Color: ',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        ...[
                          Colors.black,
                          const Color(0xFF1E3A8A),
                          const Color(0xFFDC2626),
                          AppColors.primary
                        ].map((c) => GestureDetector(
                              onTap: () => setState(() => _penColor = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _penColor == c
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

              // Position & Placement Card
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
                      'Placement Settings',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    // Target Page
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sign Page:',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        DropdownButton<int>(
                          value: _targetPage,
                          items: List.generate(
                            _pdfInfo?.pageCount ?? 1,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('Page ${index + 1}'),
                            ),
                          ),
                          onChanged: (val) {
                            if (val != null) setState(() => _targetPage = val);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      'Position Preset:',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'Bottom-Right', label: Text('Right')),
                        ButtonSegment(
                            value: 'Bottom-Left', label: Text('Left')),
                        ButtonSegment(value: 'Center', label: Text('Center')),
                        ButtonSegment(value: 'Custom', label: Text('Custom')),
                      ],
                      selected: {_positionPreset},
                      onSelectionChanged: (s) =>
                          setState(() => _positionPreset = s.first),
                      style: ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                    if (_positionPreset == 'Custom') ...[
                      const SizedBox(height: 14),
                      Text('X Position: ${_customX.toInt()} pt',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                      Slider(
                        value: _customX,
                        min: 20,
                        max: 500,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _customX = val),
                      ),
                      Text('Y Position: ${_customY.toInt()} pt',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                      Slider(
                        value: _customY,
                        min: 50,
                        max: 750,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _customY = val),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              GradientButton(
                text: 'Sign and Stamp PDF',
                icon: Icons.check_circle_rounded,
                isLoading: _isProcessing,
                onPressed: _processSign,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double width;

  _SignaturePainter(
      {required this.strokes, required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

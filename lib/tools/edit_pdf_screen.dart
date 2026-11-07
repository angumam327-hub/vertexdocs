import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/pdf_file_model.dart';
import '../services/file_service.dart';
import '../services/pdf_editor_service.dart';
import '../services/pdf_ocr_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

enum EditorTool {
  text,
  modifyText,
  highlight,
  draw,
  eraser,
  signature,
  image,
  pageTools,
}

class EditPdfScreen extends StatefulWidget {
  final File? initialFile;

  const EditPdfScreen({super.key, this.initialFile});

  @override
  State<EditPdfScreen> createState() => _EditPdfScreenState();
}

class _EditPdfScreenState extends State<EditPdfScreen> {
  final PdfEditorService _editorService = PdfEditorService();
  final FileService _fileService = FileService();

  File? _selectedFile;
  List<RenderedPdfPage> _pages = [];
  int _totalPages = 0;
  int _currentPageIndex = 0; // 0-based
  bool _isLoading = false;
  String _loadingStatus = 'Rendering PDF document...';

  // Page Rotations and Order Management
  final Map<int, int> _pageRotations = {}; // maps original page index to 0, 90, 180, 270 degrees
  final List<int> _pageOrder = []; // maps current rendered index -> original page index

  // Detected/Extracted text per original page for Tap-to-Edit & Redact
  final Map<int, List<({String text, Rect bounds})>> _pageTextLines = {};

  // Navigation & Zoom
  final ScrollController _scrollController = ScrollController();
  final TransformationController _transformController =
      TransformationController();

  // Active Tool & Bottom Panel
  EditorTool _activeTool = EditorTool.text;

  // Formatting Options
  String _selectedFont = 'Helvetica';
  double _fontSize = 14.0;
  bool _isBold = false;
  bool _isUnderline = false;
  Color _selectedColor = const Color(0xFFF23882); // Default VertexDocs Pink

  // Color Palette
  static const List<Color> _colorOptions = [
    Color(0xFFF23882), // VertexDocs Pink
    Color(0xFF1E2022), // Black
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
  ];

  // Highlight Colors
  Color _highlightColor = const Color(0xFFFFEB3B); // Yellow
  static const List<Color> _highlightOptions = [
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFF80AB), // Pink
    Color(0xFF80D8FF), // Blue
    Color(0xFFB9F6CA), // Green
  ];

  // Drawing Stroke Width
  double _drawStrokeWidth = 3.0;

  // Signatures
  final List<Uint8List> _signatureBytesList = [];
  int _selectedSignatureIndex = 1;

  // Elements on Document (Text, Highlights, Drawings, Signatures, Images)
  List<EditorElement> _elements = [];
  final List<List<EditorElement>> _undoStack = [];
  final List<List<EditorElement>> _redoStack = [];

  // Active Drawing & Highlighting Touch State
  int? _activeTouchPageIndex;
  List<Offset> _currentDrawingPoints = [];
  Offset? _highlightStart;
  Offset? _highlightEnd;

  @override
  void initState() {
    super.initState();
    _loadSampleSignatures();
    _scrollController.addListener(_onScroll);

    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_pages.isEmpty || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset.clamp(0.0, maxScroll);
    if (maxScroll > 0) {
      final index = ((currentScroll / maxScroll) * (_pages.length - 1))
          .round()
          .clamp(0, _pages.length - 1);
      if (index != _currentPageIndex) {
        setState(() => _currentPageIndex = index);
      }
    }
  }

  // Pre-generate 4 elegant designer signatures
  Future<void> _loadSampleSignatures() async {
    for (int i = 1; i <= 4; i++) {
      final bytes = await _createSampleSignatureBytes(i);
      _signatureBytesList.add(bytes);
    }
    if (mounted) setState(() {});
  }

  Future<Uint8List> _createSampleSignatureBytes(int type) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 160, 60));
    final paint = Paint()
      ..color = const Color(0xFF1E2022)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (type == 1) {
      path.moveTo(20, 42);
      path.cubicTo(35, 12, 45, 16, 55, 38);
      path.cubicTo(65, 25, 75, 20, 85, 35);
      path.cubicTo(95, 20, 105, 22, 115, 32);
      path.cubicTo(125, 25, 140, 30, 150, 42);
      path.moveTo(35, 38);
      path.lineTo(145, 38);
    } else if (type == 2) {
      path.moveTo(25, 45);
      path.cubicTo(30, 15, 60, 10, 65, 35);
      path.cubicTo(70, 50, 40, 52, 45, 25);
      path.cubicTo(50, 10, 80, 20, 95, 35);
      path.cubicTo(105, 45, 120, 15, 140, 25);
      path.cubicTo(150, 30, 130, 50, 110, 45);
      path.cubicTo(90, 40, 135, 40, 155, 38);
    } else if (type == 3) {
      path.moveTo(20, 35);
      path.lineTo(40, 15);
      path.lineTo(48, 45);
      path.cubicTo(55, 20, 70, 20, 80, 38);
      path.cubicTo(90, 25, 110, 20, 130, 35);
      path.moveTo(15, 44);
      path.lineTo(145, 40);
    } else {
      path.moveTo(30, 45);
      path.cubicTo(20, 20, 50, 12, 60, 30);
      path.cubicTo(70, 48, 55, 52, 50, 25);
      path.cubicTo(60, 25, 95, 20, 110, 35);
      path.cubicTo(120, 45, 140, 25, 150, 30);
      path.moveTo(70, 42);
      path.lineTo(140, 38);
    }

    canvas.drawPath(path, paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(160, 60);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // --- Load PDF and Render Pages Progressively ---
  Future<void> _loadPdf(File file) async {
    setState(() {
      _selectedFile = file;
      _isLoading = true;
      _loadingStatus = 'Rendering PDF document...';
      _pages = [];
      _elements = [];
      _undoStack.clear();
      _redoStack.clear();
      _currentPageIndex = 0;
      _pageRotations.clear();
      _pageOrder.clear();
      _pageTextLines.clear();
    });

    try {
      final total = await _editorService.getPdfPageCount(file.path);
      setState(() {
        _totalPages = total > 0 ? total : 1;
        _pageOrder.addAll(List.generate(_totalPages, (i) => i));
      });

      // Render Page 1 first so document is immediately visible
      final page1 = await _editorService.renderSinglePage(file.path, 1);
      if (page1 != null && mounted) {
        setState(() {
          _pages = [page1];
          _isLoading = false; // Show document immediately!
        });
        _loadExtractedTextForPage(0);
      }

      // Stream the remaining pages in the background
      for (int i = 2; i <= _totalPages; i++) {
        if (!mounted || _selectedFile?.path != file.path) break;
        final nextPg = await _editorService.renderSinglePage(file.path, i);
        if (nextPg != null && mounted) {
          setState(() {
            _pages.add(nextPg);
          });
          _loadExtractedTextForPage(i - 1);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to load PDF: $e'),
          ),
        );
      }
    }
  }

  Future<void> _loadExtractedTextForPage(int pageIndex) async {
    if (_selectedFile == null) return;
    final origIdx =
        _pageOrder.length > pageIndex ? _pageOrder[pageIndex] : pageIndex;
    if (_pageTextLines.containsKey(origIdx)) return;

    try {
      final lines = await _editorService.extractPageTextLines(
          _selectedFile!.path, origIdx);
      if (mounted) {
        setState(() {
          _pageTextLines[origIdx] = lines;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    final file = await _fileService.pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  // --- Undo / Redo ---
  void _saveSnapshotForUndo() {
    _undoStack.add(_elements.map((e) => e.copy()).toList());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_elements.map((e) => e.copy()).toList());
      _elements = _undoStack.removeLast();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_elements.map((e) => e.copy()).toList());
      _elements = _redoStack.removeLast();
    });
  }

  void _deleteElement(String id) {
    _saveSnapshotForUndo();
    setState(() {
      _elements.removeWhere((e) => e.id == id);
    });
  }

  // --- Add Text Prompt ---
  void _showAddTextDialog({
    required int pageIndex,
    Offset? position,
    String? defaultText,
  }) {
    final controller =
        TextEditingController(text: defaultText ?? 'Sample Text');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Insert Text onto PDF',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter text here...',
                hintStyle: GoogleFonts.inter(fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Text(
              'Font: $_selectedFont • Size: ${_fontSize.toInt()}pt',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _insertTextElement(
                  pageIndex: pageIndex,
                  text: text,
                  position: position,
                );
              }
            },
            child: const Text('Add Text'),
          ),
        ],
      ),
    );
  }

  // --- Modify / Redact Existing PDF Text Dialog ---
  void _showModifyExistingTextDialog(
      int pageIndex, ({String text, Rect bounds}) line) {
    final textController = TextEditingController(text: line.text);
    final double estimatedFontSize =
        (line.bounds.height * 0.85).clamp(9.0, 32.0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.find_replace_rounded,
                color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              'Edit / Redact PDF Text',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Original PDF Text:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  line.text,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Replacement Text:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: textController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter modified text (leave blank to redact/erase)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              // Fast Annotation Chips
              Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.highlight_rounded,
                        size: 16, color: Colors.orange),
                    label:
                        const Text('Highlight', style: TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.secondary,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveSnapshotForUndo();
                      setState(() {
                        _elements.add(
                          HighlightEditorElement(
                            id: 'hl_${DateTime.now().millisecondsSinceEpoch}',
                            pageIndex: pageIndex,
                            bounds: line.bounds,
                            highlightColor: _highlightColor,
                          ),
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Highlight added to text line.')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.format_underlined_rounded,
                        size: 16, color: AppColors.primary),
                    label:
                        const Text('Underline', style: TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.secondary,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _saveSnapshotForUndo();
                      setState(() {
                        _elements.add(
                          LineEditorElement(
                            id: 'line_${DateTime.now().millisecondsSinceEpoch}',
                            pageIndex: pageIndex,
                            start: Offset(line.bounds.left, line.bounds.bottom),
                            end: Offset(line.bounds.right, line.bounds.bottom),
                            color: _selectedColor,
                            strokeWidth: 1.5,
                          ),
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Underline added below text.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _saveSnapshotForUndo();
              setState(() {
                _elements.add(
                  ReplaceTextEditorElement(
                    id: 'redact_${DateTime.now().millisecondsSinceEpoch}',
                    pageIndex: pageIndex,
                    originalBounds: line.bounds,
                    newText: '', // Pure redaction whiteout
                  ),
                );
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Original text permanently redacted/erased.')),
              );
            },
            icon: const Icon(Icons.visibility_off_rounded,
                size: 16, color: AppColors.error),
            label: const Text('Redact Text',
                style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              final newText = textController.text.trim();
              _saveSnapshotForUndo();
              setState(() {
                _elements.add(
                  ReplaceTextEditorElement(
                    id: 'replace_${DateTime.now().millisecondsSinceEpoch}',
                    pageIndex: pageIndex,
                    originalBounds: line.bounds,
                    newText: newText,
                    fontSize: estimatedFontSize,
                    color: _selectedColor == const Color(0xFFF23882)
                        ? Colors.black
                        : _selectedColor,
                    isBold: _isBold,
                  ),
                );
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF text updated.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  // --- Scanned PDF OCR Recognition Dialog ---
  Future<void> _runOcrDialog() async {
    if (_selectedFile == null) return;
    setState(() {
      _isLoading = true;
      _loadingStatus =
          'Performing OCR character recognition (English & Tamil)...';
    });

    try {
      final ocrText = await PdfOcrService().recognizeText(
        filePath: _selectedFile!.path,
        language: 'en',
      );

      setState(() => _isLoading = false);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.document_scanner_rounded,
                  color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text('Scanned PDF OCR Text',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 250,
            child: SingleChildScrollView(
              child: SelectableText(
                ocrText.isEmpty ? 'No text detected on scanned pages.' : ocrText,
                style: GoogleFonts.inter(fontSize: 13, height: 1.4),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (ocrText.isNotEmpty) ...[
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ocrText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('OCR text copied to clipboard.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy All'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  final firstLine = ocrText
                      .split('\n')
                      .firstWhere(
                          (l) => l.trim().isNotEmpty && !l.startsWith('==='),
                          orElse: () => 'Recognized Text')
                      .trim();
                  _showAddTextDialog(
                    pageIndex: _currentPageIndex,
                    defaultText: firstLine,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_comment_rounded, size: 16),
                label: const Text('Insert as Text'),
              ),
            ],
          ],
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: AppColors.error, content: Text('OCR failed: $e')),
        );
      }
    }
  }

  void _insertTextElement({
    required int pageIndex,
    required String text,
    Offset? position,
  }) {
    if (pageIndex >= _pages.length) return;
    final pageSize = _pages[pageIndex].size;
    final pos = position ??
        Offset(
          (pageSize.width - 180) / 2,
          pageSize.height * 0.35,
        );

    _saveSnapshotForUndo();

    final elem = TextEditorElement(
      id: 'txt_${DateTime.now().millisecondsSinceEpoch}',
      pageIndex: pageIndex,
      text: text,
      position: pos,
      fontSize: _fontSize,
      fontFamily: _selectedFont,
      color: _selectedColor,
      isBold: _isBold,
      isUnderline: _isUnderline,
      size: Size(200, _fontSize * 2.2),
    );

    setState(() {
      _elements.add(elem);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text added. Drag to adjust position.'),
        duration: Duration(milliseconds: 1400),
      ),
    );
  }

  // --- Stamp Signature onto Document ---
  void _stampSignature(Uint8List bytes, {int? targetPageIndex}) {
    final pageIdx = targetPageIndex ?? _currentPageIndex;
    if (pageIdx >= _pages.length) return;

    final pageSize = _pages[pageIdx].size;
    final width = pageSize.width * 0.32;
    final height = width * 0.40;
    final x = (pageSize.width - width) / 2;
    final y = pageSize.height * 0.72; // Signature line position

    _saveSnapshotForUndo();

    final elem = ImageEditorElement(
      id: 'sig_${DateTime.now().millisecondsSinceEpoch}',
      pageIndex: pageIdx,
      imageBytes: bytes,
      bounds: Rect.fromLTWH(x, y, width, height),
    );

    setState(() {
      _elements.add(elem);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signature stamped on document. Drag to position.'),
        duration: Duration(milliseconds: 1400),
      ),
    );
  }

  // --- Electronic Signature Drawing Dialog ---
  void _showDrawSignatureDialog() {
    final List<Offset?> signaturePoints = [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Draw Electronic Signature',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          content: SizedBox(
            width: 320,
            height: 180,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder, width: 2),
              ),
              child: GestureDetector(
                onPanUpdate: (details) {
                  setDlgState(() {
                    signaturePoints.add(details.localPosition);
                  });
                },
                onPanEnd: (_) => setDlgState(() => signaturePoints.add(null)),
                child: CustomPaint(
                  painter: _SignaturePainter(
                    points: signaturePoints,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDlgState(() => signaturePoints.clear()),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final validPoints =
                    signaturePoints.whereType<Offset>().toList();
                if (validPoints.length > 2) {
                  final recorder = ui.PictureRecorder();
                  final canvas =
                      Canvas(recorder, const Rect.fromLTWH(0, 0, 320, 180));
                  final p = Paint()
                    ..color = Colors.black
                    ..strokeCap = StrokeCap.round
                    ..strokeWidth = 3.0;

                  for (int i = 0; i < signaturePoints.length - 1; i++) {
                    if (signaturePoints[i] != null &&
                        signaturePoints[i + 1] != null) {
                      canvas.drawLine(
                          signaturePoints[i]!, signaturePoints[i + 1]!, p);
                    }
                  }
                  final picture = recorder.endRecording();
                  final img = await picture.toImage(320, 180);
                  final bd =
                      await img.toByteData(format: ui.ImageByteFormat.png);
                  final bytes = bd!.buffer.asUint8List();

                  setState(() {
                    _signatureBytesList.add(bytes);
                    _selectedSignatureIndex = _signatureBytesList.length - 1;
                  });

                  _stampSignature(bytes);
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Stamp on PDF'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Image Insertion Handling ---
  Future<void> _pickAndInsertImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    _stampImage(bytes);
  }

  void _stampImage(Uint8List bytes) {
    if (_currentPageIndex >= _pages.length) return;
    final pageSize = _pages[_currentPageIndex].size;
    final width = pageSize.width * 0.35;
    final height = width * 0.70;
    final x = (pageSize.width - width) / 2;
    final y = pageSize.height * 0.35;

    _saveSnapshotForUndo();

    final elem = ImageEditorElement(
      id: 'img_${DateTime.now().millisecondsSinceEpoch}',
      pageIndex: _currentPageIndex,
      imageBytes: bytes,
      bounds: Rect.fromLTWH(x, y, width, height),
    );

    setState(() {
      _elements.add(elem);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image inserted onto page. Drag to position.'),
        duration: Duration(milliseconds: 1400),
      ),
    );
  }

  // --- Page Operations: Rotate, Delete, Reorder ---
  void _rotateCurrentPage() {
    if (_pages.isEmpty) return;
    _saveSnapshotForUndo();
    final origIdx = _pageOrder.length > _currentPageIndex
        ? _pageOrder[_currentPageIndex]
        : _currentPageIndex;
    setState(() {
      _pageRotations[origIdx] = ((_pageRotations[origIdx] ?? 0) + 90) % 360;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Page ${_currentPageIndex + 1} rotated 90° clockwise (${_pageRotations[origIdx]}°).'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _deleteCurrentPage() {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the only page in the document.'),
        ),
      );
      return;
    }
    _saveSnapshotForUndo();
    setState(() {
      _pages.removeAt(_currentPageIndex);
      if (_pageOrder.length > _currentPageIndex) {
        _pageOrder.removeAt(_currentPageIndex);
      }
      _elements.removeWhere((e) => e.pageIndex == _currentPageIndex);
      if (_currentPageIndex >= _pages.length) {
        _currentPageIndex = _pages.length - 1;
      }
      _totalPages = _pages.length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Page removed from document.'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  void _moveCurrentPage(int delta) {
    final newIdx = _currentPageIndex + delta;
    if (newIdx < 0 || newIdx >= _pages.length) return;
    _saveSnapshotForUndo();
    setState(() {
      final page = _pages.removeAt(_currentPageIndex);
      _pages.insert(newIdx, page);
      if (_pageOrder.length > _currentPageIndex) {
        final orig = _pageOrder.removeAt(_currentPageIndex);
        _pageOrder.insert(newIdx, orig);
      }
      _currentPageIndex = newIdx;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Page moved to position ${newIdx + 1}.'),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  // --- Save Edited PDF ---
  Future<void> _saveEditedPdf() async {
    if (_selectedFile == null) return;

    setState(() {
      _isLoading = true;
      _loadingStatus = 'Embedding changes and saving PDF...';
    });

    try {
      final resultModel = await _editorService.saveEditedPdf(
        originalPdfPath: _selectedFile!.path,
        elements: _elements,
        pageOrder: _pageOrder,
        pageRotations: _pageRotations,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        _showSaveSuccessModal(resultModel);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Error saving PDF: $e'),
          ),
        );
      }
    }
  }

  void _showSaveSuccessModal(PdfFileModel resultModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PDF Successfully Edited & Saved!',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        resultModel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final dlPath = await _fileService
                          .downloadFileToDevice(resultModel.path);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text(dlPath != null
                              ? 'Saved to Downloads: $dlPath'
                              : 'Saved to device storage'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ShareService.openFile(resultModel.path);
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Open'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ShareService.shareFile(resultModel.path);
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Main Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildTopAppBar(),
      body: _isLoading
          ? _buildLoadingView()
          : _selectedFile == null
              ? _buildPickerView()
              : _buildEditorWorkspace(),
      bottomNavigationBar:
          _selectedFile != null ? _buildBottomControlsArea() : null,
    );
  }

  // 1. TOP APP BAR
  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Color(0xFF1E2022),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        'Edit PDF',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: const Color(0xFF1E2022),
        ),
      ),
      centerTitle: true,
      actions: [
        if (_selectedFile != null) ...[
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded, size: 20),
            tooltip: 'OCR Scanned Pages',
            color: AppColors.primary,
            onPressed: _runOcrDialog,
          ),
          IconButton(
            icon: const Icon(Icons.undo_rounded, size: 20),
            tooltip: 'Undo',
            color: _undoStack.isNotEmpty
                ? AppColors.primary
                : Colors.grey.shade400,
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo_rounded, size: 20),
            tooltip: 'Redo',
            color: _redoStack.isNotEmpty
                ? AppColors.primary
                : Colors.grey.shade400,
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_rounded, size: 20),
            tooltip: 'Change PDF',
            color: AppColors.textPrimary,
            onPressed: _pickFile,
          ),
          // Save Icon Button in Pink Rounded Box
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: InkWell(
                onTap: _saveEditedPdf,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 2. LOADING VIEW
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            _loadingStatus,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 3. FILE PICKER VIEW
  Widget _buildPickerView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Select PDF to Edit',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose any document to view its pages, insert custom text, highlight lines, draw freehand, and stamp signatures.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Choose PDF File',
                  icon: Icons.folder_open_rounded,
                  onPressed: _pickFile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. MAIN EDITOR WORKSPACE
  Widget _buildEditorWorkspace() {
    return Stack(
      children: [
        // Center Document Area: Scrollable & Pinch-to-Zoom
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.8,
            maxScale: 3.0,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(
                top: 70, // Space for floating toolbar
                bottom: 24,
                left: 16,
                right: 16,
              ),
              child: Center(
                child: Column(
                  children: [
                    for (int i = 0; i < _pages.length; i++) ...[
                      _buildPdfPageSheet(i),
                      if (i < _pages.length - 1) const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Floating Page Navigation Capsule (Top Left / Center)
        Positioned(
          top: 14,
          left: 16,
          child: _buildPageNavCapsule(),
        ),

        // Floating Editing Toolbar on the PDF (Top Right / Center)
        Positioned(
          top: 10,
          right: 16,
          child: _buildFloatingToolbar(),
        ),
      ],
    );
  }

  // Page Indicator Capsule: < 1 / 9 >
  Widget _buildPageNavCapsule() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _currentPageIndex > 0
                ? () {
                    final prev = _currentPageIndex - 1;
                    setState(() => _currentPageIndex = prev);
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: _currentPageIndex > 0
                  ? AppColors.primary
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${_currentPageIndex + 1} / ${_totalPages > 0 ? _totalPages : _pages.length}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: _currentPageIndex < _pages.length - 1
                ? () {
                    final next = _currentPageIndex + 1;
                    setState(() => _currentPageIndex = next);
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: _currentPageIndex < _pages.length - 1
                  ? AppColors.primary
                  : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // Floating Toolbar on the PDF: Add Text, Modify Text, Highlight, Draw, Eraser, Signature, Image, Page Tools
  Widget _buildFloatingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolButton(
              tool: EditorTool.text,
              icon: Icons.title_rounded,
              tooltip: 'Add Text',
            ),
            _buildToolButton(
              tool: EditorTool.modifyText,
              icon: Icons.find_replace_rounded,
              tooltip: 'Edit / Redact PDF Text',
            ),
            _buildToolButton(
              tool: EditorTool.highlight,
              icon: Icons.highlight_rounded,
              tooltip: 'Highlight',
            ),
            _buildToolButton(
              tool: EditorTool.draw,
              icon: Icons.edit_rounded,
              tooltip: 'Draw',
            ),
            _buildToolButton(
              tool: EditorTool.eraser,
              icon: Icons.auto_fix_normal_rounded,
              tooltip: 'Eraser',
            ),
            _buildToolButton(
              tool: EditorTool.signature,
              icon: Icons.gesture_rounded,
              tooltip: 'Signature',
            ),
            _buildToolButton(
              tool: EditorTool.image,
              icon: Icons.add_photo_alternate_rounded,
              tooltip: 'Insert Image',
            ),
            _buildToolButton(
              tool: EditorTool.pageTools,
              icon: Icons.auto_stories_rounded,
              tooltip: 'Page Tools',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required EditorTool tool,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _activeTool == tool;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTool = tool;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // Centered PDF Document Sheet
  Widget _buildPdfPageSheet(int pageIndex) {
    if (pageIndex >= _pages.length) return const SizedBox.shrink();
    final page = _pages[pageIndex];

    // Compute screen fitting width
    final screenWidth = MediaQuery.of(context).size.width;
    final displayWidth = (screenWidth - 32).clamp(280.0, 500.0);
    final displayHeight = displayWidth * (page.size.height / page.size.width);

    final scaleX = displayWidth / page.size.width;
    final scaleY = displayHeight / page.size.height;

    // Filter elements on this page
    final pageElements =
        _elements.where((e) => e.pageIndex == pageIndex).toList();

    final origIdx =
        _pageOrder.length > pageIndex ? _pageOrder[pageIndex] : pageIndex;
    final rotDegrees = _pageRotations[origIdx] ?? 0;

    final sheetWidget = Container(
      width: displayWidth,
      height: displayHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            // 1. Actual PDF Page Image
            Positioned.fill(
              child: Image.memory(
                page.imageBytes,
                fit: BoxFit.fill,
              ),
            ),

            // 2. Custom Painted Overlay (Highlights & Drawings & Redactions)
            Positioned.fill(
              child: CustomPaint(
                painter: _PageOverlayPainter(
                  elements: pageElements,
                  scaleX: scaleX,
                  scaleY: scaleY,
                  activeDrawingPoints: _activeTouchPageIndex == pageIndex
                      ? _currentDrawingPoints
                      : const [],
                  activeDrawingColor: _selectedColor,
                  activeDrawingWidth: _drawStrokeWidth,
                  activeHighlightRect: _activeTouchPageIndex == pageIndex &&
                          _highlightStart != null &&
                          _highlightEnd != null
                      ? Rect.fromPoints(_highlightStart!, _highlightEnd!)
                      : null,
                  activeHighlightColor: _highlightColor,
                ),
              ),
            ),

            // 3. Interactive Recognized PDF Text Outlines (when in modifyText tool mode)
            if (_activeTool == EditorTool.modifyText) ...[
              for (final line in (_pageTextLines[origIdx] ?? [])) ...[
                Positioned(
                  left: line.bounds.left * scaleX,
                  top: line.bounds.top * scaleY,
                  width:
                      (line.bounds.width * scaleX).clamp(24.0, displayWidth),
                  height:
                      (line.bounds.height * scaleY).clamp(16.0, displayHeight),
                  child: GestureDetector(
                    onTap: () =>
                        _showModifyExistingTextDialog(pageIndex, line),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ],

            // 4. Interactive Draggable Elements (Text & Signatures)
            for (final elem in pageElements) ...[
              if (elem is TextEditorElement)
                _buildDraggableText(elem, scaleX, scaleY),
              if (elem is ImageEditorElement)
                _buildDraggableSignature(elem, scaleX, scaleY),
            ],

            // 5. Gesture Capture for Drawing / Highlighting / Add Text / Eraser
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) => _handlePageTap(
                    pageIndex, details.localPosition, scaleX, scaleY),
                onPanStart: (details) => _handlePanStart(
                    pageIndex, details.localPosition, scaleX, scaleY),
                onPanUpdate: (details) => _handlePanUpdate(
                    pageIndex, details.localPosition, scaleX, scaleY),
                onPanEnd: (details) => _handlePanEnd(pageIndex),
              ),
            ),
          ],
        ),
      ),
    );

    if (rotDegrees > 0) {
      return RotatedBox(
        quarterTurns: rotDegrees ~/ 90,
        child: sheetWidget,
      );
    }
    return sheetWidget;
  }

  // Draggable Text Element on PDF Sheet
  Widget _buildDraggableText(
      TextEditorElement elem, double scaleX, double scaleY) {
    final left = elem.position.dx * scaleX;
    final top = elem.position.dy * scaleY;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            elem.position = Offset(
              elem.position.dx + (details.delta.dx / scaleX),
              elem.position.dy + (details.delta.dy / scaleY),
            );
          });
        },
        onTap: () {
          if (_activeTool == EditorTool.eraser) {
            _deleteElement(elem.id);
          } else {
            _showEditTextDialog(elem);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Text(
            elem.text,
            style: TextStyle(
              fontSize: elem.fontSize * scaleX,
              fontFamily: elem.fontFamily,
              fontWeight: elem.isBold ? FontWeight.bold : FontWeight.normal,
              decoration: elem.isUnderline
                  ? TextDecoration.underline
                  : TextDecoration.none,
              color: elem.color,
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTextDialog(TextEditorElement elem) {
    final controller = TextEditingController(text: elem.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Text Content'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteElement(elem.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveSnapshotForUndo();
              setState(() {
                elem.text = controller.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // Draggable Signature or Image on PDF Sheet
  Widget _buildDraggableSignature(
      ImageEditorElement elem, double scaleX, double scaleY) {
    final left = elem.bounds.left * scaleX;
    final top = elem.bounds.top * scaleY;
    final width = elem.bounds.width * scaleX;
    final height = elem.bounds.height * scaleY;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            elem.bounds = Rect.fromLTWH(
              elem.bounds.left + (details.delta.dx / scaleX),
              elem.bounds.top + (details.delta.dy / scaleY),
              elem.bounds.width,
              elem.bounds.height,
            );
          });
        },
        onTap: () {
          if (_activeTool == EditorTool.eraser) {
            _deleteElement(elem.id);
          }
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.6),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Image.memory(elem.imageBytes, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // Touch Handlers for PDF Page
  void _handlePageTap(
      int pageIndex, Offset localPos, double scaleX, double scaleY) {
    final pdfPoint = Offset(localPos.dx / scaleX, localPos.dy / scaleY);

    if (_activeTool == EditorTool.modifyText) {
      final origIdx =
          _pageOrder.length > pageIndex ? _pageOrder[pageIndex] : pageIndex;
      final lines = _pageTextLines[origIdx] ?? [];
      for (final line in lines) {
        if (line.bounds.inflate(8).contains(pdfPoint)) {
          _showModifyExistingTextDialog(pageIndex, line);
          return;
        }
      }
    } else if (_activeTool == EditorTool.text) {
      _showAddTextDialog(pageIndex: pageIndex, position: pdfPoint);
    } else if (_activeTool == EditorTool.signature) {
      if (_signatureBytesList.isNotEmpty) {
        _stampSignature(
          _signatureBytesList[_selectedSignatureIndex],
          targetPageIndex: pageIndex,
        );
      } else {
        _showDrawSignatureDialog();
      }
    } else if (_activeTool == EditorTool.eraser) {
      for (final elem in _elements.reversed) {
        if (elem.pageIndex != pageIndex) continue;
        if (elem is HighlightEditorElement &&
            elem.bounds.inflate(12).contains(pdfPoint)) {
          _deleteElement(elem.id);
          break;
        } else if (elem is DrawingEditorElement) {
          bool hit = false;
          for (final pt in elem.points) {
            if ((pt - pdfPoint).distance < 24) {
              hit = true;
              break;
            }
          }
          if (hit) {
            _deleteElement(elem.id);
            break;
          }
        }
      }
    }
  }

  void _handlePanStart(
      int pageIndex, Offset localPos, double scaleX, double scaleY) {
    final pdfPoint = Offset(localPos.dx / scaleX, localPos.dy / scaleY);
    _activeTouchPageIndex = pageIndex;

    if (_activeTool == EditorTool.draw) {
      _saveSnapshotForUndo();
      setState(() {
        _currentDrawingPoints = [pdfPoint];
      });
    } else if (_activeTool == EditorTool.highlight) {
      setState(() {
        _highlightStart = pdfPoint;
        _highlightEnd = pdfPoint;
      });
    }
  }

  void _handlePanUpdate(
      int pageIndex, Offset localPos, double scaleX, double scaleY) {
    if (_activeTouchPageIndex != pageIndex) return;
    final pdfPoint = Offset(localPos.dx / scaleX, localPos.dy / scaleY);

    if (_activeTool == EditorTool.draw) {
      setState(() {
        _currentDrawingPoints.add(pdfPoint);
      });
    } else if (_activeTool == EditorTool.highlight) {
      setState(() {
        _highlightEnd = pdfPoint;
      });
    }
  }

  void _handlePanEnd(int pageIndex) {
    if (_activeTouchPageIndex != pageIndex) return;

    if (_activeTool == EditorTool.draw) {
      if (_currentDrawingPoints.isNotEmpty) {
        setState(() {
          _elements.add(
            DrawingEditorElement(
              id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
              pageIndex: pageIndex,
              points: List.from(_currentDrawingPoints),
              color: _selectedColor,
              strokeWidth: _drawStrokeWidth,
            ),
          );
          _currentDrawingPoints = [];
          _activeTouchPageIndex = null;
        });
      }
    } else if (_activeTool == EditorTool.highlight) {
      if (_highlightStart != null && _highlightEnd != null) {
        final rect = Rect.fromPoints(_highlightStart!, _highlightEnd!);
        if (rect.width > 4 || rect.height > 4) {
          _saveSnapshotForUndo();
          setState(() {
            _elements.add(
              HighlightEditorElement(
                id: 'hl_${DateTime.now().millisecondsSinceEpoch}',
                pageIndex: pageIndex,
                bounds: rect,
                highlightColor: _highlightColor,
              ),
            );
            _highlightStart = null;
            _highlightEnd = null;
            _activeTouchPageIndex = null;
          });
        }
      }
    }
  }

  // 5. BOTTOM EDITING CONTROLS & SAVE BUTTON
  Widget _buildBottomControlsArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Contextual Editing Tool Panel
            _buildActiveToolPanel(),
            const SizedBox(height: 12),

            // Bottom Save PDF Button
            GradientButton(
              text: 'Save PDF',
              icon: Icons.check_circle_outline_rounded,
              onPressed: _saveEditedPdf,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveToolPanel() {
    switch (_activeTool) {
      case EditorTool.text:
        return _buildTextEditingPanel();
      case EditorTool.modifyText:
        return _buildModifyTextPanel();
      case EditorTool.signature:
        return _buildSignaturePanel();
      case EditorTool.highlight:
        return _buildHighlightPanel();
      case EditorTool.draw:
        return _buildDrawPanel();
      case EditorTool.eraser:
        return _buildEraserPanel();
      case EditorTool.image:
        return _buildImagePanel();
      case EditorTool.pageTools:
        return _buildPageToolsPanel();
    }
  }

  // Modify / Redact Existing PDF Text Panel
  Widget _buildModifyTextPanel() {
    final origIdx = _pageOrder.length > _currentPageIndex
        ? _pageOrder[_currentPageIndex]
        : _currentPageIndex;
    final textLineCount = _pageTextLines[origIdx]?.length ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.find_replace_rounded,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Text(
              'Edit & Redact Original PDF Text',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '$textLineCount line(s) detected',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tap any highlighted text box on the document to modify text, redact (whiteout), underline, or highlight.',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _loadExtractedTextForPage(_currentPageIndex),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Re-scan Text'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _runOcrDialog,
              icon: const Icon(Icons.document_scanner_rounded, size: 14),
              label: const Text('OCR (Scanned Pages)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.cardBorder),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Text Panel: Font Selection, Font Size, Bold, Underline, Colors
  Widget _buildTextEditingPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Font selection chips
        Row(
          children: [
            Text(
              'Font:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            _buildFontChip('Helvetica', 'Sans'),
            const SizedBox(width: 6),
            _buildFontChip('Times', 'Serif'),
            const SizedBox(width: 6),
            _buildFontChip('Courier', 'Mono'),
            const Spacer(),
            // Insert Text button
            InkWell(
              onTap: () => _showAddTextDialog(pageIndex: _currentPageIndex),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 2),
                    Text(
                      'Insert',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Row 2: Font Size, Bold, Underline, and Color circles
        Row(
          children: [
            // Font Size: [-] 14pt [+]
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (_fontSize > 8) setState(() => _fontSize -= 1);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.remove_rounded, size: 16),
                    ),
                  ),
                  Text(
                    '${_fontSize.toInt()}pt',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (_fontSize < 40) setState(() => _fontSize += 1);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.add_rounded, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Bold Toggle
            InkWell(
              onTap: () => setState(() => _isBold = !_isBold),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _isBold ? AppColors.secondary : const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isBold ? AppColors.primary : AppColors.cardBorder,
                  ),
                ),
                child: Icon(
                  Icons.format_bold_rounded,
                  size: 18,
                  color: _isBold ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Underline Toggle
            InkWell(
              onTap: () => setState(() => _isUnderline = !_isUnderline),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _isUnderline
                      ? AppColors.secondary
                      : const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isUnderline ? AppColors.primary : AppColors.cardBorder,
                  ),
                ),
                child: Icon(
                  Icons.format_underlined_rounded,
                  size: 18,
                  color:
                      _isUnderline ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            const Spacer(),

            // Color Circles: Pink, Black, Blue, Green
            for (final col in _colorOptions) ...[
              GestureDetector(
                onTap: () => setState(() => _selectedColor = col),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColor == col
                          ? Colors.white
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: _selectedColor == col
                        ? [
                            BoxShadow(
                              color: col.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: _selectedColor == col
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFontChip(String fontName, String label) {
    final isSelected = _selectedFont == fontName;
    return InkWell(
      onTap: () => setState(() => _selectedFont = fontName),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // Signature Panel: 4 Designer Signatures + Draw Custom
  Widget _buildSignaturePanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Signature to Stamp:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            InkWell(
              onTap: _showDrawSignatureDialog,
              child: Text(
                '+ Draw Custom',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _signatureBytesList.length,
            itemBuilder: (context, idx) {
              final isSelected = _selectedSignatureIndex == idx;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedSignatureIndex = idx);
                  _stampSignature(_signatureBytesList[idx]);
                },
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.primary : AppColors.cardBorder,
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Image.memory(
                          _signatureBytesList[idx],
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (isSelected)
                        const Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Highlight Panel: Color options & instructions
  Widget _buildHighlightPanel() {
    return Row(
      children: [
        Text(
          'Highlight Color:',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        for (final col in _highlightOptions) ...[
          GestureDetector(
            onTap: () => setState(() => _highlightColor = col),
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: col,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _highlightColor == col
                      ? AppColors.primary
                      : Colors.grey.shade400,
                  width: _highlightColor == col ? 2 : 1,
                ),
              ),
              child: _highlightColor == col
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.black87)
                  : null,
            ),
          ),
        ],
        const Spacer(),
        Text(
          'Drag on page',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  // Draw Panel: Stroke Width & Color
  Widget _buildDrawPanel() {
    return Row(
      children: [
        Text(
          'Width:',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        for (final w in [2.0, 4.0, 6.0]) ...[
          InkWell(
            onTap: () => setState(() => _drawStrokeWidth = w),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: _drawStrokeWidth == w
                    ? AppColors.primary
                    : const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${w.toInt()}px',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      _drawStrokeWidth == w ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
        const Spacer(),
        for (final col in _colorOptions) ...[
          GestureDetector(
            onTap: () => setState(() => _selectedColor = col),
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: col,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedColor == col ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                boxShadow: _selectedColor == col
                    ? [
                        BoxShadow(
                          color: col.withValues(alpha: 0.6),
                          blurRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: _selectedColor == col
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  // Eraser Panel
  Widget _buildEraserPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap any text, drawing, highlight, or signature on the document to erase it.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Image Insertion Panel
  Widget _buildImagePanel() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickAndInsertImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('From Gallery'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickAndInsertImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Take Photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Page Tools Panel: Rotate 90 deg, Reorder Up/Down, Delete
  Widget _buildPageToolsPanel() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _rotateCurrentPage,
            icon: const Icon(Icons.rotate_right_rounded, size: 18),
            label: const Text('Rotate 90°'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.cardBorder),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _currentPageIndex > 0 ? () => _moveCurrentPage(-1) : null,
          icon: const Icon(Icons.arrow_upward_rounded),
          tooltip: 'Move Page Up',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF4F6F9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _currentPageIndex < _pages.length - 1
              ? () => _moveCurrentPage(1)
              : null,
          icon: const Icon(Icons.arrow_downward_rounded),
          tooltip: 'Move Page Down',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF4F6F9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _deleteCurrentPage,
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          tooltip: 'Delete Page',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.error.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom Painter for Page Elements (Highlights & Drawings)
class _PageOverlayPainter extends CustomPainter {
  final List<EditorElement> elements;
  final double scaleX;
  final double scaleY;
  final List<Offset> activeDrawingPoints;
  final Color activeDrawingColor;
  final double activeDrawingWidth;
  final Rect? activeHighlightRect;
  final Color activeHighlightColor;

  _PageOverlayPainter({
    required this.elements,
    required this.scaleX,
    required this.scaleY,
    required this.activeDrawingPoints,
    required this.activeDrawingColor,
    required this.activeDrawingWidth,
    required this.activeHighlightRect,
    required this.activeHighlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Saved Highlights
    for (final elem in elements) {
      if (elem is HighlightEditorElement) {
        final p = Paint()
          ..color = elem.highlightColor.withValues(alpha: 0.40)
          ..style = PaintingStyle.fill;

        final scaledRect = Rect.fromLTWH(
          elem.bounds.left * scaleX,
          elem.bounds.top * scaleY,
          elem.bounds.width * scaleX,
          elem.bounds.height * scaleY,
        );
        canvas.drawRect(scaledRect, p);
      }
    }

    // 2. Draw Active Highlight
    if (activeHighlightRect != null) {
      final p = Paint()
        ..color = activeHighlightColor.withValues(alpha: 0.40)
        ..style = PaintingStyle.fill;

      final scaledRect = Rect.fromLTWH(
        activeHighlightRect!.left * scaleX,
        activeHighlightRect!.top * scaleY,
        activeHighlightRect!.width * scaleX,
        activeHighlightRect!.height * scaleY,
      );
      canvas.drawRect(scaledRect, p);
    }

    // 3. Draw Saved Freehand Paths
    for (final elem in elements) {
      if (elem is DrawingEditorElement && elem.points.length > 1) {
        final p = Paint()
          ..color = elem.color
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = elem.strokeWidth * scaleX
          ..style = PaintingStyle.stroke;

        final path = Path();
        path.moveTo(
            elem.points.first.dx * scaleX, elem.points.first.dy * scaleY);
        for (int i = 1; i < elem.points.length; i++) {
          path.lineTo(elem.points[i].dx * scaleX, elem.points[i].dy * scaleY);
        }
        canvas.drawPath(path, p);
      }
    }

    // 4. Draw Active Freehand Path
    if (activeDrawingPoints.length > 1) {
      final p = Paint()
        ..color = activeDrawingColor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = activeDrawingWidth * scaleX
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(activeDrawingPoints.first.dx * scaleX,
          activeDrawingPoints.first.dy * scaleY);
      for (int i = 1; i < activeDrawingPoints.length; i++) {
        path.lineTo(activeDrawingPoints[i].dx * scaleX,
            activeDrawingPoints[i].dy * scaleY);
      }
      canvas.drawPath(path, p);
    }

    // 5. Draw Redaction Whiteouts, Replacement Text, and Underlines
    for (final elem in elements) {
      if (elem is ReplaceTextEditorElement) {
        final scaledRect = Rect.fromLTWH(
          elem.originalBounds.left * scaleX,
          elem.originalBounds.top * scaleY,
          elem.originalBounds.width * scaleX,
          elem.originalBounds.height * scaleY,
        );
        canvas.drawRect(
          scaledRect,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
        if (elem.newText.trim().isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(
              text: elem.newText,
              style: TextStyle(
                color: elem.color,
                fontSize: elem.fontSize * scaleX,
                fontWeight: elem.isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: scaledRect.width * 1.5);
          tp.paint(
            canvas,
            Offset(
              scaledRect.left,
              scaledRect.top + (scaledRect.height - tp.height) / 2,
            ),
          );
        }
      } else if (elem is LineEditorElement) {
        final p = Paint()
          ..color = elem.color
          ..strokeWidth = elem.strokeWidth * scaleX;
        canvas.drawLine(
          Offset(elem.start.dx * scaleX, elem.start.dy * scaleY),
          Offset(elem.end.dx * scaleX, elem.end.dy * scaleY),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PageOverlayPainter oldDelegate) => true;
}

// Custom Painter for Signature Dialog
class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;

  _SignaturePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

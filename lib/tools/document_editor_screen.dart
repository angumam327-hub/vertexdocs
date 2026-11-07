import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/document_editor_service.dart';
import '../services/file_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import 'edit_pdf_screen.dart';

class DocumentEditorScreen extends StatefulWidget {
  final File? initialFile;

  const DocumentEditorScreen({super.key, this.initialFile});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  final DocumentEditorService _editorService = DocumentEditorService();

  A4DocumentModel? _docModel;
  bool _isLoading = false;
  String _loadingStatus = 'Loading document...';

  // Active selected item for toolbar operations
  String? _activeItemId;

  // Undo / Redo history
  final List<A4DocumentModel> _undoStack = [];
  final List<A4DocumentModel> _redoStack = [];

  // Zoom
  double _zoomLevel = 1.0;
  final TransformationController _transformController =
      TransformationController();

  // Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Collapsible page navigation strip
  bool _showPageStrip = false;

  // Text editing controllers per paragraph / cell
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _transformController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFile(File file) async {
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Parsing Word document layout, headings & tables...';
    });

    try {
      final doc = await _editorService.loadDocument(file.path);
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();

      for (final it in doc.items) {
        if (it is DocParagraphItem) {
          _controllers[it.id] = TextEditingController(text: it.text);
        } else if (it is DocTableItem) {
          for (int r = 0; r < it.rows.length; r++) {
            for (int c = 0; c < it.rows[r].length; c++) {
              final cellKey = '${it.id}_r${r}_c$c';
              _controllers[cellKey] =
                  TextEditingController(text: it.rows[r][c].text);
            }
          }
        }
      }

      setState(() {
        _docModel = doc;
        _activeItemId = doc.items.isNotEmpty ? doc.items.first.id : null;
        _undoStack.clear();
        _redoStack.clear();
        _isLoading = false;
        _zoomLevel = 1.0;
        _transformController.value = Matrix4.identity();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to load document: $e'),
          ),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'txt'],
        allowMultiple: false,
      );
      if (res != null && res.files.single.path != null) {
        await _loadFile(File(res.files.single.path!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Error selecting file: $e'),
          ),
        );
      }
    }
  }

  void _createNewBlankA4Doc() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();

    final titleItem = DocParagraphItem(
      id: 'title_1',
      text: 'Document Title',
      fontSize: 22.0,
      isBold: true,
      headingStyle: 'title',
      alignment: TextAlign.center,
    );
    final pItem = DocParagraphItem(
      id: 'p_1',
      text:
          'Start typing your document text directly inside this A4 page sheet...',
      fontSize: 13.0,
    );

    _controllers[titleItem.id] = TextEditingController(text: titleItem.text);
    _controllers[pItem.id] = TextEditingController(text: pItem.text);

    setState(() {
      _docModel = A4DocumentModel(
        originalPath: 'Untitled.docx',
        title: 'Untitled Document',
        fileType: 'DOCX',
        items: [titleItem, pItem],
      );
      _activeItemId = titleItem.id;
      _undoStack.clear();
      _redoStack.clear();
      _zoomLevel = 1.0;
      _transformController.value = Matrix4.identity();
    });
  }

  void _saveSnapshotForUndo() {
    if (_docModel == null) return;
    _syncTextFromControllers();
    _undoStack.add(_docModel!.copy());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty || _docModel == null) return;
    _syncTextFromControllers();
    setState(() {
      _redoStack.add(_docModel!.copy());
      _docModel = _undoStack.removeLast();
      _refreshControllersFromModel();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty || _docModel == null) return;
    _syncTextFromControllers();
    setState(() {
      _undoStack.add(_docModel!.copy());
      _docModel = _redoStack.removeLast();
      _refreshControllersFromModel();
    });
  }

  void _refreshControllersFromModel() {
    if (_docModel == null) return;
    for (final it in _docModel!.items) {
      if (it is DocParagraphItem) {
        if (_controllers.containsKey(it.id)) {
          _controllers[it.id]!.text = it.text;
        } else {
          _controllers[it.id] = TextEditingController(text: it.text);
        }
      } else if (it is DocTableItem) {
        for (int r = 0; r < it.rows.length; r++) {
          for (int c = 0; c < it.rows[r].length; c++) {
            final key = '${it.id}_r${r}_c$c';
            if (_controllers.containsKey(key)) {
              _controllers[key]!.text = it.rows[r][c].text;
            } else {
              _controllers[key] =
                  TextEditingController(text: it.rows[r][c].text);
            }
          }
        }
      }
    }
  }

  void _syncTextFromControllers() {
    if (_docModel == null) return;
    for (final it in _docModel!.items) {
      if (it is DocParagraphItem && _controllers.containsKey(it.id)) {
        it.text = _controllers[it.id]!.text;
      } else if (it is DocTableItem) {
        for (int r = 0; r < it.rows.length; r++) {
          for (int c = 0; c < it.rows[r].length; c++) {
            final key = '${it.id}_r${r}_c$c';
            if (_controllers.containsKey(key)) {
              it.rows[r][c].text = _controllers[key]!.text;
            }
          }
        }
      }
    }
  }

  void _setZoom(double newZoom) {
    setState(() {
      _zoomLevel = newZoom.clamp(0.6, 2.5);
      _transformController.value =
          Matrix4.diagonal3Values(_zoomLevel, _zoomLevel, 1.0);
    });
  }

  DocParagraphItem? get _activeParagraph {
    if (_docModel == null || _activeItemId == null) return null;
    final item = _docModel!.items.firstWhere(
      (e) => e.id == _activeItemId,
      orElse: () => _docModel!.items.first,
    );
    return item is DocParagraphItem ? item : null;
  }

  void _toggleBold() {
    final p = _activeParagraph;
    if (p == null) return;
    _saveSnapshotForUndo();
    setState(() => p.isBold = !p.isBold);
  }

  void _toggleItalic() {
    final p = _activeParagraph;
    if (p == null) return;
    _saveSnapshotForUndo();
    setState(() => p.isItalic = !p.isItalic);
  }

  void _toggleUnderline() {
    final p = _activeParagraph;
    if (p == null) return;
    _saveSnapshotForUndo();
    setState(() => p.isUnderline = !p.isUnderline);
  }

  void _setAlignment(TextAlign align) {
    final p = _activeParagraph;
    if (p == null) return;
    _saveSnapshotForUndo();
    setState(() => p.alignment = align);
  }

  void _changeFontSize(double delta) {
    final p = _activeParagraph;
    if (p == null) return;
    _saveSnapshotForUndo();
    setState(() => p.fontSize = (p.fontSize + delta).clamp(9.0, 36.0));
  }

  void _setHeadingStyle(String style) {
    final p = _activeParagraph;
    if (p == null) return;
    _saveSnapshotForUndo();
    setState(() {
      p.headingStyle = style;
      if (style == 'title') {
        p.fontSize = 24.0;
        p.isBold = true;
      } else if (style == 'heading1') {
        p.fontSize = 18.0;
        p.isBold = true;
      } else if (style == 'heading2') {
        p.fontSize = 15.0;
        p.isBold = true;
      } else {
        p.fontSize = 13.0;
      }
    });
  }

  void _insertParagraphAfterActive() {
    if (_docModel == null) return;
    _saveSnapshotForUndo();

    final newId = 'p_${DateTime.now().millisecondsSinceEpoch}';
    final newP = DocParagraphItem(id: newId, text: '', fontSize: 13.0);
    _controllers[newId] = TextEditingController(text: '');

    final index = _docModel!.items.indexWhere((e) => e.id == _activeItemId);
    final targetIndex = index >= 0 ? index + 1 : _docModel!.items.length;

    setState(() {
      _docModel!.items.insert(targetIndex, newP);
      _activeItemId = newId;
    });
  }

  void _insertTable() {
    if (_docModel == null) return;
    _saveSnapshotForUndo();

    final tblId = 'tbl_${DateTime.now().millisecondsSinceEpoch}';
    final table = DocTableItem(
      id: tblId,
      rows: [
        [
          DocTableCell(text: 'Header 1', isHeader: true),
          DocTableCell(text: 'Header 2', isHeader: true),
          DocTableCell(text: 'Header 3', isHeader: true),
        ],
        [
          DocTableCell(text: 'Cell 1'),
          DocTableCell(text: 'Cell 2'),
          DocTableCell(text: 'Cell 3'),
        ],
        [
          DocTableCell(text: 'Cell 4'),
          DocTableCell(text: 'Cell 5'),
          DocTableCell(text: 'Cell 6'),
        ],
      ],
    );

    for (int r = 0; r < table.rows.length; r++) {
      for (int c = 0; c < table.rows[r].length; c++) {
        final key = '${tblId}_r${r}_c$c';
        _controllers[key] = TextEditingController(text: table.rows[r][c].text);
      }
    }

    final index = _docModel!.items.indexWhere((e) => e.id == _activeItemId);
    final targetIndex = index >= 0 ? index + 1 : _docModel!.items.length;

    setState(() {
      _docModel!.items.insert(targetIndex, table);
      _activeItemId = tblId;
    });
  }

  Future<void> _insertImage() async {
    if (_docModel == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        _saveSnapshotForUndo();

        final imgId = 'img_${DateTime.now().millisecondsSinceEpoch}';
        final imgItem = DocImageItem(id: imgId, imageBytes: bytes);

        final index = _docModel!.items.indexWhere((e) => e.id == _activeItemId);
        final targetIndex = index >= 0 ? index + 1 : _docModel!.items.length;

        setState(() {
          _docModel!.items.insert(targetIndex, imgItem);
          _activeItemId = imgId;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Error adding image: $e')),
        );
      }
    }
  }

  void _insertPageBreak() {
    if (_docModel == null) return;
    _saveSnapshotForUndo();

    final pbId = 'pb_${DateTime.now().millisecondsSinceEpoch}';
    final pb = DocPageBreakItem(id: pbId);

    final index = _docModel!.items.indexWhere((e) => e.id == _activeItemId);
    final targetIndex = index >= 0 ? index + 1 : _docModel!.items.length;

    setState(() {
      _docModel!.items.insert(targetIndex, pb);
      _activeItemId = pbId;
    });
  }

  void _deleteActiveItem() {
    if (_docModel == null ||
        _activeItemId == null ||
        _docModel!.items.length <= 1) {
      return;
    }
    _saveSnapshotForUndo();

    setState(() {
      _docModel!.items.removeWhere((e) => e.id == _activeItemId);
      _activeItemId = _docModel!.items.first.id;
    });
  }

  void _showPropertiesSheet() {
    final activeP = _activeParagraph;
    if (activeP == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Paragraph Properties',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_docModel!.items.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteActiveItem();
                        },
                      ),
                  ],
                ),
                const Divider(height: 24),
                // Heading Style
                Text('Style:',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: activeP.headingStyle,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'normal', child: Text('Normal Text')),
                    DropdownMenuItem(
                        value: 'title', child: Text('Document Title')),
                    DropdownMenuItem(
                        value: 'heading1', child: Text('Heading 1')),
                    DropdownMenuItem(
                        value: 'heading2', child: Text('Heading 2')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _setHeadingStyle(val);
                      setSheetState(() {});
                    }
                  },
                ),
                const SizedBox(height: 14),
                // Font Size
                Row(
                  children: [
                    Text('Size: ${activeP.fontSize.toInt()}pt',
                        style: GoogleFonts.inter(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: activeP.fontSize,
                        min: 9,
                        max: 36,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          _saveSnapshotForUndo();
                          setState(() => activeP.fontSize = val);
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                // Formatting Chips (Bold, Italic, Underline)
                Row(
                  children: [
                    FilterChip(
                      label: const Text('B',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      selected: activeP.isBold,
                      selectedColor: AppColors.secondary,
                      checkmarkColor: AppColors.primary,
                      onSelected: (v) {
                        _toggleBold();
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('I',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                      selected: activeP.isItalic,
                      selectedColor: AppColors.secondary,
                      checkmarkColor: AppColors.primary,
                      onSelected: (v) {
                        _toggleItalic();
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('U',
                          style:
                              TextStyle(decoration: TextDecoration.underline)),
                      selected: activeP.isUnderline,
                      selectedColor: AppColors.secondary,
                      checkmarkColor: AppColors.primary,
                      onSelected: (v) {
                        _toggleUnderline();
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Text Alignment
                Row(
                  children: [
                    Text('Align:',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.format_align_left_rounded),
                      color: activeP.alignment == TextAlign.left
                          ? AppColors.primary
                          : Colors.grey,
                      onPressed: () {
                        _setAlignment(TextAlign.left);
                        setSheetState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_align_center_rounded),
                      color: activeP.alignment == TextAlign.center
                          ? AppColors.primary
                          : Colors.grey,
                      onPressed: () {
                        _setAlignment(TextAlign.center);
                        setSheetState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_align_right_rounded),
                      color: activeP.alignment == TextAlign.right
                          ? AppColors.primary
                          : Colors.grey,
                      onPressed: () {
                        _setAlignment(TextAlign.right);
                        setSheetState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_align_justify_rounded),
                      color: activeP.alignment == TextAlign.justify
                          ? AppColors.primary
                          : Colors.grey,
                      onPressed: () {
                        _setAlignment(TextAlign.justify);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Color Picker
                Row(
                  children: [
                    Text('Color:',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    ...[
                      Colors.black,
                      const Color(0xFFF23882),
                      const Color(0xFF1E88E5),
                      const Color(0xFFE53935),
                      const Color(0xFF43A047),
                      const Color(0xFFFB8C00),
                    ].map((c) {
                      final isSel = activeP.color == c;
                      return GestureDetector(
                        onTap: () {
                          _saveSnapshotForUndo();
                          setState(() => activeP.color = c);
                          setSheetState(() {});
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                              width: isSel ? 2.5 : 1,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 20),
                GradientButton(
                  text: 'Apply Changes',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportAsPdf() async {
    if (_docModel == null) return;
    _syncTextFromControllers();

    setState(() {
      _isLoading = true;
      _loadingStatus = 'Exporting document to formatted A4 PDF...';
    });

    try {
      final model = await _editorService.exportAsPdf(
        items: _docModel!.items,
        documentTitle: _docModel!.title,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        _showSuccessSheet(
          title: 'Exported as PDF!',
          filePath: model.path,
          fileSize: model.formattedSize,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _saveDocx() async {
    if (_docModel == null) return;
    _syncTextFromControllers();

    setState(() {
      _isLoading = true;
      _loadingStatus = 'Packaging Word Document (.docx)...';
    });

    try {
      final file = await _editorService.saveAsDocx(
        items: _docModel!.items,
        originalPath: _docModel!.originalPath,
        rawArchiveBytes: _docModel!.rawArchiveBytes,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        final stat = await file.stat();
        _showSuccessSheet(
          title: 'Saved as Word Document (.docx)!',
          filePath: file.path,
          fileSize: FileUtils.formatBytes(stat.size),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Saving failed: $e')),
        );
      }
    }
  }

  Future<void> _saveTxt() async {
    if (_docModel == null) return;
    _syncTextFromControllers();

    setState(() {
      _isLoading = true;
      _loadingStatus = 'Saving Plain Text (.txt)...';
    });

    try {
      final file = await _editorService.saveAsTxt(
        items: _docModel!.items,
        originalPath: _docModel!.originalPath,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        final stat = await file.stat();
        _showSuccessSheet(
          title: 'Saved as Text (.txt)!',
          filePath: file.path,
          fileSize: FileUtils.formatBytes(stat.size),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Saving failed: $e')),
        );
      }
    }
  }

  void _showSuccessSheet({
    required String title,
    required String filePath,
    required String fileSize,
  }) {
    final isPdf = filePath.toLowerCase().endsWith('.pdf');

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
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Size: $fileSize',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isPdf) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditPdfScreen(initialFile: File(filePath)),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text('Open in Edit PDF Studio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final dlPath =
                          await FileService().downloadFileToDevice(filePath);
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
                      ShareService.openFile(filePath);
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
                      ShareService.shareFile(filePath);
                    },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isPdf ? AppColors.secondary : AppColors.primary,
                      foregroundColor:
                          isPdf ? AppColors.primary : Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEBF1), // Neutral desktop paper desk
      appBar: AppBar(
        title: Text(
          _docModel == null ? 'Document Editor' : _docModel!.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_docModel != null) ...[
            IconButton(
              icon: Icon(
                _showPageStrip
                    ? Icons.view_carousel_rounded
                    : Icons.view_carousel_outlined,
                color:
                    _showPageStrip ? AppColors.primary : Colors.grey.shade600,
              ),
              tooltip: 'Toggle Page Navigation Strip',
              onPressed: () => setState(() => _showPageStrip = !_showPageStrip),
            ),
            IconButton(
              icon: Icon(
                  _isSearching ? Icons.close_rounded : Icons.search_rounded,
                  color: AppColors.primary),
              tooltip: 'Search Document',
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Undo',
              color: _undoStack.isNotEmpty
                  ? AppColors.primary
                  : Colors.grey.shade400,
              onPressed: _undoStack.isNotEmpty ? _undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              tooltip: 'Redo',
              color: _redoStack.isNotEmpty
                  ? AppColors.primary
                  : Colors.grey.shade400,
              onPressed: _redoStack.isNotEmpty ? _redo : null,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.save_rounded,
                  color: AppColors.primary, size: 26),
              tooltip: 'Save Options',
              onSelected: (val) {
                if (val == 'docx') _saveDocx();
                if (val == 'pdf') _exportAsPdf();
                if (val == 'txt') _saveTxt();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'docx',
                  child: Row(
                    children: [
                      Icon(Icons.description_rounded,
                          color: Colors.blue, size: 20),
                      SizedBox(width: 10),
                      Text('Save as Word (.docx)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded,
                          color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Text('Export as PDF'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'txt',
                  child: Row(
                    children: [
                      Icon(Icons.article_outlined,
                          color: Colors.grey, size: 20),
                      SizedBox(width: 10),
                      Text('Save as Plain Text (.txt)'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(_loadingStatus,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            )
          : _docModel == null
              ? _buildPickerScreen()
              : _buildA4Workspace(),
    );
  }

  Widget _buildPickerScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_document,
                      color: AppColors.primary, size: 40),
                ),
                const SizedBox(height: 18),
                Text(
                  'A4 Word Document Editor',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Displays authentic A4 page sheets preserving headings, paragraphs, tables, and images with in-place text editing.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Open Existing Document',
                  icon: Icons.folder_open_rounded,
                  onPressed: _pickFile,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _createNewBlankA4Doc,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text('Create Blank A4 Document'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageNavStrip() {
    int pageCount = 1;
    if (_docModel != null) {
      pageCount = _docModel!.items.whereType<DocPageBreakItem>().length + 1;
    }

    return Container(
      height: 48,
      color: AppColors.background,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: pageCount,
        itemBuilder: (context, idx) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Page ${idx + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildA4Workspace() {
    return Column(
      children: [
        // Collapsible Page Strip
        if (_showPageStrip) _buildPageNavStrip(),

        // Search Bar if open
        if (_isSearching)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search words in document...',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.primary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        }),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

        // Professional Word Formatting Toolbar
        _buildWordToolbar(),

        // Document Workspace (Vertical Scrolling A4 Sheets)
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 2.5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: _buildA4PageSheets(),
              ),
            ),
          ),
        ),

        // Bottom Stats & Zoom bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_docModel!.wordCount} Words • ${_docModel!.items.length} Elements',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_out, size: 18),
                    onPressed: () => _setZoom(_zoomLevel - 0.15),
                    tooltip: 'Zoom out',
                  ),
                  Text('${(_zoomLevel * 100).toInt()}%',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.zoom_in, size: 18),
                    onPressed: () => _setZoom(_zoomLevel + 0.15),
                    tooltip: 'Zoom in',
                  ),
                  IconButton(
                    icon: const Icon(Icons.fit_screen_rounded, size: 18),
                    onPressed: () => _setZoom(1.0),
                    tooltip: 'Reset Zoom',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWordToolbar() {
    final activeP = _activeParagraph;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Style Selector (Normal, Title, H1, H2)
            DropdownButton<String>(
              value: activeP?.headingStyle ?? 'normal',
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal Text')),
                DropdownMenuItem(value: 'title', child: Text('Document Title')),
                DropdownMenuItem(value: 'heading1', child: Text('Heading 1')),
                DropdownMenuItem(value: 'heading2', child: Text('Heading 2')),
              ],
              onChanged: (val) {
                if (val != null) _setHeadingStyle(val);
              },
            ),
            const VerticalDivider(width: 16, thickness: 1),

            // Bold
            _buildToolbarBtn(
              icon: Icons.format_bold_rounded,
              isActive: activeP?.isBold ?? false,
              onTap: _toggleBold,
              tooltip: 'Bold',
            ),
            // Italic
            _buildToolbarBtn(
              icon: Icons.format_italic_rounded,
              isActive: activeP?.isItalic ?? false,
              onTap: _toggleItalic,
              tooltip: 'Italic',
            ),
            // Underline
            _buildToolbarBtn(
              icon: Icons.format_underlined_rounded,
              isActive: activeP?.isUnderline ?? false,
              onTap: _toggleUnderline,
              tooltip: 'Underline',
            ),
            const VerticalDivider(width: 16, thickness: 1),

            // Font size controls
            IconButton(
              icon: const Icon(Icons.remove, size: 16),
              onPressed: () => _changeFontSize(-1),
              tooltip: 'Decrease size',
            ),
            Text(
              '${(activeP?.fontSize ?? 13).toInt()} pt',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              onPressed: () => _changeFontSize(1),
              tooltip: 'Increase size',
            ),
            const VerticalDivider(width: 16, thickness: 1),

            // Alignment
            _buildToolbarBtn(
              icon: Icons.format_align_left_rounded,
              isActive:
                  (activeP?.alignment ?? TextAlign.left) == TextAlign.left,
              onTap: () => _setAlignment(TextAlign.left),
              tooltip: 'Align Left',
            ),
            _buildToolbarBtn(
              icon: Icons.format_align_center_rounded,
              isActive:
                  (activeP?.alignment ?? TextAlign.left) == TextAlign.center,
              onTap: () => _setAlignment(TextAlign.center),
              tooltip: 'Align Center',
            ),
            _buildToolbarBtn(
              icon: Icons.format_align_right_rounded,
              isActive:
                  (activeP?.alignment ?? TextAlign.left) == TextAlign.right,
              onTap: () => _setAlignment(TextAlign.right),
              tooltip: 'Align Right',
            ),
            _buildToolbarBtn(
              icon: Icons.format_align_justify_rounded,
              isActive:
                  (activeP?.alignment ?? TextAlign.left) == TextAlign.justify,
              onTap: () => _setAlignment(TextAlign.justify),
              tooltip: 'Justify',
            ),
            const VerticalDivider(width: 16, thickness: 1),

            // Insert tools
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: AppColors.primary),
              label: const Text('Paragraph'),
              backgroundColor: AppColors.secondary,
              onPressed: _insertParagraphAfterActive,
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.table_chart_outlined,
                  size: 16, color: AppColors.primary),
              label: const Text('Table'),
              backgroundColor: AppColors.secondary,
              onPressed: _insertTable,
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.image_outlined,
                  size: 16, color: AppColors.primary),
              label: const Text('Image'),
              backgroundColor: AppColors.secondary,
              onPressed: _insertImage,
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.insert_page_break_rounded,
                  size: 16, color: AppColors.primary),
              label: const Text('Page Break'),
              backgroundColor: AppColors.secondary,
              onPressed: _insertPageBreak,
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.tune_rounded,
                  size: 16, color: AppColors.primary),
              label: const Text('Properties'),
              backgroundColor: AppColors.secondary,
              onPressed: _showPropertiesSheet,
            ),
            const SizedBox(width: 6),
            if (_docModel != null && _docModel!.items.length > 1)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 20),
                tooltip: 'Delete active element',
                onPressed: _deleteActiveItem,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildA4PageSheets() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Standard A4 aspect ratio 1 : 1.414 (width = ~650 dp, height = ~920 dp)
        final double a4Width =
            (constraints.maxWidth * 0.98).clamp(320.0, 750.0);
        final double a4MinHeight = a4Width * 1.414;

        // Group items by page break
        final List<List<DocItem>> pages = [];
        List<DocItem> currentPage = [];

        for (final item in _docModel!.items) {
          if (item is DocPageBreakItem) {
            if (currentPage.isNotEmpty) {
              pages.add(currentPage);
              currentPage = [];
            }
          } else {
            currentPage.add(item);
          }
        }
        if (currentPage.isNotEmpty) {
          pages.add(currentPage);
        }
        if (pages.isEmpty) {
          pages.add([]);
        }

        return Column(
          children: List.generate(pages.length, (pageIndex) {
            final pageItems = pages[pageIndex];

            return Container(
              margin: const EdgeInsets.only(bottom: 32),
              width: a4Width,
              constraints: BoxConstraints(minHeight: a4MinHeight),
              padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 52),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _docModel!.title,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        'Page ${pageIndex + 1} of ${pages.length}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 0.5),

                  // Page Items (Headings, Paragraphs, Tables, Images)
                  ...pageItems.map((item) => _buildPageItem(item)),

                  const SizedBox(height: 30),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPageItem(DocItem item) {
    final isSelected = _activeItemId == item.id;

    if (item is DocImageItem) {
      return GestureDetector(
        onTap: () => setState(() => _activeItemId = item.id),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          alignment: item.alignment == TextAlign.center
              ? Alignment.center
              : (item.alignment == TextAlign.right
                  ? Alignment.centerRight
                  : Alignment.centerLeft),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              item.imageBytes,
              width: item.width,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    if (item is DocTableItem) {
      return GestureDetector(
        onTap: () => setState(() => _activeItemId = item.id),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade400,
                width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: List.generate(item.rows.length, (r) {
              final row = item.rows[r];
              return TableRow(
                decoration: BoxDecoration(
                  color: r == 0 && row.any((c) => c.isHeader)
                      ? Colors.grey.shade100
                      : Colors.white,
                ),
                children: List.generate(row.length, (c) {
                  final cell = row[c];
                  final key = '${item.id}_r${r}_c$c';
                  final controller = _controllers[key];

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      textAlign: cell.alignment,
                      style: TextStyle(
                        fontSize: cell.isHeader ? 12 : 11,
                        fontWeight:
                            cell.isHeader ? FontWeight.bold : FontWeight.normal,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onTap: () => setState(() => _activeItemId = item.id),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      );
    }

    if (item is DocParagraphItem) {
      final controller = _controllers[item.id];
      bool matchesSearch = false;
      if (_searchQuery.isNotEmpty &&
          item.text.toLowerCase().contains(_searchQuery)) {
        matchesSearch = true;
      }

      final double bottomSpacing = item.headingStyle == 'title'
          ? 18.0
          : (item.headingStyle.startsWith('heading') ? 14.0 : 10.0);

      return GestureDetector(
        onTap: () => setState(() => _activeItemId = item.id),
        child: Container(
          margin: EdgeInsets.only(bottom: bottomSpacing),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: matchesSearch
                ? Colors.amber.shade100
                : (isSelected
                    ? AppColors.secondary.withValues(alpha: 0.3)
                    : Colors.transparent),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : (matchesSearch ? Border.all(color: Colors.amber) : null),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: controller,
            maxLines: null,
            textAlign: item.alignment,
            style: TextStyle(
              fontSize: item.fontSize,
              fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: item.isUnderline
                  ? TextDecoration.underline
                  : TextDecoration.none,
              color: item.color,
              height: item.headingStyle == 'title' ? 1.2 : 1.45,
            ),
            decoration: InputDecoration(
              hintText: item.headingStyle == 'title'
                  ? 'Document Title...'
                  : (item.headingStyle.startsWith('heading')
                      ? 'Heading...'
                      : 'Type paragraph text here...'),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onTap: () => setState(() => _activeItemId = item.id),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildToolbarBtn({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, size: 19),
      color: isActive ? AppColors.primary : AppColors.textSecondary,
      style: IconButton.styleFrom(
        backgroundColor: isActive ? AppColors.secondary : Colors.transparent,
      ),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

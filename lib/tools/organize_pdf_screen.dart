import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_organize_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class OrganizePdfScreen extends StatefulWidget {
  final File? initialFile;

  const OrganizePdfScreen({super.key, this.initialFile});

  @override
  State<OrganizePdfScreen> createState() => _OrganizePdfScreenState();
}

class _OrganizePdfScreenState extends State<OrganizePdfScreen> {
  File? _selectedFile;
  List<int> _pageOrder = []; // 1-based page numbers
  final Set<int> _deletedPages = {};
  final Map<int, int> _pageRotations = {}; // page -> angle (0, 90, 180, 270)
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
      _pageOrder = List.generate(info.pageCount, (i) => i + 1);
      _deletedPages.clear();
      _pageRotations.clear();
      _outputNameController.text =
          'Organized_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  void _rotatePage(int page) {
    setState(() {
      final current = _pageRotations[page] ?? 0;
      _pageRotations[page] = (current + 90) % 360;
    });
  }

  void _toggleDeletePage(int page) {
    setState(() {
      if (_deletedPages.contains(page)) {
        _deletedPages.remove(page);
      } else {
        if (_deletedPages.length + 1 >= _pageOrder.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Cannot delete all pages from document.')),
          );
          return;
        }
        _deletedPages.add(page);
      }
    });
  }

  Future<void> _processOrganize() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfOrganizeService().organizePdf(
        filePath: _selectedFile!.path,
        newPageOrder: _pageOrder,
        pagesToDelete: _deletedPages.toList(),
        pageRotations: _pageRotations,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.showSuccess(
        context: context,
        title: 'PDF Organized Successfully!',
        filePath: resultModel.path,
        subtitle: '${resultModel.name} (${resultModel.pageCount} pages)',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Error organizing PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organize PDF'),
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
                      child: const Icon(Icons.view_comfortable_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Visually Organize Pages',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reorder, rotate individual pages, or delete unneeded pages visually before saving.',
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
          : Column(
              children: [
                // File summary bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_selectedFile!.path.split(Platform.pathSeparator).last} (${_pageOrder.length - _deletedPages.length} active pages)',
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                          onPressed: _pickFile, child: const Text('Change')),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Instruction hint
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tap ↻ to rotate, 🗑 to delete/restore',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                      Text(
                        'Hold & drag to reorder',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Reorderable Grid of Pages
                Expanded(
                  child: ReorderableListView(
                    padding: const EdgeInsets.all(16),
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final item = _pageOrder.removeAt(oldIndex);
                        _pageOrder.insert(newIndex, item);
                      });
                    },
                    children: [
                      for (int i = 0; i < _pageOrder.length; i++)
                        _buildPageTile(i, _pageOrder[i]),
                    ],
                  ),
                ),

                // Bottom Action
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(top: BorderSide(color: AppColors.cardBorder)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _outputNameController,
                          decoration: const InputDecoration(
                            labelText: 'Output File Name',
                            prefixIcon: Icon(Icons.edit_outlined,
                                color: AppColors.primary, size: 20),
                            suffixText: '.pdf',
                          ),
                        ),
                        const SizedBox(height: 12),
                        GradientButton(
                          text:
                              'Save Reorganized PDF (${_pageOrder.length - _deletedPages.length} Pages)',
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: _isProcessing,
                          onPressed: _processOrganize,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPageTile(int index, int pageNumber) {
    final isDeleted = _deletedPages.contains(pageNumber);
    final rotation = _pageRotations[pageNumber] ?? 0;

    return Container(
      key: ValueKey('page_$pageNumber'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDeleted ? AppColors.errorLight : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDeleted ? AppColors.error : AppColors.cardBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator_rounded,
                color: AppColors.textTertiary),
          ),
          const SizedBox(width: 12),

          // Page thumbnail box
          RotatedBox(
            quarterTurns: rotation ~/ 90,
            child: Container(
              width: 36,
              height: 48,
              decoration: BoxDecoration(
                color: isDeleted ? Colors.grey.shade300 : AppColors.secondary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.secondaryBorder),
              ),
              child: Center(
                child: Text(
                  '$pageNumber',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDeleted ? Colors.grey : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Page details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Page $pageNumber ${isDeleted ? "(Marked for Deletion)" : ""}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                    color: isDeleted ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Position: #${index + 1} • Rotation: $rotation°',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),

          // Actions: Rotate & Delete
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded,
                color: AppColors.primary, size: 22),
            tooltip: 'Rotate 90°',
            onPressed: isDeleted ? null : () => _rotatePage(pageNumber),
          ),
          IconButton(
            icon: Icon(
              isDeleted ? Icons.restore_rounded : Icons.delete_outline_rounded,
              color: isDeleted ? AppColors.success : AppColors.error,
              size: 22,
            ),
            tooltip: isDeleted ? 'Restore Page' : 'Delete Page',
            onPressed: () => _toggleDeletePage(pageNumber),
          ),
        ],
      ),
    );
  }
}

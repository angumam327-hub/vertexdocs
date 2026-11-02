import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pdf_file_model.dart';
import '../screens/pdf_preview_screen.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';

class MergePdfScreen extends StatefulWidget {
  final List<File>? initialFiles;

  const MergePdfScreen({super.key, this.initialFiles});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<File> _selectedFiles = [];
  final TextEditingController _outputNameController = TextEditingController(
    text: 'Merged_Document',
  );
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
      _selectedFiles.addAll(widget.initialFiles!);
    }
  }

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  Future<void> _pickMoreFiles() async {
    final files = await FileService().pickMultiplePdfs();
    if (files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(files);
      });
    }
  }

  Future<void> _processMerge() async {
    if (_selectedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least 2 PDF files to merge.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final paths = _selectedFiles.map((f) => f.path).toList();
      final resultModel = await PdfService().mergePdfs(
        filePaths: paths,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      _showSuccessDialog(resultModel);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Error merging PDFs: $e'),
        ),
      );
    }
  }

  void _showSuccessDialog(PdfFileModel result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'PDFs Merged Successfully!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${result.name} (${result.formattedSize})',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Preview PDF',
              icon: Icons.visibility_outlined,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfPreviewScreen(
                      filePath: result.path,
                      title: result.name,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                    onPressed: () {
                      ShareService.shareFile(result.path);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open External'),
                    onPressed: () {
                      ShareService.openFile(result.path);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDF'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.primary),
              tooltip: 'Add More PDFs',
              onPressed: _pickMoreFiles,
            ),
        ],
      ),
      body: _selectedFiles.isEmpty
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
                      child: const Icon(
                        Icons.call_merge_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Combine Multiple PDFs',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select two or more PDF documents to merge into a single, beautifully organized file.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Select PDF Files',
                      icon: Icons.add_circle_outline,
                      onPressed: _pickMoreFiles,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Files to Merge (${_selectedFiles.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Drag ☰ to reorder',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _selectedFiles.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final item = _selectedFiles.removeAt(oldIndex);
                        _selectedFiles.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      final name = file.path.split(Platform.pathSeparator).last;
                      final size = file.existsSync() ? file.lengthSync() : 0;

                      return Container(
                        key: ValueKey(file.path),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.secondary,
                            radius: 16,
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            FileUtils.formatBytes(size),
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.textTertiary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 20, color: AppColors.error),
                                onPressed: () {
                                  setState(() {
                                    _selectedFiles.removeAt(index);
                                  });
                                },
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle_rounded,
                                    color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        const SizedBox(height: 14),
                        GradientButton(
                          text: 'Merge ${_selectedFiles.length} PDFs',
                          icon: Icons.call_merge_rounded,
                          isLoading: _isProcessing,
                          onPressed:
                              _selectedFiles.length >= 2 ? _processMerge : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

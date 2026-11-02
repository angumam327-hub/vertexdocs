import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_organize_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class RemovePagesScreen extends StatefulWidget {
  final File? initialFile;

  const RemovePagesScreen({super.key, this.initialFile});

  @override
  State<RemovePagesScreen> createState() => _RemovePagesScreenState();
}

class _RemovePagesScreenState extends State<RemovePagesScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  final Set<int> _pagesToRemove = {};
  bool _isProcessing = false;
  final TextEditingController _inputPagesController = TextEditingController();
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
    _inputPagesController.dispose();
    _outputNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPdf(File file) async {
    setState(() => _selectedFile = file);
    final info = await PdfService().getPdfInfo(file.path);
    if (!mounted) return;

    setState(() {
      _pdfInfo = info;
      _pagesToRemove.clear();
      _outputNameController.text =
          'PagesRemoved_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  void _parseRangeInput(String text) {
    final parts = text.split(',');
    final newSet = <int>{};
    final maxP = _pdfInfo?.pageCount ?? 9999;

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final bounds = trimmed.split('-');
        if (bounds.length == 2) {
          final start = int.tryParse(bounds[0].trim());
          final end = int.tryParse(bounds[1].trim());
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              if (i >= 1 && i <= maxP) newSet.add(i);
            }
          }
        }
      } else {
        final num = int.tryParse(trimmed);
        if (num != null && num >= 1 && num <= maxP) {
          newSet.add(num);
        }
      }
    }

    setState(() {
      _pagesToRemove.clear();
      _pagesToRemove.addAll(newSet);
    });
  }

  Future<void> _processRemove() async {
    if (_selectedFile == null || _pagesToRemove.isEmpty) return;

    if (_pagesToRemove.length >= (_pdfInfo?.pageCount ?? 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove all pages from the PDF.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfOrganizeService().removePages(
        filePath: _selectedFile!.path,
        pagesToRemove: _pagesToRemove.toList()..sort(),
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.showSuccess(
        context: context,
        title: 'Pages Removed Successfully!',
        filePath: resultModel.path,
        subtitle:
            'Removed ${_pagesToRemove.length} pages (${resultModel.pageCount} remaining)',
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
    final totalPages = _pdfInfo?.pageCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remove PDF Pages'),
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
                      child: const Icon(Icons.delete_sweep_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Delete Unwanted Pages',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select the pages you want to delete and generate a clean PDF without them.',
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
                // File info header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.path
                                  .split(Platform.pathSeparator)
                                  .last,
                              style: GoogleFonts.poppins(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$totalPages Pages • ${_pagesToRemove.length} marked to delete',
                              style: GoogleFonts.inter(
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
                const Divider(height: 1),

                // Quick Selection Chips & Text input
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ActionChip(
                            label: const Text('Even Pages'),
                            onPressed: () {
                              setState(() {
                                for (int i = 2; i <= totalPages; i += 2) {
                                  _pagesToRemove.add(i);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('Odd Pages'),
                            onPressed: () {
                              setState(() {
                                for (int i = 1; i <= totalPages; i += 2) {
                                  _pagesToRemove.add(i);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('Clear All'),
                            onPressed: () =>
                                setState(() => _pagesToRemove.clear()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _inputPagesController,
                        decoration: InputDecoration(
                          hintText: 'Enter pages to delete e.g. 1, 3, 5-8',
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_rounded,
                                color: AppColors.primary),
                            onPressed: () =>
                                _parseRangeInput(_inputPagesController.text),
                          ),
                        ),
                        onSubmitted: _parseRangeInput,
                      ),
                    ],
                  ),
                ),

                // Grid of Pages
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: totalPages,
                    itemBuilder: (ctx, index) {
                      final page = index + 1;
                      final isSelected = _pagesToRemove.contains(page);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _pagesToRemove.remove(page);
                            } else {
                              _pagesToRemove.add(page);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.errorLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.error
                                  : AppColors.cardBorder,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 28,
                                    color: isSelected
                                        ? AppColors.error
                                        : AppColors.textTertiary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$page',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isSelected
                                          ? AppColors.error
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected)
                                const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(Icons.cancel,
                                      color: AppColors.error, size: 18),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom button
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
                              'Delete ${_pagesToRemove.length} Pages & Save PDF',
                          icon: Icons.delete_sweep_rounded,
                          isLoading: _isProcessing,
                          onPressed:
                              _pagesToRemove.isNotEmpty ? _processRemove : null,
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

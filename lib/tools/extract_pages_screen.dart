import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_organize_service.dart';
import '../services/pdf_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class ExtractPagesScreen extends StatefulWidget {
  final File? initialFile;

  const ExtractPagesScreen({super.key, this.initialFile});

  @override
  State<ExtractPagesScreen> createState() => _ExtractPagesScreenState();
}

class _ExtractPagesScreenState extends State<ExtractPagesScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  final Set<int> _pagesToExtract = {};
  bool _splitIntoSeparateFiles = false;
  bool _isProcessing = false;
  final TextEditingController _rangeController = TextEditingController();
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
    _rangeController.dispose();
    _outputNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPdf(File file) async {
    setState(() => _selectedFile = file);
    final info = await PdfService().getPdfInfo(file.path);
    if (!mounted) return;

    setState(() {
      _pdfInfo = info;
      _pagesToExtract.clear();
      _outputNameController.text =
          'Extracted_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
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
      _pagesToExtract.clear();
      _pagesToExtract.addAll(newSet);
    });
  }

  Future<void> _processExtract() async {
    if (_selectedFile == null || _pagesToExtract.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final results = await PdfOrganizeService().extractPages(
        filePath: _selectedFile!.path,
        pagesToExtract: _pagesToExtract.toList()..sort(),
        splitIntoSeparateFiles: _splitIntoSeparateFiles,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (results.length == 1) {
        ToolResultModal.showSuccess(
          context: context,
          title: 'Pages Extracted Successfully!',
          filePath: results.first.path,
          subtitle: '${results.first.name} (${results.first.pageCount} pages)',
        );
      } else {
        // Multiple files extracted
        showModalBottomSheet(
          context: context,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Extracted ${results.length} Separate PDFs',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  text: 'Share All (${results.length} Files)',
                  icon: Icons.share_outlined,
                  onPressed: () {
                    ShareService.shareMultipleFiles(
                        results.map((r) => r.path).toList());
                  },
                ),
              ],
            ),
          ),
        );
      }
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
        title: const Text('Extract PDF Pages'),
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
                      child: const Icon(Icons.file_download_outlined,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Extract Specific Pages',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose specific pages from your document to pull out into a brand new PDF.',
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
                              '$totalPages Pages • ${_pagesToExtract.length} selected to extract',
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

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: TextField(
                    controller: _rangeController,
                    decoration: InputDecoration(
                      hintText: 'Enter pages e.g. 1, 3, 5-7',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_rounded,
                            color: AppColors.primary),
                        onPressed: () =>
                            _parseRangeInput(_rangeController.text),
                      ),
                    ),
                    onSubmitted: _parseRangeInput,
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
                      final isSelected = _pagesToExtract.contains(page);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _pagesToExtract.remove(page);
                            } else {
                              _pagesToExtract.add(page);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.secondaryLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
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
                                    Icons.description_rounded,
                                    size: 28,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textTertiary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$page',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected)
                                const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(Icons.check_circle,
                                      color: AppColors.primary, size: 18),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Options
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Save each page as a separate PDF',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    value: _splitIntoSeparateFiles,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) =>
                        setState(() => _splitIntoSeparateFiles = val),
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
                        if (!_splitIntoSeparateFiles) ...[
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
                        ],
                        GradientButton(
                          text: 'Extract ${_pagesToExtract.length} Pages',
                          icon: Icons.file_download_outlined,
                          isLoading: _isProcessing,
                          onPressed: _pagesToExtract.isNotEmpty
                              ? _processExtract
                              : null,
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

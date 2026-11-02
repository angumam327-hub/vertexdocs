import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/file_service.dart';
import '../services/pdf_organize_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class PageNumbersScreen extends StatefulWidget {
  final File? initialFile;

  const PageNumbersScreen({super.key, this.initialFile});

  @override
  State<PageNumbersScreen> createState() => _PageNumbersScreenState();
}

class _PageNumbersScreenState extends State<PageNumbersScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  String _position =
      'bottom_right'; // 'bottom_center', 'bottom_left', 'top_right', etc.
  String _format = 'Page {n} of {total}';
  final int _startNumber = 1;
  double _fontSize = 10;
  bool _isProcessing = false;
  final TextEditingController _outputNameController = TextEditingController();

  final List<String> _formats = const [
    'Page {n} of {total}',
    '{n}',
    '- {n} -',
    '{n} / {total}',
  ];

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
      _pdfInfo = info;
      _outputNameController.text =
          'Numbered_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processNumbering() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfOrganizeService().addPageNumbers(
        filePath: _selectedFile!.path,
        position: _position,
        format: _format,
        startNumber: _startNumber,
        fontSize: _fontSize,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.showSuccess(
        context: context,
        title: 'Page Numbers Added!',
        filePath: resultModel.path,
        subtitle: '${resultModel.name} (${resultModel.pageCount} pages)',
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
        title: const Text('Page Numbers'),
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
                      child: const Icon(Icons.format_list_numbered_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Insert Page Numbers',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stamp page numbering headers or footers with customizable positions and format.',
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 14),
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
                                '${_pdfInfo?.pageCount ?? 0} Pages • ${FileUtils.formatBytes(_selectedFile!.lengthSync())}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                            onPressed: _pickFile, child: const Text('Change')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mini preview container
                  Center(
                    child: Container(
                      width: 160,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.cardBorder, width: 2),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: _position.contains('top') ? 8 : null,
                            bottom: _position.contains('bottom') ? 8 : null,
                            left: _position.contains('left')
                                ? 8
                                : (_position.contains('center') ? 0 : null),
                            right: _position.contains('right')
                                ? 8
                                : (_position.contains('center') ? 0 : null),
                            child: Center(
                              child: Text(
                                _format.replaceAll('{n}', '1').replaceAll(
                                    '{total}', '${_pdfInfo?.pageCount ?? 5}'),
                                style: GoogleFonts.inter(
                                  fontSize: _fontSize,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Icon(Icons.description_outlined,
                                size: 48, color: Colors.grey.shade300),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Position Selector Grid
                  Text('Position on Page',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildPosButton('top_left', 'Top Left'),
                      const SizedBox(width: 8),
                      _buildPosButton('top_center', 'Top Center'),
                      const SizedBox(width: 8),
                      _buildPosButton('top_right', 'Top Right'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPosButton('bottom_left', 'Bottom Left'),
                      const SizedBox(width: 8),
                      _buildPosButton('bottom_center', 'Bottom Center'),
                      const SizedBox(width: 8),
                      _buildPosButton('bottom_right', 'Bottom Right'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Numbering Format
                  Text('Numbering Style',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _formats.map((fmt) {
                      final isSel = _format == fmt;
                      return ChoiceChip(
                        label: Text(fmt
                            .replaceAll('{n}', '1')
                            .replaceAll('{total}', '10')),
                        selected: isSel,
                        selectedColor: AppColors.secondary,
                        onSelected: (val) {
                          if (val) setState(() => _format = fmt);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Font Size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Font Size: ${_fontSize.toInt()} pt',
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Slider(
                    value: _fontSize,
                    min: 8,
                    max: 18,
                    divisions: 10,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.secondary,
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _outputNameController,
                    decoration: const InputDecoration(
                      labelText: 'Output File Name',
                      prefixIcon: Icon(Icons.edit_outlined,
                          color: AppColors.primary, size: 20),
                      suffixText: '.pdf',
                    ),
                  ),
                  const SizedBox(height: 28),

                  GradientButton(
                    text: 'Apply Page Numbers',
                    icon: Icons.format_list_numbered_rounded,
                    isLoading: _isProcessing,
                    onPressed: _processNumbering,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPosButton(String posKey, String label) {
    final isSel = _position == posKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _position = posKey),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.cardBorder,
              width: isSel ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
              color: isSel ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

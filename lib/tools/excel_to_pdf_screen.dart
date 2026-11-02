import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/pdf_conversion_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class ExcelToPdfScreen extends StatefulWidget {
  const ExcelToPdfScreen({super.key});

  @override
  State<ExcelToPdfScreen> createState() => _ExcelToPdfScreenState();
}

class _ExcelToPdfScreenState extends State<ExcelToPdfScreen> {
  File? _selectedFile;
  bool _isProcessing = false;
  final TextEditingController _outputNameController = TextEditingController();

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  Future<void> _pickXlsx() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _selectedFile = file;
        _outputNameController.text = file.path
            .split(Platform.pathSeparator)
            .last
            .replaceAll(RegExp(r'\.xlsx?$', caseSensitive: false), '');
      });
    }
  }

  Future<void> _processConversion() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfConversionService().excelToPdf(
        filePath: _selectedFile!.path,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.showSuccess(
        context: context,
        title: 'Excel Converted to PDF!',
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
        title: const Text('Excel to PDF'),
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
                      child: const Icon(Icons.grid_on_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Convert XLSX to PDF Table',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Transform Excel (.xlsx) spreadsheets into landscape PDF documents formatted with bordered table grids.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Select Excel File (.xlsx)',
                      icon: Icons.file_upload_outlined,
                      onPressed: _pickXlsx,
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
                        const Icon(Icons.table_chart_rounded,
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
                                FileUtils.formatBytes(
                                    _selectedFile!.lengthSync()),
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                            onPressed: _pickXlsx, child: const Text('Change')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _outputNameController,
                    decoration: const InputDecoration(
                      labelText: 'Output PDF Name',
                      prefixIcon: Icon(Icons.edit_outlined,
                          color: AppColors.primary, size: 20),
                      suffixText: '.pdf',
                    ),
                  ),
                  const SizedBox(height: 28),
                  GradientButton(
                    text: 'Convert Excel to PDF Table',
                    icon: Icons.picture_as_pdf_rounded,
                    isLoading: _isProcessing,
                    onPressed: _processConversion,
                  ),
                ],
              ),
            ),
    );
  }
}

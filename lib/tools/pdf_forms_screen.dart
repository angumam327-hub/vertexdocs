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
import 'add_text_screen.dart';

class PdfFormsScreen extends StatefulWidget {
  final File? initialFile;

  const PdfFormsScreen({super.key, this.initialFile});

  @override
  State<PdfFormsScreen> createState() => _PdfFormsScreenState();
}

class _PdfFormsScreenState extends State<PdfFormsScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  bool _isLoadingFields = false;
  bool _isProcessing = false;

  List<FormFieldInfo> _fields = [];
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _checkboxValues = {};
  bool _flattenForm = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPdf(File file) async {
    setState(() {
      _selectedFile = file;
      _isLoadingFields = true;
      _fields = [];
      _textControllers.clear();
      _checkboxValues.clear();
    });

    final info = await PdfService().getPdfInfo(file.path);
    final fields = await PdfEditService().getFormFields(file.path);

    for (final f in fields) {
      if (f.type == 'checkbox') {
        _checkboxValues[f.name] = f.isChecked;
      } else {
        _textControllers[f.name] = TextEditingController(text: f.value);
      }
    }

    if (!mounted) return;
    setState(() {
      _pdfInfo = info;
      _fields = fields;
      _isLoadingFields = false;
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processFillForm() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final fieldMap = <String, dynamic>{};
      for (final entry in _textControllers.entries) {
        fieldMap[entry.key] = entry.value.text;
      }
      for (final entry in _checkboxValues.entries) {
        fieldMap[entry.key] = entry.value;
      }

      final result = await PdfEditService().fillFormFields(
        filePath: _selectedFile!.path,
        fieldValues: fieldMap,
        flattenForm: _flattenForm,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.show(
        context: context,
        result: result,
        toolTitle: 'PDF Forms',
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
        title: const Text('PDF Forms'),
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
                    child: const Icon(Icons.dynamic_form_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fill & Flatten Forms',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Scan interactive AcroForm text fields, check boxes, and export filled PDF contracts.',
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
                        'Select PDF Form Document',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose an application form, tax document, or job contract.',
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
                            '${_pdfInfo?.pageCount ?? 1} pages • ${_fields.length} form fields detected',
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

              if (_isLoadingFields) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ] else if (_fields.isEmpty) ...[
                // No interactive AcroForm fields
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 36),
                      const SizedBox(height: 12),
                      Text(
                        'No AcroForm Fields Detected',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This PDF is a flat document without pre-embedded fillable input boxes. You can overlay custom text directly onto any line using the "Add Text" tool.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    AddTextScreen(initialFile: _selectedFile)),
                          );
                        },
                        icon: const Icon(Icons.text_fields_rounded,
                            color: AppColors.primary),
                        label: Text(
                          'Open Add Text Tool',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // List of detected Form Fields
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Form Fields (${_fields.length})',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Interactive',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _fields.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final f = _fields[index];
                          if (f.type == 'checkbox') {
                            return CheckboxListTile(
                              title: Text(f.name,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              value: _checkboxValues[f.name] ?? false,
                              activeColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setState(() {
                                  _checkboxValues[f.name] = val ?? false;
                                });
                              },
                            );
                          }
                          return TextField(
                            controller: _textControllers[f.name],
                            decoration: InputDecoration(
                              labelText: f.name,
                              hintText: 'Enter ${f.name}...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              isDense: true,
                            ),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Flatten Form After Filling',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Permanently convert form inputs into static page text',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        value: _flattenForm,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _flattenForm = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                GradientButton(
                  text: 'Save Completed Form',
                  icon: Icons.check_circle_rounded,
                  isLoading: _isProcessing,
                  onPressed: _processFillForm,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

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

class RotatePdfScreen extends StatefulWidget {
  final File? initialFile;

  const RotatePdfScreen({super.key, this.initialFile});

  @override
  State<RotatePdfScreen> createState() => _RotatePdfScreenState();
}

class _RotatePdfScreenState extends State<RotatePdfScreen> {
  File? _selectedFile;
  PdfInfo? _pdfInfo;
  int _degrees = 90;
  bool _rotateAllPages = true;
  final TextEditingController _targetPagesController = TextEditingController();
  final TextEditingController _outputNameController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadPdf(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _targetPagesController.dispose();
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
          'Rotated_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file);
    }
  }

  Future<void> _processRotate() async {
    if (_selectedFile == null) return;

    List<int>? pages;
    if (!_rotateAllPages) {
      final text = _targetPagesController.text.trim();
      if (text.isNotEmpty) {
        pages = text
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .where(
                (n) => n != null && n > 0 && n <= (_pdfInfo?.pageCount ?? 9999))
            .cast<int>()
            .toList();
      }
    }

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfService().rotatePdf(
        filePath: _selectedFile!.path,
        degrees: _degrees,
        targetPages: pages,
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
          content: Text('Error rotating PDF: $e'),
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
              'PDF Rotated Successfully!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${result.name} (${result.formattedSize}) • Rotated $_degrees°',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Preview Rotated PDF',
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
                    onPressed: () => ShareService.shareFile(result.path),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open External'),
                    onPressed: () => ShareService.openFile(result.path),
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

  Widget _buildAnglePill(int angle, String label, IconData icon) {
    final isSelected = _degrees == angle;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _degrees = angle),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.cardBorder,
              width: isSelected ? 1.8 : 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotate PDF'),
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
                      child: const Icon(
                        Icons.rotate_right_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Rotate Document Pages',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fix upside down or sideways PDF pages by rotating 90°, 180°, or 270° with a single tap.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded,
                              color: AppColors.primary),
                        ),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_pdfInfo?.pageCount ?? 0} Pages • ${FileUtils.formatBytes(_selectedFile!.lengthSync())}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                            onPressed: _pickFile, child: const Text('Change')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Rotation visual preview
                  Center(
                    child: Container(
                      width: 140,
                      height: 180,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.cardBorder, width: 2),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: RotatedBox(
                        quarterTurns: _degrees ~/ 90,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.description_rounded,
                                size: 48, color: AppColors.primary),
                            const SizedBox(height: 8),
                            Text(
                              'Sample Page',
                              style: GoogleFonts.inter(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Rotation Direction',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildAnglePill(
                          90, '90° Right', Icons.rotate_right_rounded),
                      const SizedBox(width: 10),
                      _buildAnglePill(180, '180° Flip', Icons.sync_rounded),
                      const SizedBox(width: 10),
                      _buildAnglePill(
                          270, '90° Left', Icons.rotate_left_rounded),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Target pages
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Rotate all pages',
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Applies to all ${_pdfInfo?.pageCount ?? 0} pages',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          value: _rotateAllPages,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) =>
                              setState(() => _rotateAllPages = val),
                        ),
                        if (!_rotateAllPages) ...[
                          const Divider(),
                          TextField(
                            controller: _targetPagesController,
                            decoration: InputDecoration(
                              labelText: 'Specific Pages (e.g. 1, 3, 5)',
                              hintText: '1, 2, 4',
                              hintStyle: GoogleFonts.inter(
                                  color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

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
                    text: 'Rotate & Save PDF',
                    icon: Icons.rotate_right_rounded,
                    isLoading: _isProcessing,
                    onPressed: _processRotate,
                  ),
                ],
              ),
            ),
    );
  }
}

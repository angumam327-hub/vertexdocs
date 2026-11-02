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

class UnlockPdfScreen extends StatefulWidget {
  final File? initialFile;

  const UnlockPdfScreen({super.key, this.initialFile});

  @override
  State<UnlockPdfScreen> createState() => _UnlockPdfScreenState();
}

class _UnlockPdfScreenState extends State<UnlockPdfScreen> {
  File? _selectedFile;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _outputNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _selectFile(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _outputNameController.dispose();
    super.dispose();
  }

  void _selectFile(File file) {
    setState(() {
      _selectedFile = file;
      _outputNameController.text =
          'Unlocked_${file.path.split(Platform.pathSeparator).last.replaceAll('.pdf', '')}';
    });
  }

  Future<void> _pickFile() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      _selectFile(file);
    }
  }

  Future<void> _processUnlock() async {
    if (_selectedFile == null) return;

    final pass = _passwordController.text.trim();
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the document password.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final resultModel = await PdfService().unlockPdf(
        filePath: _selectedFile!.path,
        password: pass,
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
          content:
              Text('Failed to unlock: Incorrect password or invalid format.'),
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
              child: const Icon(Icons.lock_open_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'PDF Unlocked Successfully!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${result.name} is now free of encryption and can be opened without a password.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Preview Unlocked PDF',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock PDF'),
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
                        Icons.lock_open_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Remove Password Security',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Provide your valid PDF password once to permanently remove password restrictions and save an unlocked copy.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Select Locked PDF',
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
                          child: const Icon(Icons.lock_rounded,
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
                                FileUtils.formatBytes(
                                    _selectedFile!.lengthSync()),
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

                  // Password field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Enter PDF Password',
                      hintText: 'Current password to decrypt',
                      prefixIcon: const Icon(Icons.key_rounded,
                          color: AppColors.primary, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

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
                    text: 'Unlock & Save Decrypted PDF',
                    icon: Icons.lock_open_rounded,
                    isLoading: _isProcessing,
                    onPressed: _processUnlock,
                  ),
                ],
              ),
            ),
    );
  }
}

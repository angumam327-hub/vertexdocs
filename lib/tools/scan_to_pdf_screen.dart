import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class ScanToPdfScreen extends StatefulWidget {
  const ScanToPdfScreen({super.key});

  @override
  State<ScanToPdfScreen> createState() => _ScanToPdfScreenState();
}

class _ScanToPdfScreenState extends State<ScanToPdfScreen> {
  final List<File> _scannedPages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  final TextEditingController _outputNameController =
      TextEditingController(text: 'Scanned_Doc');

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  Future<void> _captureWithCamera() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (photo != null) {
      setState(() {
        _scannedPages.add(File(photo.path));
      });
    }
  }

  Future<void> _importFromGallery() async {
    final images = await _picker.pickMultiImage(imageQuality: 90);
    if (images.isNotEmpty) {
      setState(() {
        _scannedPages.addAll(images.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _processScanPdf() async {
    if (_scannedPages.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final paths = _scannedPages.map((f) => f.path).toList();
      final resultModel = await PdfService().imagesToPdf(
        imagePaths: paths,
        outputName: _outputNameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.showSuccess(
        context: context,
        title: 'Scan PDF Created!',
        filePath: resultModel.path,
        subtitle: '${resultModel.name} (${_scannedPages.length} scanned pages)',
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
        title: const Text('Scan to PDF'),
        actions: [
          if (_scannedPages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined,
                  color: AppColors.primary),
              tooltip: 'Scan Another Page',
              onPressed: _captureWithCamera,
            ),
        ],
      ),
      body: _scannedPages.isEmpty
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
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Camera Document Scanner',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Snap receipts, contracts, IDs or notes using your camera and combine them into a clean multi-page PDF.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Snap with Camera',
                      icon: Icons.camera_alt_rounded,
                      onPressed: _captureWithCamera,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Import from Gallery'),
                      onPressed: _importFromGallery,
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
                        'Scanned Pages (${_scannedPages.length})',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                        label: const Text('Snap Next Page'),
                        onPressed: _captureWithCamera,
                      ),
                    ],
                  ),
                ),

                // Reorderable list of scan pages
                Expanded(
                  child: ReorderableListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _scannedPages.length,
                    onReorderItem: (oldIdx, newIdx) {
                      setState(() {
                        final item = _scannedPages.removeAt(oldIdx);
                        _scannedPages.insert(newIdx, item);
                      });
                    },
                    itemBuilder: (ctx, index) {
                      final imgFile = _scannedPages[index];
                      return Container(
                        key: ValueKey(imgFile.path),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(imgFile,
                                width: 44, height: 44, fit: BoxFit.cover),
                          ),
                          title: Text('Page ${index + 1}',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: AppColors.error),
                                onPressed: () => setState(
                                    () => _scannedPages.removeAt(index)),
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
                            labelText: 'Output PDF Name',
                            prefixIcon: Icon(Icons.edit_outlined,
                                color: AppColors.primary, size: 20),
                            suffixText: '.pdf',
                          ),
                        ),
                        const SizedBox(height: 12),
                        GradientButton(
                          text: 'Generate PDF (${_scannedPages.length} Pages)',
                          icon: Icons.picture_as_pdf_rounded,
                          isLoading: _isProcessing,
                          onPressed:
                              _scannedPages.isNotEmpty ? _processScanPdf : null,
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

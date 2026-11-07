import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/pdf_preview_screen.dart';
import '../services/compression_service.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/gradient_button.dart';

class SmartCompressorScreen extends StatefulWidget {
  final File? initialFile;

  const SmartCompressorScreen({super.key, this.initialFile});

  @override
  State<SmartCompressorScreen> createState() => _SmartCompressorScreenState();
}

class _SmartCompressorScreenState extends State<SmartCompressorScreen> {
  final CompressionService _compressionService = CompressionService();

  File? _selectedFile;
  int _originalSizeBytes = 0;
  String _fileExtension = '';

  // Step 3: Target size state
  final TextEditingController _targetSizeController =
      TextEditingController(text: '500');
  String _targetUnit = 'KB'; // 'KB' or 'MB'

  bool _isCompressing = false;
  double _progressValue = 0.0;
  String _progressStatus = '';

  CompressionResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _loadFileInfo(widget.initialFile!);
    }
  }

  @override
  void dispose() {
    _targetSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadFileInfo(File file) async {
    final size = await file.length();
    final ext = file.path.split('.').last.toLowerCase();

    // Suggest a smart initial target (~50% of original)
    final halfSizeKb = (size / 1024 / 2).round();
    String defaultInput = '500';
    String defaultUnit = 'KB';

    if (halfSizeKb > 1024) {
      defaultInput = (halfSizeKb / 1024).toStringAsFixed(1);
      defaultUnit = 'MB';
    } else if (halfSizeKb > 50) {
      defaultInput = halfSizeKb.toString();
      defaultUnit = 'KB';
    }

    setState(() {
      _selectedFile = file;
      _originalSizeBytes = size;
      _fileExtension = ext;
      _targetSizeController.text = defaultInput;
      _targetUnit = defaultUnit;
      _result = null;
    });
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'docx',
          'pptx',
          'xlsx'
        ],
        allowMultiple: false,
      );

      if (res != null && res.files.single.path != null) {
        await _loadFileInfo(File(res.files.single.path!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Error choosing file: $e'),
          ),
        );
      }
    }
  }

  int _calculateTargetKb() {
    final val = double.tryParse(_targetSizeController.text.trim()) ?? 500;
    if (_targetUnit == 'MB') {
      return (val * 1024).round().clamp(10, 500 * 1024);
    } else {
      return val.round().clamp(10, 1000 * 1024);
    }
  }

  Future<void> _executeCompression() async {
    if (_selectedFile == null) return;

    final targetKb = _calculateTargetKb();
    if (targetKb <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Please enter a valid target size greater than 0.'),
        ),
      );
      return;
    }

    setState(() {
      _isCompressing = true;
      _progressValue = 0.05;
      _progressStatus = 'Analyzing file structure...';
      _result = null;
    });

    try {
      final res = await _compressionService.compressToTargetSize(
        filePath: _selectedFile!.path,
        targetSizeKb: targetKb,
        onProgress: (p, s) {
          if (mounted) {
            setState(() {
              _progressValue = p;
              _progressStatus = s;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _result = res;
          _isCompressing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompressing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Compression failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Smart File Compressor',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // STEP 1 & 2: Select File / File info display
            _buildFileCard(),
            const SizedBox(height: 20),

            if (_selectedFile != null) ...[
              // STEP 3: Ask user what should be the final file size
              _buildTargetSizeSection(),
              const SizedBox(height: 24),

              // Progress Card
              if (_isCompressing) ...[
                _buildProgressCard(),
                const SizedBox(height: 20),
              ],

              // STEP 4: Compress Now button
              if (!_isCompressing && _result == null)
                GradientButton(
                  text: 'Compress Now',
                  icon: Icons.bolt_rounded,
                  onPressed: _executeCompression,
                ),

              // STEP 6 & 7: Compression Result Card + Preview/Save/Share
              if (_result != null) ...[
                _buildResultCard(),
                const SizedBox(height: 20),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard() {
    if (_selectedFile == null) {
      return InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'STEP 1: Select File to Compress',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Supports PDF, JPG, JPEG, PNG, WEBP, DOCX, PPTX, XLSX',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final name = _selectedFile!.path.split(Platform.pathSeparator).last;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getFileIcon(_fileExtension),
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _fileExtension.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Original Size: ${FileUtils.formatBytes(_originalSizeBytes)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.change_circle_outlined,
                color: AppColors.primary),
            tooltip: 'Change File',
            onPressed: _pickFile,
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSizeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.straighten_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'What should be the final file size?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your exact target size in KB or MB below. The compressor will adjust image resolutions and document streams to approach your requested size.',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),

          // Numeric Input & KB/MB Unit Toggle
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _targetSizeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Target Output Size',
                    hintText: 'e.g. 500',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ToggleButtons(
                isSelected: [_targetUnit == 'KB', _targetUnit == 'MB'],
                onPressed: (idx) {
                  setState(() => _targetUnit = idx == 0 ? 'KB' : 'MB');
                },
                borderRadius: BorderRadius.circular(12),
                selectedColor: Colors.white,
                fillColor: AppColors.primary,
                children: const [
                  Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('KB',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('MB',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Preset Chips (500 KB, 1 MB, 2 MB, 3 MB, 5 MB)
          Text(
            'Quick Size Options:',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['200 KB', '500 KB', '1 MB', '2 MB', '3 MB', '5 MB']
                .map((preset) {
              final parts = preset.split(' ');
              final isSelected =
                  _targetSizeController.text.trim() == parts[0] &&
                      _targetUnit == parts[1];
              return ChoiceChip(
                label: Text(preset),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                backgroundColor: AppColors.secondary.withValues(alpha: 0.5),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _targetSizeController.text = parts[0];
                      _targetUnit = parts[1];
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _progressStatus,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '${(_progressValue * 100).toInt()}%',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _progressValue,
            backgroundColor: AppColors.secondary,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            borderRadius: BorderRadius.circular(6),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Compression Successful!',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '-${r.formattedReduction}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // STEP 6: Multi-field metric display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                _buildMetricRow('Original Size', r.formattedOriginalSize),
                const Divider(height: 14),
                _buildMetricRow('Requested Target Size', r.formattedTargetSize),
                const Divider(height: 14),
                _buildMetricRow(
                  'Actual Compressed Size',
                  r.formattedCompressedSize,
                  valueColor: AppColors.success,
                  isBold: true,
                ),
                const Divider(height: 14),
                _buildMetricRow('Space Saved', r.formattedSavedBytes,
                    valueColor: AppColors.primary),
                const Divider(height: 14),
                _buildMetricRow('Compression Ratio', r.formattedReduction),
              ],
            ),
          ),

          if (r.note != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFE65100)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.note!,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFFE65100)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // STEP 7: Preview, Save, Share buttons
          Row(
            children: [
              if (r.fileType == 'PDF') ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfPreviewScreen(
                            filePath: r.compressedPath,
                            title: r.outputName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => ShareService.openFile(r.compressedPath),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Open File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: () => ShareService.shareFile(r.compressedPath),
                icon: const Icon(Icons.share_outlined, size: 20),
                tooltip: 'Share File',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _result = null;
                _selectedFile = null;
              });
            },
            child: Text(
              'Compress Another File',
              style: GoogleFonts.inter(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style:
              GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
        return Icons.description_rounded;
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/share_service.dart';
import '../theme/app_colors.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late PdfViewerController _pdfViewerController;
  int _pageCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.filePath);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_pageCount > 0)
              Text(
                'Page $_currentPage of $_pageCount',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.primary),
            tooltip: 'Share',
            onPressed: () => ShareService.shareFile(widget.filePath),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded,
                color: AppColors.textPrimary),
            tooltip: 'Open Externally',
            onPressed: () => ShareService.openFile(widget.filePath),
          ),
        ],
      ),
      body: !file.existsSync()
          ? Center(
              child: Text(
                'File does not exist on disk.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            )
          : Stack(
              children: [
                SfPdfViewer.file(
                  file,
                  controller: _pdfViewerController,
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                    setState(() {
                      _pageCount = details.document.pages.count;
                      _isLoading = false;
                    });
                  },
                  onPageChanged: (PdfPageChangedDetails details) {
                    setState(() {
                      _currentPage = details.newPageNumber;
                    });
                  },
                ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded,
                  color: AppColors.primary),
              onPressed: _currentPage > 1
                  ? () => _pdfViewerController.previousPage()
                  : null,
            ),
            Text(
              '$_currentPage / $_pageCount',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary),
              onPressed: _currentPage < _pageCount
                  ? () => _pdfViewerController.nextPage()
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

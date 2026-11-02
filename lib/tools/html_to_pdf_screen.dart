import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pdf_file_model.dart';
import '../services/pdf_conversion_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_result_modal.dart';

class HtmlToPdfScreen extends StatefulWidget {
  const HtmlToPdfScreen({super.key});

  @override
  State<HtmlToPdfScreen> createState() => _HtmlToPdfScreenState();
}

class _HtmlToPdfScreenState extends State<HtmlToPdfScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _htmlController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  bool _isProcessing = false;

  final String _defaultHtml = '''<h1>Project Invoice & Summary</h1>
<p>Thank you for choosing VertexDocs as your professional PDF toolkit.</p>

<h2>Invoice Details</h2>
<p><strong>Invoice Number:</strong> #VD-2026-8814</p>
<p><strong>Date:</strong> November 2, 2026</p>
<p><strong>Status:</strong> Paid in Full</p>

<h2>Service Breakdown</h2>
<ul>
  <li>Organize & Merge PDF Documents: 24 Files</li>
  <li>AI Document Summaries & Translation: 10 Pages</li>
  <li>Digital Signatures & Watermarks: Applied</li>
</ul>

<p>For questions or enterprise licensing, visit JM Vertex Technologies.</p>''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _htmlController.text = _defaultHtml;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _htmlController.dispose();
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _loadTemplate(String type) {
    if (type == 'invoice') {
      _htmlController.text = _defaultHtml;
    } else if (type == 'report') {
      _htmlController.text = '''<h1>Quarterly Engineering Report</h1>
<p>Executive performance overview prepared by VertexDocs Architecture Team.</p>
<h2>1. Objectives</h2>
<p>Delivered 42 comprehensive PDF processing tools with native Dart implementation.</p>
<h2>2. Milestones Achieved</h2>
<ul>
  <li>ISO 19005-1 PDF/A-1b Archival Compliance</li>
  <li>OpenXML (.docx, .xlsx, .pptx) Native Conversion</li>
  <li>On-device Vector Graphics and AcroForm Automation</li>
</ul>
<p><em>Approved by Lead System Architect</em></p>''';
    } else if (type == 'receipt') {
      _htmlController.text = '''<h1>Payment Confirmation</h1>
<p>Transaction ID: TXN-9941829048</p>
<p>Amount: \$49.00 USD</p>
<p>Merchant: VertexDocs Cloud Systems</p>
<p>Date: November 2026</p>
<p>Thank you for your business!</p>''';
    }
    setState(() {});
  }

  Future<void> _processConvert() async {
    final isUrlTab = _tabController.index == 1;

    if (isUrlTab && _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Please enter a valid URL.')),
      );
      return;
    }

    if (!isUrlTab && _htmlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Please enter HTML content.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final customTitle = _titleController.text.trim().isNotEmpty
          ? '${_titleController.text.trim()}.pdf'
          : null;

      final PdfFileModel result;
      if (isUrlTab) {
        result = await PdfConversionService().htmlToPdf(
          url: _urlController.text.trim(),
          outputName: customTitle,
        );
      } else {
        result = await PdfConversionService().htmlToPdf(
          htmlContent: _htmlController.text.trim(),
          outputName: customTitle,
        );
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ToolResultModal.show(
        context: context,
        result: result,
        toolTitle: 'HTML to PDF',
        onDismiss: () => Navigator.of(context).pop(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Error generating PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTML to PDF'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.code_rounded), text: 'HTML Code'),
            Tab(icon: Icon(Icons.link_rounded), text: 'Web URL'),
          ],
        ),
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
                    child: const Icon(Icons.html_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Web Page to Document',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Render HTML tags, tables, and web links cleanly into PDF without heavy WebViews.',
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

            // Tab Content
            SizedBox(
              height: 340,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: HTML editor
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Quick Templates: ',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          ActionChip(
                            label: const Text('Invoice'),
                            onPressed: () => _loadTemplate('invoice'),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('Report'),
                            onPressed: () => _loadTemplate('report'),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text('Receipt'),
                            onPressed: () => _loadTemplate('receipt'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: TextField(
                            controller: _htmlController,
                            maxLines: null,
                            expands: true,
                            style: GoogleFonts.firaCode(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: '<h1>Title</h1>\n<p>Content...</p>',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Tab 2: Web URL
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Web Page URL',
                          hintText: 'https://example.com/article',
                          prefixIcon: const Icon(Icons.public_rounded,
                              color: AppColors.primary),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'VertexDocs will fetch the remote webpage HTML, extract headings, typography, lists, and paragraphs, and compile them into a neat multi-page PDF.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Optional Output Name
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Document Name (Optional)',
                hintText: 'e.g. My_Exported_Webpage',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
                prefixIcon:
                    const Icon(Icons.title_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),

            GradientButton(
              text: 'Generate PDF Document',
              icon: Icons.picture_as_pdf_rounded,
              isLoading: _isProcessing,
              onPressed: _processConvert,
            ),
          ],
        ),
      ),
    );
  }
}

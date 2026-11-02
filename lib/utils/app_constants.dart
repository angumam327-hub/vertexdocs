import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'VertexDocs';
  static const String appTagline = 'Your PDFs, made simple.';
  static const String appVersion = '1.0.0';
  static const String developerName = 'JM Vertex Technologies';

  // SharedPreferences Keys
  static const String prefRecentFiles = 'vertex_recent_files';
  static const String prefSavedFiles = 'vertex_saved_files';
  static const String prefAppLanguage = 'vertex_app_language';
  static const String prefGeminiApiKey = 'vertex_gemini_api_key';
  static const String prefAutoSave = 'vertex_auto_save';
  static const String prefDefaultQuality = 'vertex_default_quality';

  // Tool IDs: A. Organize PDF
  static const String toolMerge = 'merge';
  static const String toolSplit = 'split';
  static const String toolOrganize = 'organize';
  static const String toolRemovePages = 'remove_pages';
  static const String toolExtractPages = 'extract_pages';
  static const String toolRotate = 'rotate';
  static const String toolPageNumbers = 'page_numbers';
  static const String toolCrop = 'crop';

  // Tool IDs: B. Optimize PDF
  static const String toolCompress = 'compress';
  static const String toolRepair = 'repair';
  static const String toolOcrPdf = 'ocr_pdf';
  static const String toolScanToPdf = 'scan_to_pdf';
  static const String toolCompare = 'compare';
  static const String toolPdfToPdfA = 'pdf_to_pdfa';

  // Tool IDs: C. Convert PDF
  static const String toolPdfToWord = 'pdf_to_word';
  static const String toolPdfToExcel = 'pdf_to_excel';
  static const String toolPdfToPowerPoint = 'pdf_to_powerpoint';
  static const String toolPdfToJpg = 'pdf_to_jpg';
  static const String toolPdfToImages = 'pdf_to_images';
  static const String toolWordToPdf = 'word_to_pdf';
  static const String toolExcelToPdf = 'excel_to_pdf';
  static const String toolPowerPointToPdf = 'powerpoint_to_pdf';
  static const String toolJpgToPdf = 'jpg_to_pdf';
  static const String toolImagesToPdf = 'images_to_pdf';
  static const String toolHtmlToPdf = 'html_to_pdf';

  // Tool IDs: D. PDF Security
  static const String toolProtect = 'protect';
  static const String toolUnlock = 'unlock';
  static const String toolSign = 'sign';
  static const String toolWatermark = 'watermark';
  static const String toolRedact = 'redact';

  // Tool IDs: E. Edit PDF
  static const String toolEdit = 'edit';
  static const String toolAddText = 'add_text';
  static const String toolAddImages = 'add_images';
  static const String toolAddShapes = 'add_shapes';
  static const String toolAddAnnotations = 'add_annotations';
  static const String toolPdfForms = 'pdf_forms';

  // Tool IDs: F. PDF Intelligence
  static const String toolAiSummarizer = 'ai_summarizer';
  static const String toolTranslatePdf = 'translate_pdf';
  static const String toolExtractText = 'extract_text';
  static const String toolExtractKeyPoints = 'extract_key_points';
  static const String toolPdfQa = 'pdf_qa';
  static const String toolExplainPdf = 'explain_pdf';
  static const String toolOcr = 'ocr'; // Legacy alias
}

/// Metadata structure for a PDF tool item displayed in home & all tools
class PdfToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String category;
  final String? badge;
  final bool isWorkflow;

  const PdfToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    this.badge,
    this.isWorkflow = false,
  });
}

/// Complete catalog of all 42 iLovePDF-style PDF tools in VertexDocs
final List<PdfToolItem> allPdfTools = [
  // --- A. ORGANIZE PDF ---
  const PdfToolItem(
    id: AppConstants.toolMerge,
    title: 'Merge PDF',
    description: 'Combine multiple PDFs into one document in your chosen order',
    icon: Icons.call_merge_rounded,
    category: 'Organize PDF',
    badge: 'Popular',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolSplit,
    title: 'Split PDF',
    description:
        'Extract specific page ranges or separate pages into independent files',
    icon: Icons.call_split_rounded,
    category: 'Organize PDF',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolOrganize,
    title: 'Organize PDF',
    description:
        'Rearrange, rotate, delete or extract pages visually with thumbnails',
    icon: Icons.view_comfortable_rounded,
    category: 'Organize PDF',
    badge: 'New',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolRemovePages,
    title: 'Remove PDF Pages',
    description:
        'Select and permanently delete unwanted pages from your document',
    icon: Icons.delete_sweep_rounded,
    category: 'Organize PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolExtractPages,
    title: 'Extract PDF Pages',
    description: 'Pull out chosen pages and create a new focused PDF file',
    icon: Icons.file_download_outlined,
    category: 'Organize PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolRotate,
    title: 'Rotate PDF',
    description:
        'Rotate PDF pages 90°, 180° or 270° clockwise or counter-clockwise',
    icon: Icons.rotate_right_rounded,
    category: 'Organize PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolPageNumbers,
    title: 'Page Numbers',
    description:
        'Insert customizable header or footer page numbers with stylish formatting',
    icon: Icons.format_list_numbered_rounded,
    category: 'Organize PDF',
    badge: 'Pro',
  ),
  const PdfToolItem(
    id: AppConstants.toolCrop,
    title: 'Crop PDF',
    description: 'Trim margins or crop page dimensions to remove blank space',
    icon: Icons.crop_rounded,
    category: 'Organize PDF',
  ),

  // --- B. OPTIMIZE PDF ---
  const PdfToolItem(
    id: AppConstants.toolCompress,
    title: 'Compress PDF',
    description:
        'Reduce file size significantly while preserving clear visual quality',
    icon: Icons.compress_rounded,
    category: 'Optimize PDF',
    badge: 'Fast',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolRepair,
    title: 'Repair PDF',
    description:
        'Rebuild cross-reference tables and recover data from damaged PDFs',
    icon: Icons.build_circle_rounded,
    category: 'Optimize PDF',
    badge: 'Smart',
  ),
  const PdfToolItem(
    id: AppConstants.toolOcrPdf,
    title: 'OCR PDF',
    description:
        'Recognize optical characters from scanned pages in English & Tamil',
    icon: Icons.document_scanner_rounded,
    category: 'Optimize PDF',
    badge: 'Bilingual',
  ),
  const PdfToolItem(
    id: AppConstants.toolScanToPdf,
    title: 'Scan to PDF',
    description:
        'Capture documents with your device camera and convert into sharp PDFs',
    icon: Icons.camera_alt_rounded,
    category: 'Optimize PDF',
    badge: 'Camera',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolCompare,
    title: 'Compare PDF',
    description:
        'Compare two PDF documents side-by-side and highlight additions & deletions',
    icon: Icons.compare_arrows_rounded,
    category: 'Optimize PDF',
    badge: 'Diff',
  ),
  const PdfToolItem(
    id: AppConstants.toolPdfToPdfA,
    title: 'PDF to PDF/A',
    description:
        'Convert standard PDF to ISO compliant PDF/A for long-term archiving',
    icon: Icons.archive_rounded,
    category: 'Optimize PDF',
  ),

  // --- C. CONVERT PDF ---
  const PdfToolItem(
    id: AppConstants.toolPdfToWord,
    title: 'PDF to Word',
    description:
        'Convert PDF text and structure into editable Microsoft Word (.docx)',
    icon: Icons.article_rounded,
    category: 'Convert PDF',
    badge: 'DOCX',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolPdfToExcel,
    title: 'PDF to Excel',
    description:
        'Extract tables, columns and tabular data into Microsoft Excel (.xlsx)',
    icon: Icons.table_chart_rounded,
    category: 'Convert PDF',
    badge: 'XLSX',
  ),
  const PdfToolItem(
    id: AppConstants.toolPdfToPowerPoint,
    title: 'PDF to PowerPoint',
    description:
        'Convert PDF pages into presentation slides in Microsoft PowerPoint (.pptx)',
    icon: Icons.slideshow_rounded,
    category: 'Convert PDF',
    badge: 'PPTX',
  ),
  const PdfToolItem(
    id: AppConstants.toolPdfToJpg,
    title: 'PDF to JPG',
    description: 'Save PDF pages as high-resolution compressed JPG pictures',
    icon: Icons.image_rounded,
    category: 'Convert PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolPdfToImages,
    title: 'PDF to Images',
    description: 'Convert all PDF pages into PNG or JPG image formats',
    icon: Icons.photo_library_rounded,
    category: 'Convert PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolWordToPdf,
    title: 'Word to PDF',
    description:
        'Convert Microsoft Word (.docx) documents into professional PDFs',
    icon: Icons.description_rounded,
    category: 'Convert PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolExcelToPdf,
    title: 'Excel to PDF',
    description:
        'Convert Microsoft Excel (.xlsx) spreadsheets into clean PDF tables',
    icon: Icons.grid_on_rounded,
    category: 'Convert PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolPowerPointToPdf,
    title: 'PowerPoint to PDF',
    description:
        'Convert PowerPoint (.pptx) presentation decks into PDF handouts',
    icon: Icons.co_present_rounded,
    category: 'Convert PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolJpgToPdf,
    title: 'JPG to PDF',
    description:
        'Transform multiple JPG pictures into a unified multi-page PDF',
    icon: Icons.add_photo_alternate_rounded,
    category: 'Convert PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolImagesToPdf,
    title: 'Images to PDF',
    description:
        'Create a single PDF from gallery photos with margin & size control',
    icon: Icons.picture_as_pdf_rounded,
    category: 'Convert PDF',
    badge: 'Popular',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolHtmlToPdf,
    title: 'HTML to PDF',
    description:
        'Convert web pages or raw HTML code into neatly rendered PDF documents',
    icon: Icons.html_rounded,
    category: 'Convert PDF',
  ),

  // --- D. PDF SECURITY ---
  const PdfToolItem(
    id: AppConstants.toolProtect,
    title: 'Protect PDF',
    description: 'Encrypt document with custom secure 256-bit AES password',
    icon: Icons.lock_rounded,
    category: 'PDF Security',
    badge: 'AES-256',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolUnlock,
    title: 'Unlock PDF',
    description:
        'Remove password protection from authorized encrypted PDF files',
    icon: Icons.lock_open_rounded,
    category: 'PDF Security',
  ),
  const PdfToolItem(
    id: AppConstants.toolSign,
    title: 'Sign PDF',
    description:
        'Draw or import electronic signatures and stamp them onto any page',
    icon: Icons.draw_rounded,
    category: 'PDF Security',
    badge: 'e-Sign',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolWatermark,
    title: 'Add Watermark',
    description:
        'Stamp custom text or confidential copyright watermarks onto pages',
    icon: Icons.branding_watermark_rounded,
    category: 'PDF Security',
  ),
  const PdfToolItem(
    id: AppConstants.toolRedact,
    title: 'Redact PDF',
    description:
        'Permanently purge sensitive text, names or numbers from page streams',
    icon: Icons.visibility_off_rounded,
    category: 'PDF Security',
    badge: 'Privacy',
  ),

  // --- E. EDIT PDF ---
  const PdfToolItem(
    id: AppConstants.toolEdit,
    title: 'Edit PDF',
    description:
        'Add text, graphics, arrows, stamps, and annotations to any page',
    icon: Icons.edit_note_rounded,
    category: 'Edit PDF',
    badge: 'Full Suite',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolAddText,
    title: 'Add Text',
    description: 'Place custom styled typography and paragraphs onto PDF pages',
    icon: Icons.title_rounded,
    category: 'Edit PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolAddImages,
    title: 'Add Images',
    description:
        'Insert logos, photos or scanned stamps onto existing PDF pages',
    icon: Icons.insert_photo_rounded,
    category: 'Edit PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolAddShapes,
    title: 'Add Shapes',
    description:
        'Draw rectangles, circles, lines, and callout arrows with stroke & fill',
    icon: Icons.interests_rounded,
    category: 'Edit PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolAddAnnotations,
    title: 'Add Annotations',
    description: 'Highlight phrases, underline, strikeout, or add sticky notes',
    icon: Icons.highlight_rounded,
    category: 'Edit PDF',
  ),
  const PdfToolItem(
    id: AppConstants.toolPdfForms,
    title: 'PDF Forms',
    description:
        'Fill out interactive AcroForm text fields and checkboxes in PDFs',
    icon: Icons.dynamic_form_rounded,
    category: 'Edit PDF',
    badge: 'Interactive',
  ),

  // --- F. PDF INTELLIGENCE ---
  const PdfToolItem(
    id: AppConstants.toolAiSummarizer,
    title: 'AI Summarizer',
    description: 'Generate high-impact executive summaries in English or Tamil',
    icon: Icons.summarize_rounded,
    category: 'PDF Intelligence',
    badge: 'AI',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolTranslatePdf,
    title: 'Translate PDF',
    description:
        'Translate document contents across English, Tamil, Hindi, Spanish & more',
    icon: Icons.translate_rounded,
    category: 'PDF Intelligence',
    badge: 'Multilingual',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolExtractText,
    title: 'Extract Text',
    description:
        'Extract raw selectable text from all pages for easy copying & sharing',
    icon: Icons.content_paste_go_rounded,
    category: 'PDF Intelligence',
  ),
  const PdfToolItem(
    id: AppConstants.toolExtractKeyPoints,
    title: 'Extract Key Points',
    description: 'Isolate bulleted action items, stats, and critical takeaways',
    icon: Icons.checklist_rounded,
    category: 'PDF Intelligence',
    badge: 'Bullet Points',
  ),
  const PdfToolItem(
    id: AppConstants.toolPdfQa,
    title: 'PDF Question & Answer',
    description:
        'Ask detailed questions and get answers grounded directly in document text',
    icon: Icons.question_answer_rounded,
    category: 'PDF Intelligence',
    badge: 'Q&A',
    isWorkflow: true,
  ),
  const PdfToolItem(
    id: AppConstants.toolExplainPdf,
    title: 'Explain Simply',
    description:
        'Break down complex legal, technical, or academic clauses into plain terms',
    icon: Icons.lightbulb_rounded,
    category: 'PDF Intelligence',
    badge: 'Simple Words',
  ),
];

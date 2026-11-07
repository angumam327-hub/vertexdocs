import 'dart:io';
import 'package:flutter/material.dart';
import '../tools/add_annotations_screen.dart';
import '../tools/add_images_screen.dart';
import '../tools/add_shapes_screen.dart';
import '../tools/add_text_screen.dart';
import '../tools/ai_summarizer_screen.dart';
import '../tools/compare_pdf_screen.dart';
import '../tools/compress_pdf_screen.dart';
import '../tools/crop_pdf_screen.dart';
import '../tools/document_editor_screen.dart';
import '../tools/edit_pdf_screen.dart';
import '../tools/excel_to_pdf_screen.dart';
import '../tools/explain_pdf_screen.dart';
import '../tools/extract_key_points_screen.dart';
import '../tools/extract_pages_screen.dart';
import '../tools/html_to_pdf_screen.dart';
import '../tools/images_to_pdf_screen.dart';
import '../tools/jpg_to_pdf_screen.dart';
import '../tools/merge_pdf_screen.dart';
import '../tools/ocr_pdf_screen.dart';
import '../tools/ocr_screen.dart';
import '../tools/organize_pdf_screen.dart';
import '../tools/page_numbers_screen.dart';
import '../tools/pdf_editor_screen.dart';
import '../tools/pdf_forms_screen.dart';
import '../tools/pdf_qa_screen.dart';
import '../tools/pdf_to_excel_screen.dart';
import '../tools/pdf_to_images_screen.dart';
import '../tools/pdf_to_jpg_screen.dart';
import '../tools/pdf_to_pdfa_screen.dart';
import '../tools/pdf_to_powerpoint_screen.dart';
import '../tools/pdf_to_word_screen.dart';
import '../tools/powerpoint_to_pdf_screen.dart';
import '../tools/protect_pdf_screen.dart';
import '../tools/redact_pdf_screen.dart';
import '../tools/remove_pages_screen.dart';
import '../tools/repair_pdf_screen.dart';
import '../tools/rotate_pdf_screen.dart';
import '../tools/scan_to_pdf_screen.dart';
import '../tools/sign_pdf_screen.dart';
import '../tools/smart_compressor_screen.dart';
import '../tools/split_pdf_screen.dart';
import '../tools/translate_document_screen.dart';
import '../tools/translate_pdf_screen.dart';
import '../tools/unlock_pdf_screen.dart';
import '../tools/watermark_screen.dart';
import '../tools/word_to_pdf_screen.dart';
import 'app_constants.dart';

class ToolRouter {
  ToolRouter._();

  static void openTool(BuildContext context, String toolId, {File? file}) {
    Widget screen;
    switch (toolId) {
      // --- A. Organize PDF ---
      case AppConstants.toolMerge:
        screen = MergePdfScreen(initialFiles: file != null ? [file] : null);
        break;
      case AppConstants.toolSplit:
        screen = SplitPdfScreen(initialFile: file);
        break;
      case AppConstants.toolOrganize:
        screen = OrganizePdfScreen(initialFile: file);
        break;
      case AppConstants.toolRemovePages:
        screen = RemovePagesScreen(initialFile: file);
        break;
      case AppConstants.toolExtractPages:
        screen = ExtractPagesScreen(initialFile: file);
        break;
      case AppConstants.toolRotate:
        screen = RotatePdfScreen(initialFile: file);
        break;
      case AppConstants.toolPageNumbers:
        screen = PageNumbersScreen(initialFile: file);
        break;
      case AppConstants.toolCrop:
        screen = CropPdfScreen(initialFile: file);
        break;

      // --- B. Optimize PDF ---
      case AppConstants.toolSmartCompressor:
        screen = SmartCompressorScreen(initialFile: file);
        break;
      case AppConstants.toolCompress:
        screen = CompressPdfScreen(initialFile: file);
        break;
      case AppConstants.toolRepair:
        screen = RepairPdfScreen(initialFile: file);
        break;
      case AppConstants.toolOcrPdf:
        screen = OcrPdfScreen(initialFile: file);
        break;
      case AppConstants.toolScanToPdf:
        screen = const ScanToPdfScreen();
        break;
      case AppConstants.toolCompare:
        screen = ComparePdfScreen(initialFile: file);
        break;
      case AppConstants.toolPdfToPdfA:
        screen = PdfToPdfaScreen(initialFile: file);
        break;

      // --- C. Convert PDF ---
      case AppConstants.toolPdfToWord:
        screen = PdfToWordScreen(initialFile: file);
        break;
      case AppConstants.toolPdfToExcel:
        screen = PdfToExcelScreen(initialFile: file);
        break;
      case AppConstants.toolPdfToPowerPoint:
        screen = PdfToPowerpointScreen(initialFile: file);
        break;
      case AppConstants.toolPdfToJpg:
        screen = PdfToJpgScreen(initialFile: file);
        break;
      case AppConstants.toolPdfToImages:
        screen = PdfToImagesScreen(initialFile: file);
        break;
      case AppConstants.toolWordToPdf:
        screen = const WordToPdfScreen();
        break;
      case AppConstants.toolExcelToPdf:
        screen = const ExcelToPdfScreen();
        break;
      case AppConstants.toolPowerPointToPdf:
        screen = const PowerpointToPdfScreen();
        break;
      case AppConstants.toolJpgToPdf:
        screen = const JpgToPdfScreen();
        break;
      case AppConstants.toolImagesToPdf:
        screen = const ImagesToPdfScreen();
        break;
      case AppConstants.toolHtmlToPdf:
        screen = const HtmlToPdfScreen();
        break;

      // --- D. PDF Security ---
      case AppConstants.toolProtect:
        screen = ProtectPdfScreen(initialFile: file);
        break;
      case AppConstants.toolUnlock:
        screen = UnlockPdfScreen(initialFile: file);
        break;
      case AppConstants.toolSign:
        screen = SignPdfScreen(initialFile: file);
        break;
      case AppConstants.toolWatermark:
        screen = WatermarkScreen(initialFile: file);
        break;
      case AppConstants.toolRedact:
        screen = RedactPdfScreen(initialFile: file);
        break;

      // --- E. Edit PDF ---
      case AppConstants.toolPdfEditor:
        screen = PdfEditorScreen(initialFile: file);
        break;
      case AppConstants.toolDocumentEditor:
        screen = DocumentEditorScreen(initialFile: file);
        break;
      case AppConstants.toolEdit:
        screen = EditPdfScreen(initialFile: file);
        break;
      case AppConstants.toolAddText:
        screen = AddTextScreen(initialFile: file);
        break;
      case AppConstants.toolAddImages:
        screen = AddImagesScreen(initialFile: file);
        break;
      case AppConstants.toolAddShapes:
        screen = AddShapesScreen(initialFile: file);
        break;
      case AppConstants.toolAddAnnotations:
        screen = AddAnnotationsScreen(initialFile: file);
        break;
      case AppConstants.toolPdfForms:
        screen = PdfFormsScreen(initialFile: file);
        break;

      // --- F. PDF Intelligence ---
      case AppConstants.toolAiSummarizer:
        screen = AiSummarizerScreen(initialFile: file);
        break;
      case AppConstants.toolTranslatePdf:
        screen = TranslatePdfScreen(initialFile: file);
        break;
      case AppConstants.toolTranslateDocument:
        screen = TranslateDocumentScreen(initialFile: file);
        break;
      case AppConstants.toolExtractText:
        screen = OcrScreen(initialFile: file);
        break;
      case AppConstants.toolExtractKeyPoints:
        screen = ExtractKeyPointsScreen(initialFile: file);
        break;
      case AppConstants.toolPdfQa:
        screen = PdfQaScreen(initialFile: file);
        break;
      case AppConstants.toolExplainPdf:
        screen = ExplainPdfScreen(initialFile: file);
        break;
      case AppConstants.toolOcr:
        screen = OcrScreen(initialFile: file);
        break;

      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

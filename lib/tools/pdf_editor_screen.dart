import 'dart:io';
import 'package:flutter/material.dart';
import 'edit_pdf_screen.dart';

class PdfEditorScreen extends StatelessWidget {
  final File? initialFile;

  const PdfEditorScreen({super.key, this.initialFile});

  @override
  Widget build(BuildContext context) {
    return EditPdfScreen(initialFile: initialFile);
  }
}

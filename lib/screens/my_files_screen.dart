import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pdf_file_model.dart';
import '../services/file_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/pdf_file_card.dart';
import '../widgets/search_bar_widget.dart';
import 'pdf_preview_screen.dart';

class MyFilesScreen extends StatefulWidget {
  const MyFilesScreen({super.key});

  @override
  State<MyFilesScreen> createState() => _MyFilesScreenState();
}

class _MyFilesScreenState extends State<MyFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  int _totalBytesUsed = 0;

  final List<String> _filters = const [
    'All',
    'Merged',
    'Split',
    'Compressed',
    'Protected',
    'Unlocked',
    'Watermarked',
  ];

  @override
  void initState() {
    super.initState();
    _refreshStorageUsage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshStorageUsage() async {
    final bytes = await FileService().getTotalStorageUsed();
    if (mounted) {
      setState(() => _totalBytesUsed = bytes);
    }
  }

  Future<void> _importPdf() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      final stat = await file.stat();
      final model = PdfFileModel(
        id: '${file.path}_${stat.modified.millisecondsSinceEpoch}',
        name: file.path.split(Platform.pathSeparator).last,
        path: file.path,
        size: stat.size,
        lastModified: stat.modified,
        operationType: 'Imported',
      );
      await StorageService().addSavedFile(model);
      await _refreshStorageUsage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'My Files',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded,
                color: AppColors.primary, size: 28),
            tooltip: 'Import PDF',
            onPressed: _importPdf,
          ),
        ],
      ),
      body: ValueListenableBuilder<List<PdfFileModel>>(
        valueListenable: StorageService().savedFilesNotifier,
        builder: (context, savedFiles, _) {
          final filteredList = savedFiles.where((f) {
            final matchesSearch = _searchQuery.isEmpty ||
                f.name.toLowerCase().contains(_searchQuery);
            final matchesFilter = _selectedFilter == 'All' ||
                f.operationType.toLowerCase() == _selectedFilter.toLowerCase();
            return matchesSearch && matchesFilter;
          }).toList();

          return Column(
            children: [
              // Search & filter section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: SearchBarWidget(
                  controller: _searchController,
                  hintText: 'Search my files...',
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                  onClear: () {
                    setState(() => _searchQuery = '');
                  },
                ),
              ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: _filters.map((filter) {
                    final isSel = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSel,
                        selectedColor: AppColors.secondary,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                          color: isSel
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedFilter = filter);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Storage Info Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storage_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            '${savedFiles.length} Documents',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Total: ${FileUtils.formatBytes(_totalBytesUsed)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // File List
              Expanded(
                child: filteredList.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.folder_open_rounded,
                        title: savedFiles.isEmpty
                            ? 'No PDF files yet'
                            : 'No matching files found',
                        description: savedFiles.isEmpty
                            ? 'Processed and imported PDF files will appear here.'
                            : 'Try changing your search keyword or selected filter.',
                        buttonText: savedFiles.isEmpty ? 'Import a PDF' : null,
                        onButtonPressed: savedFiles.isEmpty ? _importPdf : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final fileModel = filteredList[index];
                          return PdfFileCard(
                            file: fileModel,
                            onTap: () {
                              ShareService.openFile(fileModel.path);
                            },
                            onPreview: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PdfPreviewScreen(
                                    filePath: fileModel.path,
                                    title: fileModel.name,
                                  ),
                                ),
                              );
                            },
                            onShare: () =>
                                ShareService.shareFile(fileModel.path),
                            onDelete: () async {
                              await FileService().deleteFile(fileModel.path);
                              await _refreshStorageUsage();
                            },
                            onRename: (newName) async {
                              await FileService()
                                  .renameFile(fileModel.path, newName);
                              await _refreshStorageUsage();
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

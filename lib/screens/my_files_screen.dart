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

enum FileSortOption {
  dateDesc('Date: Newest First'),
  dateAsc('Date: Oldest First'),
  nameAsc('Name: A to Z'),
  nameDesc('Name: Z to A'),
  sizeDesc('Size: Largest First'),
  sizeAsc('Size: Smallest First');

  final String label;
  const FileSortOption(this.label);
}

class MyFilesScreen extends StatefulWidget {
  const MyFilesScreen({super.key});

  @override
  State<MyFilesScreen> createState() => _MyFilesScreenState();
}

class _MyFilesScreenState extends State<MyFilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  FileSortOption _currentSort = FileSortOption.dateDesc;
  int _totalBytesUsed = 0;

  final List<String> _filters = const [
    'All',
    'Original',
    'Translated',
    'Compressed',
    'Edited',
    'Merged',
    'Split',
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

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'Sort Files By',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(),
            ...FileSortOption.values.map((opt) {
              final isSel = _currentSort == opt;
              return ListTile(
                title: Text(
                  opt.label,
                  style: GoogleFonts.inter(
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                trailing: isSel
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _currentSort = opt);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
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
            icon: const Icon(Icons.sort_rounded, color: AppColors.primary),
            tooltip: 'Sort Files',
            onPressed: _showSortDialog,
          ),
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

            bool matchesFilter = false;
            if (_selectedFilter == 'All') {
              matchesFilter = true;
            } else if (_selectedFilter == 'Original') {
              matchesFilter = f.operationType.toLowerCase() == 'imported' ||
                  f.operationType.toLowerCase() == 'original';
            } else if (_selectedFilter == 'Edited') {
              matchesFilter = f.operationType.toLowerCase().contains('edited');
            } else {
              matchesFilter = f.operationType
                  .toLowerCase()
                  .contains(_selectedFilter.toLowerCase());
            }

            return matchesSearch && matchesFilter;
          }).toList();

          // Apply Sorting
          filteredList.sort((a, b) {
            switch (_currentSort) {
              case FileSortOption.dateDesc:
                return b.lastModified.compareTo(a.lastModified);
              case FileSortOption.dateAsc:
                return a.lastModified.compareTo(b.lastModified);
              case FileSortOption.nameAsc:
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              case FileSortOption.nameDesc:
                return b.name.toLowerCase().compareTo(a.name.toLowerCase());
              case FileSortOption.sizeDesc:
                return b.size.compareTo(a.size);
              case FileSortOption.sizeAsc:
                return a.size.compareTo(b.size);
            }
          });

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
                            '${filteredList.length} of ${savedFiles.length} Documents',
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

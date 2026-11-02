import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pdf_file_model.dart';
import '../services/file_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/tool_router.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/pdf_file_card.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/tool_card.dart';
import 'ai_assistant_screen.dart';
import 'pdf_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTool(BuildContext context, String toolId, {File? file}) {
    ToolRouter.openTool(context, toolId, file: file);
  }

  void _showFileActionSheet(BuildContext context, File file) {
    final name = file.path.split(Platform.pathSeparator).last;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Select an action for this PDF',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            _buildActionItem(
              ctx,
              Icons.visibility_outlined,
              'Preview Document',
              'View inside VertexDocs',
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PdfPreviewScreen(filePath: file.path, title: name),
                  ),
                );
              },
            ),
            _buildActionItem(
              ctx,
              Icons.auto_awesome_rounded,
              'Ask VertexDocs AI',
              'Summarize, extract points, or chat',
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AiAssistantScreen(initialPdfPath: file.path),
                  ),
                );
              },
            ),
            _buildActionItem(
              ctx,
              Icons.compress_rounded,
              'Compress PDF',
              'Reduce file size',
              () {
                Navigator.pop(ctx);
                _openTool(context, AppConstants.toolCompress, file: file);
              },
            ),
            _buildActionItem(
              ctx,
              Icons.call_split_rounded,
              'Split Pages',
              'Extract specific page range',
              () {
                Navigator.pop(ctx);
                _openTool(context, AppConstants.toolSplit, file: file);
              },
            ),
            _buildActionItem(
              ctx,
              Icons.branding_watermark_rounded,
              'Add Watermark',
              'Stamp text on pages',
              () {
                Navigator.pop(ctx);
                _openTool(context, AppConstants.toolWatermark, file: file);
              },
            ),
            _buildActionItem(
              ctx,
              Icons.lock_rounded,
              'Protect with Password',
              '256-bit AES encryption',
              () {
                Navigator.pop(ctx);
                _openTool(context, AppConstants.toolProtect, file: file);
              },
            ),
            _buildActionItem(
              ctx,
              Icons.document_scanner_rounded,
              'OCR & Extract Text',
              'Extract all text',
              () {
                Navigator.pop(ctx);
                _openTool(context, AppConstants.toolOcr, file: file);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext ctx,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.secondaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title,
          style:
              GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style:
              GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTools = allPdfTools.where((t) {
      if (_searchFilter.isEmpty) return true;
      return t.title.toLowerCase().contains(_searchFilter) ||
          t.description.toLowerCase().contains(_searchFilter) ||
          t.category.toLowerCase().contains(_searchFilter);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pink Gradient Home Header
            AppHeader(
              onFilePicked: (file) => _showFileActionSheet(context, file),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: SearchBarWidget(
                controller: _searchController,
                onChanged: (val) {
                  setState(() => _searchFilter = val.trim().toLowerCase());
                },
                onClear: () {
                  setState(() => _searchFilter = '');
                },
              ),
            ),

            // Two-column PDF tool cards Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchFilter.isEmpty
                        ? 'Popular PDF Tools'
                        : 'Found Tools (${filteredTools.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.onNavigateTab != null && _searchFilter.isEmpty)
                    TextButton(
                      onPressed: () => widget.onNavigateTab!(1),
                      child: Text(
                        'View All',
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Tools 2-Column Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: filteredTools.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.search_off_rounded,
                      title: 'No tools found',
                      description:
                          'Try searching with a different keyword like "Merge", "Protect", or "Compress".',
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.05,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount:
                          _searchFilter.isEmpty ? 6 : filteredTools.length,
                      itemBuilder: (context, index) {
                        final tool = filteredTools[index];
                        return ToolCard(
                          tool: tool,
                          onTap: () => _openTool(context, tool.id),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 24),

            // Recently Processed Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recently Processed',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ValueListenableBuilder<List<PdfFileModel>>(
                    valueListenable: StorageService().recentFilesNotifier,
                    builder: (context, recentList, _) {
                      if (recentList.isEmpty) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: () {
                          StorageService().clearRecentFiles();
                        },
                        child: Text(
                          'Clear',
                          style: GoogleFonts.inter(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Recently Processed List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ValueListenableBuilder<List<PdfFileModel>>(
                valueListenable: StorageService().recentFilesNotifier,
                builder: (context, recentList, _) {
                  if (recentList.isEmpty) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No documents processed yet',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose a file or select any tool above to get started.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentList.length > 5 ? 5 : recentList.length,
                    itemBuilder: (context, index) {
                      final item = recentList[index];
                      return PdfFileCard(
                        file: item,
                        onTap: () {
                          ShareService.openFile(item.path);
                        },
                        onPreview: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfPreviewScreen(
                                filePath: item.path,
                                title: item.name,
                              ),
                            ),
                          );
                        },
                        onShare: () => ShareService.shareFile(item.path),
                        onDelete: () => FileService().deleteFile(item.path),
                        onRename: (newName) =>
                            FileService().renameFile(item.path, newName),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

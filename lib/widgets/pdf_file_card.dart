import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pdf_file_model.dart';
import '../theme/app_colors.dart';

class PdfFileCard extends StatelessWidget {
  final PdfFileModel file;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final Function(String newName)? onRename;
  final VoidCallback? onPreview;
  final VoidCallback? onChange;

  const PdfFileCard({
    super.key,
    required this.file,
    this.onTap,
    this.onShare,
    this.onDelete,
    this.onRename,
    this.onPreview,
    this.onChange,
  });

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(
      text: file.name.replaceAll('.pdf', ''),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Rename File',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File Name',
            suffixText: '.pdf',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && onRename != null) {
                Navigator.pop(dialogCtx);
                onRename!(newName);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'Delete File',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete "${file.name}"? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (onDelete != null) onDelete!();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? onChange,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.secondary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // PDF Icon badge
                Container(
                  width: 44,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      file.isEncrypted
                          ? Icons.lock_outline_rounded
                          : Icons.picture_as_pdf_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // File name & meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        file.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  if (file.pageCount != null &&
                                      file.pageCount! > 0) ...[
                                    TextSpan(
                                      text:
                                          '${file.pageCount} ${file.pageCount == 1 ? 'page' : 'pages'} • ',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  TextSpan(
                                    text: file.formattedSize,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (file.formattedDate.isNotEmpty) ...[
                                    TextSpan(
                                      text: ' • ${file.formattedDate}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (file.operationType.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              flex: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  file.operationType,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Change button
                if (onChange != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onChange,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Change',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],

                // Share button
                if (onChange == null && onShare != null)
                  IconButton(
                    icon: const Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onShare,
                    tooltip: 'Share',
                  ),

                // Popup menu
                if (onChange == null ||
                    onRename != null ||
                    onDelete != null ||
                    onPreview != null)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'open':
                          if (onTap != null) onTap!();
                          break;
                        case 'preview':
                          if (onPreview != null) onPreview!();
                          break;
                        case 'share':
                          if (onShare != null) onShare!();
                          break;
                        case 'rename':
                          _showRenameDialog(context);
                          break;
                        case 'delete':
                          _showDeleteDialog(context);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (onTap != null)
                        const PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_new_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Open'),
                            ],
                          ),
                        ),
                      if (onPreview != null)
                        const PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Preview in App'),
                            ],
                          ),
                        ),
                      if (onShare != null)
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Share'),
                            ],
                          ),
                        ),
                      if (onRename != null)
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Rename'),
                            ],
                          ),
                        ),
                      if (onDelete != null) ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AppColors.error),
                              SizedBox(width: 10),
                              Text('Delete',
                                  style: TextStyle(color: AppColors.error)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

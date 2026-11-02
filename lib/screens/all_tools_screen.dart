import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../utils/app_constants.dart';
import '../utils/tool_router.dart';
import '../widgets/empty_state.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/tool_card.dart';

class AllToolsScreen extends StatefulWidget {
  const AllToolsScreen({super.key});

  @override
  State<AllToolsScreen> createState() => _AllToolsScreenState();
}

class _AllToolsScreenState extends State<AllToolsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';
  String _selectedCategory = 'All';

  final List<String> _categories = const [
    'All',
    'Workflows',
    'Organize PDF',
    'Optimize PDF',
    'Convert PDF',
    'PDF Security',
    'Edit PDF',
    'PDF Intelligence',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTool(BuildContext context, String toolId) {
    ToolRouter.openTool(context, toolId);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = allPdfTools.where((t) {
      final matchesSearch = _searchFilter.isEmpty ||
          t.title.toLowerCase().contains(_searchFilter) ||
          t.description.toLowerCase().contains(_searchFilter);

      final bool matchesCat;
      if (_selectedCategory == 'All') {
        matchesCat = true;
      } else if (_selectedCategory == 'Workflows') {
        matchesCat = t.isWorkflow;
      } else {
        matchesCat = t.category == _selectedCategory;
      }

      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'All PDF Tools (${allPdfTools.length})',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBarWidget(
              controller: _searchController,
              hintText: 'Search all 42 tools (e.g. merge, word, sign)...',
              onChanged: (val) {
                setState(() => _searchFilter = val.trim().toLowerCase());
              },
              onClear: () {
                setState(() => _searchFilter = '');
              },
            ),
            const SizedBox(height: 16),

            // Category filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSel,
                      selectedColor: AppColors.secondary,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                        color:
                            isSel ? AppColors.primary : AppColors.textSecondary,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            if (filtered.isEmpty)
              const EmptyStateWidget(
                icon: Icons.search_off_rounded,
                title: 'No tools found',
                description:
                    'Try choosing another category or clearing your search.',
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.05,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final tool = filtered[index];
                  return ToolCard(
                    tool: tool,
                    onTap: () => _openTool(context, tool.id),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

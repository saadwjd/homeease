import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class ServiceListingScreen extends ConsumerStatefulWidget {
  final String category;
  const ServiceListingScreen({super.key, this.category = ''});

  @override
  ConsumerState<ServiceListingScreen> createState() =>
      _ServiceListingScreenState();
}

class _ServiceListingScreenState extends ConsumerState<ServiceListingScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = '';
  String _sortBy = 'rating'; // 'rating' | 'price_asc' | 'price_desc'
  bool _onlyAvailable = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search providers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Category Chips ─────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: 'All',
                  isSelected: _selectedCategory.isEmpty,
                  onTap: () => setState(() => _selectedCategory = ''),
                ),
                ...['Plumber', 'Electrician', 'Cleaner', 'Painter', 'Carpenter', 'AC Repair']
                    .map((cat) => _CategoryChip(
                          label: cat,
                          isSelected: _selectedCategory == cat,
                          onTap: () =>
                              setState(() => _selectedCategory = cat),
                        )),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Provider List ──────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(firestore).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var docs = snapshot.data?.docs ?? [];

                // Client-side search filter (Firestore doesn't do full-text)
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final skills = List<String>.from(data['skills'] ?? [])
                        .join(' ')
                        .toLowerCase();
                    return name.contains(_searchQuery) ||
                        skills.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        const Text('No providers found',
                            style: AppTextStyles.heading3),
                        const Text('Try a different search or category',
                            style: AppTextStyles.bodySecondary),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _ProviderListCard(
                      providerId: docs[index].id,
                      data: data,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Query _buildQuery(FirebaseFirestore firestore) {
    Query query = firestore.collection('providers');

    if (_onlyAvailable) {
      query = query.where('isAvailable', isEqualTo: true);
    }

    if (_selectedCategory.isNotEmpty) {
      query = query.where('skills', arrayContains: _selectedCategory);
    }

    if (_sortBy == 'rating') {
      query = query.orderBy('rating', descending: true);
    } else if (_sortBy == 'price_asc') {
      query = query.orderBy('hourlyRate', descending: false);
    } else if (_sortBy == 'price_desc') {
      query = query.orderBy('hourlyRate', descending: true);
    }

    return query;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters', style: AppTextStyles.heading3),
                  const SizedBox(height: AppSpacing.md),

                  const Text('Sort by', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Top Rated'),
                        selected: _sortBy == 'rating',
                        onSelected: (_) {
                          setSheetState(() => _sortBy = 'rating');
                          setState(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Price: Low to High'),
                        selected: _sortBy == 'price_asc',
                        onSelected: (_) {
                          setSheetState(() => _sortBy = 'price_asc');
                          setState(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Price: High to Low'),
                        selected: _sortBy == 'price_desc',
                        onSelected: (_) {
                          setSheetState(() => _sortBy = 'price_desc');
                          setState(() {});
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  SwitchListTile(
                    title: const Text('Available now only'),
                    value: _onlyAvailable,
                    onChanged: (val) {
                      setSheetState(() => _onlyAvailable = val);
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: AppSpacing.md),

                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.backgroundLight,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProviderListCard extends StatelessWidget {
  final String providerId;
  final Map<String, dynamic> data;

  const _ProviderListCard({required this.providerId, required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? '';
    final skills = List<String>.from(data['skills'] ?? []);
    final rating = (data['rating'] ?? 0.0).toDouble();
    final reviewCount = data['reviewCount'] ?? 0;
    final hourlyRate = (data['hourlyRate'] ?? 0.0).toDouble();
    final avatarUrl = data['avatarUrl'] as String?;
    final isVerified = data['isVerified'] ?? false;

    return GestureDetector(
      onTap: () => context.go('/provider/$providerId'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primaryLight,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),

              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: AppColors.primary, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skills.join(' · '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Color(0xFFF9AB00), size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${rating.toStringAsFixed(1)} ($reviewCount)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price & arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs.${hourlyRate.toInt()}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Text(
                    'per hour',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

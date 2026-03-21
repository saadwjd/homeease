import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class ProviderProfileScreen extends ConsumerWidget {
  final String providerId;
  const ProviderProfileScreen({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            firestore.collection('providers').doc(providerId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? '';
          final bio = data['bio'] ?? 'No bio provided.';
          final skills = List<String>.from(data['skills'] ?? []);
          final rating = (data['rating'] ?? 0.0).toDouble();
          final reviewCount = data['reviewCount'] ?? 0;
          final hourlyRate = (data['hourlyRate'] ?? 0.0).toDouble();
          final address = data['address'] ?? '';
          final isAvailable = data['isAvailable'] ?? false;
          final isVerified = data['isVerified'] ?? false;
          final avatarUrl = data['avatarUrl'] as String?;
          final experienceYears = data['experienceYears'] ?? 0;

          return CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.serviceListing);
                    }
                  },
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primaryDark, AppColors.primary],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white24,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified,
                                    color: Colors.lightBlueAccent,
                                    size: 18),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.green
                                  : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isAvailable ? 'Available' : 'Unavailable',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats row
                      Row(
                        children: [
                          _StatChip(
                              icon: Icons.star,
                              value: rating.toStringAsFixed(1),
                              label: 'Rating',
                              color: const Color(0xFFF9AB00)),
                          const SizedBox(width: 8),
                          _StatChip(
                              icon: Icons.reviews_outlined,
                              value: '$reviewCount',
                              label: 'Reviews',
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          _StatChip(
                              icon: Icons.workspace_premium_outlined,
                              value: '${experienceYears}yr',
                              label: 'Experience',
                              color: AppColors.accent),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Skills
                      const Text('Services Offered',
                          style: AppTextStyles.heading3),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: skills
                            .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(s,
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ))
                            .toList(),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Bio
                      const Text('About', style: AppTextStyles.heading3),
                      const SizedBox(height: 8),
                      Text(bio, style: AppTextStyles.body),

                      const SizedBox(height: AppSpacing.lg),

                      // Location & Rate
                      _InfoRow(
                          icon: Icons.location_on_outlined,
                          text: address.isNotEmpty
                              ? address
                              : 'Location not specified'),
                      const SizedBox(height: 8),
                      _InfoRow(
                          icon: Icons.payments_outlined,
                          text: 'Rs. ${hourlyRate.toInt()} per hour'),

                      const SizedBox(height: AppSpacing.xl),

                      // Action buttons
                      Row(
                        children: [
                          // Chat button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                context.push(
                                  '/chat/$providerId?name=${Uri.encodeComponent(name)}',
                                );
                              },
                              icon: const Icon(Icons.chat_outlined),
                              label: const Text('Chat'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                    color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Book button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isAvailable
                                  ? () => context
                                      .push('/booking/$providerId')
                                  : null,
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('Book Now'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Reviews section
                      const Text('Reviews', style: AppTextStyles.heading3),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: firestore
                            .collection('reviews')
                            .where('providerId', isEqualTo: providerId)
                            .limit(5)
                            .snapshots(),
                        builder: (context, reviewSnap) {
                          final reviews =
                              reviewSnap.data?.docs ?? [];
                          if (reviews.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No reviews yet.',
                                  style: AppTextStyles.bodySecondary),
                            );
                          }
                          return Column(
                            children: reviews.map((r) {
                              final rd = r.data()
                                  as Map<String, dynamic>;
                              return _ReviewTile(
                                rating:
                                    (rd['rating'] ?? 0.0).toDouble(),
                                comment: rd['comment'] ?? '',
                                userId: rd['userId'] ?? '',
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: AppTextStyles.body)),
      ],
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  final double rating;
  final String comment;
  final String userId;

  const _ReviewTile({
    required this.rating,
    required this.comment,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return FutureBuilder<DocumentSnapshot>(
      future: firestore.collection('users').doc(userId).get(),
      builder: (context, snap) {
        final userName =
            (snap.data?.data() as Map<String, dynamic>?)?['name'] ??
                'User';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        userName.isNotEmpty
                            ? userName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: const Color(0xFFF9AB00),
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(comment, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

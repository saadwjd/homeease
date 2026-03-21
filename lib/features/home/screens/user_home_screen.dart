import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

const List<Map<String, dynamic>> kServiceCategories = [
  {'name': 'Plumber', 'icon': Icons.water_drop, 'color': 0xFF2563EB, 'bg': 0xFFEFF6FF},
  {'name': 'Electrician', 'icon': Icons.bolt, 'color': 0xFFD97706, 'bg': 0xFFFFFBEB},
  {'name': 'Cleaner', 'icon': Icons.cleaning_services, 'color': 0xFF059669, 'bg': 0xFFECFDF5},
  {'name': 'Painter', 'icon': Icons.format_paint, 'color': 0xFFDC2626, 'bg': 0xFFFEF2F2},
  {'name': 'Carpenter', 'icon': Icons.handyman, 'color': 0xFF92400E, 'bg': 0xFFFFFBEB},
  {'name': 'AC Repair', 'icon': Icons.ac_unit, 'color': 0xFF0891B2, 'bg': 0xFFECFEFF},
  {'name': 'Gardener', 'icon': Icons.grass, 'color': 0xFF16A34A, 'bg': 0xFFF0FDF4},
  {'name': 'Security', 'icon': Icons.security, 'color': 0xFF7C3AED, 'bg': 0xFFF5F3FF},
];

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final firstName = userAsync.value?.name.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _PremiumHeader(firstName: firstName)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.serviceListing),
                    child: const Text('See all', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cat = kServiceCategories[index];
                  return _ServiceTile(
                    name: cat['name'] as String,
                    icon: cat['icon'] as IconData,
                    color: Color(cat['color'] as int),
                    bg: Color(cat['bg'] as int),
                    onTap: () => context.go('${AppRoutes.serviceListing}?category=${cat['name']}'),
                  );
                },
                childCount: kServiceCategories.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Top Providers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.serviceListing),
                    child: const Text('See all', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _FeaturedProviders()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: const Text('How It Works', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                children: [
                  _HowItWorksStep(number: '1', title: 'Choose', subtitle: 'Pick a service', color: const Color(0xFF2563EB)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade300)),
                  _HowItWorksStep(number: '2', title: 'Book', subtitle: 'Schedule a time', color: const Color(0xFF7C3AED)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade300)),
                  _HowItWorksStep(number: '3', title: 'Done', subtitle: 'Job completed', color: const Color(0xFF059669)),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  final String firstName;
  const _PremiumHeader({required this.firstName});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -40, right: -30, child: _Bubble(160, 0.06)),
          Positioned(top: 50, right: 70, child: _Bubble(80, 0.05)),
          Positioned(bottom: 40, left: -40, child: _Bubble(130, 0.04)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getGreeting(), style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(firstName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.push(AppRoutes.notifications),
                        child: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('What service do you need today?', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15)),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.serviceListing),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(Icons.search, color: Colors.grey.shade400, size: 22),
                          const SizedBox(width: 10),
                          Text('Search plumber, cleaner...', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                          const Spacer(),
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                            child: const Text('Search', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _Badge(icon: Icons.verified_outlined, label: 'Verified Pros'),
                      const SizedBox(width: 14),
                      _Badge(icon: Icons.flash_on_outlined, label: 'Fast Booking'),
                      const SizedBox(width: 14),
                      _Badge(icon: Icons.star_outline_rounded, label: 'Top Rated'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final double opacity;
  const _Bubble(this.size, this.opacity);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
  );
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: Colors.white.withOpacity(0.8), size: 13),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500)),
  ]);
}

class _ServiceTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _ServiceTile({required this.name, required this.icon, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 7),
            Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _FeaturedProviders extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('providers').where('isAvailable', isEqualTo: true).orderBy('rating', descending: true).limit(10).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No providers yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              Text('Check back soon!', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            ]),
          );
        }
        return SizedBox(
          height: 215,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _ProviderCard(
                providerId: docs[index].id,
                name: data['name'] ?? '',
                skills: List<String>.from(data['skills'] ?? []),
                rating: (data['rating'] ?? 0.0).toDouble(),
                avatarUrl: data['avatarUrl'],
                hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
                reviewCount: data['reviewCount'] ?? 0,
              );
            },
          ),
        );
      },
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String providerId;
  final String name;
  final List<String> skills;
  final double rating;
  final String? avatarUrl;
  final double hourlyRate;
  final int reviewCount;
  const _ProviderCard({required this.providerId, required this.name, required this.skills, required this.rating, this.avatarUrl, required this.hourlyRate, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/provider/$providerId'),
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 76,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)) : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(skills.isNotEmpty ? skills.first : 'Service Pro', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 2),
                    Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    Text(' ($reviewCount)', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ]),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                    child: Text('Rs.${hourlyRate.toInt()}/hr', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final Color color;
  const _HowItWorksStep({required this.number, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Center(child: Text(number, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16))),
          ),
          const SizedBox(height: 7),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

// Admin emails — add yours here
const List<String> kAdminEmails = [
  'saadwajid65@gmail.com',
];

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Users'),
            Tab(icon: Icon(Icons.handyman_outlined, size: 18), text: 'Providers'),
            Tab(icon: Icon(Icons.calendar_today_outlined, size: 18), text: 'Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(firestore: firestore),
          _UsersTab(firestore: firestore),
          _ProvidersTab(firestore: firestore),
          _BookingsTab(firestore: firestore),
        ],
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _OverviewTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Platform Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                label: 'Total Users',
                icon: Icons.people_outline,
                color: AppColors.primary,
                stream: firestore.collection('users').snapshots(),
                getValue: (snap) => snap.docs.length.toString(),
              ),
              _StatCard(
                label: 'Total Providers',
                icon: Icons.handyman_outlined,
                color: AppColors.accent,
                stream: firestore.collection('providers').snapshots(),
                getValue: (snap) => snap.docs.length.toString(),
              ),
              _StatCard(
                label: 'Total Bookings',
                icon: Icons.calendar_today_outlined,
                color: const Color(0xFF9C27B0),
                stream: firestore.collection('bookings').snapshots(),
                getValue: (snap) => snap.docs.length.toString(),
              ),
              _StatCard(
                label: 'Completed Jobs',
                icon: Icons.task_alt,
                color: AppColors.accent,
                stream: firestore
                    .collection('bookings')
                    .where('status', isEqualTo: 'completed')
                    .snapshots(),
                getValue: (snap) => snap.docs.length.toString(),
              ),
              _StatCard(
                label: 'Pending Bookings',
                icon: Icons.hourglass_empty,
                color: AppColors.warning,
                stream: firestore
                    .collection('bookings')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                getValue: (snap) => snap.docs.length.toString(),
              ),
              _StatCard(
                label: 'Total Reviews',
                icon: Icons.star_outline,
                color: const Color(0xFFF9AB00),
                stream: firestore.collection('reviews').snapshots(),
                getValue: (snap) => snap.docs.length.toString(),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text('Recent Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('bookings')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryLight,
                        child: Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                      ),
                      title: Text('${data['serviceType']} booking',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                          '${data['userName']} → ${data['providerName']}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(data['status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['status'] ?? '',
                          style: TextStyle(
                              color: _statusColor(data['status']),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed': return AppColors.primary;
      case 'completed': return AppColors.accent;
      case 'cancelled': return AppColors.error;
      default: return AppColors.warning;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;
  final String Function(QuerySnapshot) getValue;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
    required this.getValue,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.hasData ? getValue(snapshot.data!) : '...';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

// ── Users Tab ────────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _UsersTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unknown';
            final email = data['email'] ?? '';
            final role = data['role'] ?? 'user';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(email,
                    style: const TextStyle(fontSize: 12)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: role == 'provider'
                            ? AppColors.accentLight
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: role == 'provider'
                                ? AppColors.accent
                                : AppColors.primary),
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('MMM d').format(createdAt),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textHint),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Providers Tab ────────────────────────────────────────────────────────
class _ProvidersTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _ProvidersTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('providers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unknown';
            final skills = List<String>.from(data['skills'] ?? []);
            final rating = (data['rating'] ?? 0.0).toDouble();
            final isVerified = data['isVerified'] ?? false;
            final isAvailable = data['isAvailable'] ?? false;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.accentLight,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AppColors.accent, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  color: AppColors.primary, size: 14),
                            ],
                          ]),
                          Text(skills.take(3).join(', '),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Row(children: [
                            const Icon(Icons.star,
                                color: Color(0xFFF9AB00), size: 12),
                            Text(' $rating',
                                style: const TextStyle(fontSize: 12)),
                          ]),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        // Verify toggle
                        GestureDetector(
                          onTap: () {
                            firestore
                                .collection('providers')
                                .doc(docs[index].id)
                                .update({'isVerified': !isVerified});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isVerified
                                  ? AppColors.accentLight
                                  : AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isVerified
                                    ? AppColors.accent
                                    : AppColors.divider,
                              ),
                            ),
                            child: Text(
                              isVerified ? 'Verified ✓' : 'Verify',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isVerified
                                      ? AppColors.accent
                                      : AppColors.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? AppColors.accentLight
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isAvailable ? 'Online' : 'Offline',
                            style: TextStyle(
                                fontSize: 11,
                                color: isAvailable
                                    ? AppColors.accent
                                    : AppColors.textHint),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Bookings Tab ─────────────────────────────────────────────────────────
class _BookingsTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _BookingsTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            Color statusColor = AppColors.warning;
            if (status == 'confirmed') statusColor = AppColors.primary;
            if (status == 'completed') statusColor = AppColors.accent;
            if (status == 'cancelled') statusColor = AppColors.error;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(data['serviceType'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(status,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                        '${data['userName']} → ${data['providerName']}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    Text('Rs. ${(data['totalAmount'] ?? 0).toInt()}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                    if (createdAt != null)
                      Text(DateFormat('MMM d, yyyy').format(createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../auth/providers/auth_provider.dart';
import '../../booking/models/booking_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../support/screens/help_support_screen.dart';
import '../../support/screens/about_screen.dart';

class UserDashboardScreen extends ConsumerStatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  ConsumerState<UserDashboardScreen> createState() =>
      _UserDashboardScreenState();
}

class _UserDashboardScreenState extends ConsumerState<UserDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Account'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline), text: 'Profile'),
            Tab(icon: Icon(Icons.calendar_today_outlined), text: 'Bookings'),
            Tab(icon: Icon(Icons.settings_outlined), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ProfileTab(userId: authUser.uid),
          _BookingsTab(userId: authUser.uid),
          _SettingsTab(userId: authUser.uid),
        ],
      ),
    );
  }
}

// ── Profile Tab ────────────────────────────────────────────────────────────
class _ProfileTab extends ConsumerStatefulWidget {
  final String userId;
  const _ProfileTab({required this.userId});

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto(String userId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final file = File(picked.path);
      final ext = picked.path.split('.').last;
      final fileName = 'avatars/$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/$ext'),
      );
      final url = await uploadTask.ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'avatarUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated!')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        String msg = 'Upload failed.';
        if (e.code == 'unauthorized') {
          msg = 'Permission denied. Check Firebase Storage rules.';
        } else if (e.code == 'object-not-found') {
          msg = 'Storage bucket not found. Check Firebase console.';
        } else {
          msg = 'Upload failed: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('users').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? '';
        final email = data['email'] ?? '';
        final phone = data['phone'] ?? '';
        final address = data['address'] ?? '';
        final avatarUrl = data['avatarUrl'] as String?;

        if (!_isEditing) {
          _nameController.text = name;
          _phoneController.text = phone;
          _addressController.text = address;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: _isUploadingPhoto ? null : () => _pickAndUploadPhoto(widget.userId),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: _isUploadingPhoto
                          ? const CircularProgressIndicator()
                          : avatarUrl == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(name, style: AppTextStyles.heading2),
              Text(email, style: AppTextStyles.bodySecondary),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Personal Info', style: AppTextStyles.heading3),
                  TextButton.icon(
                    onPressed: () async {
                      if (_isEditing) {
                        setState(() => _isSaving = true);
                        final firestore = ref.read(firestoreProvider);
                        await firestore
                            .collection('users')
                            .doc(widget.userId)
                            .update({
                          'name': _nameController.text.trim(),
                          'phone': _phoneController.text.trim(),
                          'address': _addressController.text.trim(),
                        });
                        setState(() {
                          _isSaving = false;
                          _isEditing = false;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated!')),
                          );
                        }
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_isEditing ? Icons.save : Icons.edit, size: 18),
                    label: Text(_isEditing ? 'Save' : 'Edit'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoField(
                label: 'Full Name',
                controller: _nameController,
                icon: Icons.person_outline,
                enabled: _isEditing,
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoField(
                label: 'Phone',
                controller: _phoneController,
                icon: Icons.phone_outlined,
                enabled: _isEditing,
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoField(
                label: 'Address',
                controller: _addressController,
                icon: Icons.location_on_outlined,
                enabled: _isEditing,
                maxLines: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final int maxLines;

  const _InfoField({
    required this.label,
    required this.controller,
    required this.icon,
    this.enabled = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: enabled ? Colors.white : AppColors.backgroundLight,
      ),
    );
  }
}

// ── Bookings Tab ───────────────────────────────────────────────────────────
class _BookingsTab extends ConsumerWidget {
  final String userId;
  const _BookingsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 72, color: AppColors.textHint),
                const SizedBox(height: 16),
                const Text('No bookings yet', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                const Text('Book a service to get started',
                    style: AppTextStyles.bodySecondary),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.serviceListing),
                  child: const Text('Browse Services'),
                ),
              ],
            ),
          );
        }

        final bookings =
            docs.map((d) => BookingModel.fromFirestore(d)).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            return _BookingCard(booking: bookings[index]);
          },
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppColors.warning;
    if (booking.status == BookingStatus.confirmed) statusColor = AppColors.primary;
    if (booking.status == BookingStatus.completed) statusColor = AppColors.accent;
    if (booking.status == BookingStatus.cancelled) statusColor = AppColors.error;

    return GestureDetector(
      onTap: () => context.push('/booking-detail/${booking.id}'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(booking.serviceType,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          booking.status.name,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(booking.providerName, style: AppTextStyles.bodySecondary),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('MMM d, yyyy').format(booking.scheduledDate)} at ${booking.timeSlot}',
                  style: AppTextStyles.bodySecondary,
                ),
              ]),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    booking.isPaid ? '✅ Paid via JazzCash' : '💵 Cash on service',
                    style: TextStyle(
                      fontSize: 12,
                      color: booking.isPaid
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Rs. ${booking.totalAmount.toInt()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings Tab ───────────────────────────────────────────────────────────
class _SettingsTab extends ConsumerWidget {
  final String userId;
  const _SettingsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('providers').doc(userId).snapshots(),
      builder: (context, providerSnap) {
        // Show nothing while loading to avoid flicker
        if (providerSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasProviderProfile = providerSnap.data?.exists ?? false;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const SizedBox(height: AppSpacing.md),

            // ── Switch Profile Banner ──────────────────────────────────
            if (hasProviderProfile)
              // User HAS a provider profile — show switch button
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.swap_horiz, color: Colors.white),
                  ),
                  title: const Text(
                    'Switch to Provider Dashboard',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Manage your service bookings',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 16),
                  onTap: () => context.go(AppRoutes.providerDashboard),
                ),
              )
            else
              // User does NOT have a provider profile — show "Become a Provider"
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.accent,
                    child:
                        Icon(Icons.handyman_outlined, color: Colors.white),
                  ),
                  title: const Text(
                    'Become a Service Provider',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Earn money by offering your skills',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: AppColors.accent, size: 16),
                  onTap: () => context.go(AppRoutes.providerOnboarding),
                ),
              ),

            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'View your notifications',
              onTap: () => context.push(AppRoutes.notifications),
            ),
            _SettingsTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get help with your bookings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              ),
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'About Home Ease',
              subtitle: 'Version 1.0.0',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go(AppRoutes.login);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: onTap,
      ),
    );
  }
}
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
import '../../chat/screens/chat_inbox_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../provider_dashboard/screens/provider_onboarding_screen.dart' show kAvailableServices;

class ProviderHomeScreen extends ConsumerStatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  ConsumerState<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends ConsumerState<ProviderHomeScreen>
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

  Future<void> _switchToUserProfile(BuildContext context) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final firestore = ref.read(firestoreProvider);
    final userDoc = await firestore.collection('users').doc(user.uid).get();
    if (!mounted) return;
    if (userDoc.exists && context.mounted) {
      await firestore.collection('users').doc(user.uid).update({'activeRole': 'user'});
      if (context.mounted) context.go(AppRoutes.userHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) return const SizedBox();
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('providers').doc(authUser.uid).snapshots(),
      builder: (context, providerSnap) {
        final providerData = providerSnap.data?.data() as Map<String, dynamic>? ?? {};
        final isAvailable = providerData['isAvailable'] ?? true;
        final skills = List<String>.from(providerData['skills'] ?? []);

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Dashboard',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (skills.isNotEmpty)
                  Text(
                    skills.join(' • '),
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
            actions: [
              // User View button
              TextButton.icon(
                onPressed: () => _switchToUserProfile(context),
                icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                label: const Text('User View',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
              // Availability toggle with label
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAvailable ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isAvailable ? Colors.greenAccent : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Switch(
                      value: isAvailable,
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.green,
                      inactiveThumbColor: Colors.white60,
                      inactiveTrackColor: Colors.white24,
                      onChanged: (val) async {
                        await firestore
                            .collection('providers')
                            .doc(authUser.uid)
                            .update({'isAvailable': val});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val
                                  ? 'You are now Online — visible to customers'
                                  : 'You are now Offline — hidden from customers'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(icon: Icon(Icons.inbox_outlined, size: 18), text: 'Requests'),
                Tab(icon: Icon(Icons.calendar_today_outlined, size: 18), text: 'Bookings'),
                Tab(icon: Icon(Icons.chat_outlined, size: 18), text: 'Messages'),
                Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Profile'),
              ],
            ),
          ),
          body: Column(
            children: [
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _StatsRow(providerId: authUser.uid),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _RequestsTab(providerId: authUser.uid, skills: skills),
                    _BookingsTab(providerId: authUser.uid),
                    const ChatInboxScreen(),
                    _ProviderProfileTab(
                        providerId: authUser.uid, providerData: providerData),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Stats Row ──────────────────────────────────────────────────────────────
class _StatsRow extends ConsumerWidget {
  final String providerId;
  const _StatsRow({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final pending =
            docs.where((d) => (d.data() as Map)['status'] == 'pending').length;
        final confirmed =
            docs.where((d) => (d.data() as Map)['status'] == 'confirmed').length;
        final earnings = docs
            .where((d) => (d.data() as Map)['status'] == 'completed')
            .fold<double>(
                0,
                (sum, d) =>
                    sum + ((d.data() as Map)['totalAmount'] ?? 0.0).toDouble());

        return Row(
          children: [
            _StatCard(label: 'Pending', value: '$pending', color: AppColors.warning),
            const SizedBox(width: 8),
            _StatCard(label: 'Active', value: '$confirmed', color: Colors.blue),
            const SizedBox(width: 8),
            _StatCard(
                label: 'Earnings',
                value: 'Rs.${earnings.toInt()}',
                color: AppColors.accent),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Requests Tab ───────────────────────────────────────────────────────────
class _RequestsTab extends ConsumerWidget {
  final String providerId;
  final List<String> skills;
  const _RequestsTab({required this.providerId, required this.skills});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 72, color: AppColors.textHint),
                const SizedBox(height: 16),
                const Text('No pending requests', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                const Text('New booking requests will appear here',
                    style: AppTextStyles.bodySecondary),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final booking = BookingModel.fromFirestore(docs[index]);
            return _RequestCard(
              booking: booking,
              onAccept: () async {
                await firestore
                    .collection('bookings')
                    .doc(booking.id)
                    .update({'status': 'confirmed'});
                // Notify user that booking was confirmed
                await firestore.collection('notifications').add({
                  'recipientId': booking.userId,
                  'title': 'Booking Confirmed!',
                  'body':
                      '${booking.providerName} confirmed your ${booking.serviceType} booking on ${DateFormat('MMM d').format(booking.scheduledDate)}.',
                  'isRead': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking accepted!')));
                }
              },
              onDecline: () async {
                await firestore
                    .collection('bookings')
                    .doc(booking.id)
                    .update({'status': 'cancelled'});
                await firestore.collection('notifications').add({
                  'recipientId': booking.userId,
                  'title': 'Booking Declined',
                  'body':
                      'Your ${booking.serviceType} booking was declined. Please try another provider.',
                  'isRead': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              },
            );
          },
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _RequestCard(
      {required this.booking, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(booking.serviceType,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                const Spacer(),
                Text('Rs. ${booking.totalAmount.toInt()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(booking.userName.isNotEmpty ? booking.userName : 'Customer',
                  style: AppTextStyles.bodySecondary),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                  '${DateFormat('MMM d, yyyy').format(booking.scheduledDate)} at ${booking.timeSlot}',
                  style: AppTextStyles.bodySecondary),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(booking.address,
                    style: AppTextStyles.bodySecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            if ((booking.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.note_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(booking.notes ?? '',
                      style: AppTextStyles.bodySecondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error)),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bookings Tab ───────────────────────────────────────────────────────────
class _BookingsTab extends ConsumerWidget {
  final String providerId;
  const _BookingsTab({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .where('status', whereIn: ['pending', 'confirmed', 'inProgress', 'completed'])
          .orderBy('scheduledDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 72, color: AppColors.textHint),
                SizedBox(height: 16),
                Text('No bookings yet', style: AppTextStyles.heading3),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final booking = BookingModel.fromFirestore(docs[index]);
            return _BookingCard(booking: booking, firestore: firestore);
          },
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final FirebaseFirestore firestore;
  const _BookingCard({required this.booking, required this.firestore});

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppColors.primary;
    if (booking.status == BookingStatus.completed) statusColor = AppColors.accent;
    if (booking.status == BookingStatus.inProgress) statusColor = AppColors.warning;
    if (booking.status == BookingStatus.pending) statusColor = AppColors.warning;

    return Card(
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(booking.status.name,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(booking.userName.isNotEmpty ? booking.userName : 'Customer',
                  style: AppTextStyles.bodySecondary),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                  '${DateFormat('MMM d, yyyy').format(booking.scheduledDate)} at ${booking.timeSlot}',
                  style: AppTextStyles.bodySecondary),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(booking.address,
                    style: AppTextStyles.bodySecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rs. ${booking.totalAmount.toInt()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 15)),
                if (booking.status == BookingStatus.confirmed)
                  ElevatedButton(
                    onPressed: () {
                      firestore
                          .collection('bookings')
                          .doc(booking.id)
                          .update({'status': 'completed'});
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(100, 36)),
                    child: const Text('Mark Done'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Provider Profile Tab ───────────────────────────────────────────────────
class _ProviderProfileTab extends ConsumerStatefulWidget {
  final String providerId;
  final Map<String, dynamic> providerData;
  const _ProviderProfileTab({required this.providerId, required this.providerData});

  @override
  ConsumerState<_ProviderProfileTab> createState() => _ProviderProfileTabState();
}

class _ProviderProfileTabState extends ConsumerState<_ProviderProfileTab> {
  final _bioController = TextEditingController();
  final _rateController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _experienceController = TextEditingController();
  bool _isEditing = false;
  bool _isUploadingPhoto = false;
  List<String> _selectedServices = [];
  String _selectedGender = 'Male';

  @override
  void initState() {
    super.initState();
    _loadFromData(widget.providerData);
  }

  void _loadFromData(Map<String, dynamic> data) {
    _bioController.text = data['bio'] ?? '';
    _rateController.text = '${data['hourlyRate'] ?? ''}';
    _addressController.text = data['address'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _ageController.text = '${data['age'] ?? ''}';
    _experienceController.text = '${data['experienceYears'] ?? ''}';
    _selectedServices = List<String>.from(data['skills'] ?? []);
    _selectedGender = data['gender'] ?? 'Male';
  }

  @override
  void dispose() {
    _bioController.dispose();
    _rateController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final file = File(picked.path);
      final ext = picked.path.split('.').last;
      final ref = FirebaseStorage.instance.ref()
          .child('avatars/${widget.providerId}/profile_${DateTime.now().millisecondsSinceEpoch}.$ext');
      final task = await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));
      final url = await task.ref.getDownloadURL();
      final firestore = ref.storage.app.options.projectId.isNotEmpty
          ? FirebaseFirestore.instance : FirebaseFirestore.instance;
      await FirebaseFirestore.instance.collection('providers').doc(widget.providerId).update({'avatarUrl': url});
      await FirebaseFirestore.instance.collection('users').doc(widget.providerId).update({'avatarUrl': url});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);
    final name = widget.providerData['name'] ?? '';
    final rating = (widget.providerData['rating'] ?? 0.0).toDouble();
    final reviewCount = widget.providerData['reviewCount'] ?? 0;
    final avatarUrl = widget.providerData['avatarUrl'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Center(
            child: GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: _isUploadingPhoto
                        ? const CircularProgressIndicator()
                        : avatarUrl == null
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary))
                            : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(name, style: AppTextStyles.heading3)),
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, color: Color(0xFFF9AB00), size: 14),
              const SizedBox(width: 2),
              Text('$rating ($reviewCount reviews)', style: AppTextStyles.bodySecondary),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Details', style: AppTextStyles.heading3),
              TextButton.icon(
                onPressed: () async {
                  if (_isEditing) {
                    await firestore.collection('providers').doc(widget.providerId).update({
                      'bio': _bioController.text.trim(),
                      'hourlyRate': double.tryParse(_rateController.text) ?? 0,
                      'address': _addressController.text.trim(),
                      'phone': _phoneController.text.trim(),
                      'age': int.tryParse(_ageController.text) ?? 0,
                      'experienceYears': int.tryParse(_experienceController.text) ?? 0,
                      'skills': _selectedServices,
                      'gender': _selectedGender,
                    });
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated!')));
                  }
                  setState(() => _isEditing = !_isEditing);
                },
                icon: Icon(_isEditing ? Icons.save : Icons.edit, size: 16),
                label: Text(_isEditing ? 'Save' : 'Edit'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(controller: _phoneController, enabled: _isEditing,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: AppSpacing.md),

          // Gender dropdown
          _isEditing
              ? DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.person_outline)),
                  items: ['Male', 'Female', 'Prefer not to say']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _selectedGender = v!),
                )
              : TextFormField(
                  initialValue: _selectedGender, enabled: false,
                  decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: AppSpacing.md),

          TextFormField(controller: _ageController, enabled: _isEditing,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake_outlined))),
          const SizedBox(height: AppSpacing.md),

          TextFormField(controller: _experienceController, enabled: _isEditing,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Years of Experience',
                prefixIcon: Icon(Icons.workspace_premium_outlined))),
          const SizedBox(height: AppSpacing.md),

          TextFormField(controller: _rateController, enabled: _isEditing,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Hourly Rate (Rs.)',
                prefixIcon: Icon(Icons.payments_outlined))),
          const SizedBox(height: AppSpacing.md),

          TextFormField(controller: _addressController, enabled: _isEditing,
            decoration: const InputDecoration(labelText: 'Service Area',
                prefixIcon: Icon(Icons.location_on_outlined))),
          const SizedBox(height: AppSpacing.md),

          TextFormField(controller: _bioController, enabled: _isEditing, maxLines: 4,
            decoration: const InputDecoration(labelText: 'Bio',
                prefixIcon: Icon(Icons.description_outlined), alignLabelWithHint: true)),
          const SizedBox(height: AppSpacing.lg),

          // Services editing
          const Text('Services Offered', style: AppTextStyles.heading3),
          const SizedBox(height: 8),
          _isEditing
              ? Wrap(
                  spacing: 8, runSpacing: 8,
                  children: kAvailableServices.map((service) {
                    final selected = _selectedServices.contains(service);
                    return FilterChip(
                      label: Text(service), selected: selected,
                      onSelected: (val) => setState(() => val
                          ? _selectedServices.add(service)
                          : _selectedServices.remove(service)),
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                          color: selected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
                    );
                  }).toList(),
                )
              : Wrap(
                  spacing: 8, runSpacing: 6,
                  children: _selectedServices.map((s) => Chip(
                    label: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                    backgroundColor: AppColors.primaryLight,
                  )).toList(),
                ),

          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(double.infinity, 52)),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

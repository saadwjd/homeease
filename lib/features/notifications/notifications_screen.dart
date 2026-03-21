import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    final authUser = ref.watch(authStateProvider).value;

    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              firestore
                  .collection('notifications')
                  .where('recipientId', isEqualTo: authUser.uid)
                  .where('isRead', isEqualTo: false)
                  .get()
                  .then((snapshot) {
                for (final doc in snapshot.docs) {
                  doc.reference.update({'isRead': true});
                }
              });
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('notifications')
            .where('recipientId', isEqualTo: authUser.uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
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
                  Icon(Icons.notifications_none,
                      size: 72, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  const Text('No notifications yet',
                      style: AppTextStyles.heading3),
                  const SizedBox(height: 8),
                  const Text(
                    'Booking updates will appear here',
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final title = data['title'] ?? '';
              final body = data['body'] ?? '';
              final createdAt =
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

              return InkWell(
                onTap: () => docs[index].reference.update({'isRead': true}),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.transparent : AppColors.primaryLight,
                    border: const Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: isRead ? AppColors.divider : _notifColor(data['type']),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _notifIcon(data['type']),
                          color: isRead ? AppColors.textHint : Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(body, style: AppTextStyles.bodySecondary),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, h:mm a').format(createdAt),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _notifIcon(String? type) {
    switch (type) {
      case 'welcome': return Icons.waving_hand;
      case 'tip': return Icons.lightbulb_outline;
      case 'provider_welcome': return Icons.handyman_outlined;
      case 'booking_confirmed': return Icons.check_circle_outline;
      case 'booking_cancelled': return Icons.cancel_outlined;
      case 'booking_completed': return Icons.task_alt;
      default: return Icons.notifications;
    }
  }

  Color _notifColor(String? type) {
    switch (type) {
      case 'welcome': return AppColors.accent;
      case 'tip': return const Color(0xFFF9AB00);
      case 'provider_welcome': return AppColors.accent;
      case 'booking_confirmed': return AppColors.primary;
      case 'booking_cancelled': return AppColors.error;
      case 'booking_completed': return AppColors.accent;
      default: return AppColors.primary;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) return const SizedBox();
    final firestore = ref.watch(firestoreProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('chats')
          .where('participants', arrayContains: authUser.uid)
          .orderBy('lastMessageAt', descending: true)
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
                Icon(Icons.chat_bubble_outline, size: 72, color: AppColors.textHint),
                const SizedBox(height: 16),
                const Text('No messages yet', style: AppTextStyles.heading3),
                const SizedBox(height: 8),
                const Text(
                  'When users message you,\nthey will appear here',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants'] ?? []);
            final otherUserId = participants.firstWhere(
              (id) => id != authUser.uid,
              orElse: () => '',
            );
            // Skip malformed chat docs with no valid other participant
            if (otherUserId.isEmpty) return const SizedBox.shrink();
            final lastMessage = data['lastMessage'] ?? '';
            final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
            final lastSenderId = data['lastSenderId'] ?? '';
            final isUnread = lastSenderId != authUser.uid && lastMessage.isNotEmpty;
            return _InboxTile(
              otherUserId: otherUserId,
              lastMessage: lastMessage,
              lastMessageAt: lastMessageAt,
              isUnread: isUnread,
              currentUserId: authUser.uid,
            );
          },
        );
      },
    );
  }
}

class _InboxTile extends ConsumerWidget {
  final String otherUserId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool isUnread;
  final String currentUserId;

  const _InboxTile({
    required this.otherUserId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.isUnread,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);
    return FutureBuilder<DocumentSnapshot>(
      future: firestore.collection('users').doc(otherUserId).get(),
      builder: (context, snap) {
        final userData = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = userData['name'] ?? 'User';
        final avatarUrl = userData['avatarUrl'] as String?;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              if (isUnread)
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          trailing: lastMessageAt != null
              ? Text(
                  _formatTime(lastMessageAt!),
                  style: TextStyle(
                    fontSize: 11,
                    color: isUnread ? AppColors.primary : AppColors.textHint,
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                )
              : null,
          onTap: () => context.push(
            '/chat/$otherUserId?name=${Uri.encodeComponent(name)}',
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return DateFormat('h:mm a').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }
}

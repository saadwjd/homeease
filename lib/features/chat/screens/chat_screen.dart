import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../auth/providers/auth_provider.dart';
import '../models/chat_message.dart';
import '../../../core/theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isUploading = false;

  Future<void> _sendImageMessage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    await _uploadAndSendFile(File(picked.path), 'image');
  }

  Future<void> _sendCameraImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 70);
    if (picked == null) return;
    await _uploadAndSendFile(File(picked.path), 'image');
  }

  Future<void> _uploadAndSendFile(File file, String type) async {
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) return;

    setState(() => _isUploading = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final chatId = ChatMessage.getChatId(authUser.uid, widget.otherUserId);
      final ext = file.path.split('.').last;
      final fileName = 'chat_media/$chatId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: type == 'image' ? 'image/$ext' : 'application/octet-stream'),
      );
      final url = await uploadTask.ref.getDownloadURL();

      String senderName = 'User';
      final userDoc = await firestore.collection('users').doc(authUser.uid).get();
      if (userDoc.exists) {
        senderName = userDoc.data()?['name'] ?? 'User';
      }

      await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': authUser.uid,
        'senderName': senderName,
        'text': '',
        'mediaUrl': url,
        'mediaType': type,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await firestore.collection('chats').doc(chatId).set({
        'participants': [authUser.uid, widget.otherUserId],
        'lastMessage': type == 'image' ? '📷 Photo' : '📎 File',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': authUser.uid,
        'lastSenderName': senderName,
      }, SetOptions(merge: true));

      _scrollToBottom();
    } on FirebaseException catch (e) {
      if (mounted) {
        String msg = e.code == 'unauthorized'
            ? 'Permission denied. Check Firebase Storage rules.'
            : 'Upload failed: ${e.message}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Send Attachment',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      _sendImageMessage();
                    },
                  ),
                  _AttachOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.pop(context);
                      _sendCameraImage();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Use FirebaseFirestore directly — ref is no longer available in dispose
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      FirebaseFirestore.instance.collection('users').doc(authUser.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
    } else {
      _setOnlineStatus(false);
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) return;
    final firestore = ref.read(firestoreProvider);
    await firestore.collection('users').doc(authUser.uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markMessagesAsRead(String chatId) async {
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) return;
    final firestore = ref.read(firestoreProvider);

    // Mark all messages from the other person as read
    final unread = await firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.otherUserId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final firestore = ref.read(firestoreProvider);
      // IMPORTANT: always sort UIDs the same way so both sides get the same chatId
      final chatId = ChatMessage.getChatId(authUser.uid, widget.otherUserId);

      // Get sender name — check both users and providers collections
      String senderName = 'User';
      final userDoc = await firestore.collection('users').doc(authUser.uid).get();
      if (userDoc.exists) {
        senderName = userDoc.data()?['name'] ?? 'User';
      } else {
        final providerDoc =
            await firestore.collection('providers').doc(authUser.uid).get();
        senderName = providerDoc.data()?['name'] ?? 'Provider';
      }

      // Save message
      await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': authUser.uid,
        'senderName': senderName,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update chat metadata — MUST include both participant UIDs in participants array
      await firestore.collection('chats').doc(chatId).set({
        'participants': [authUser.uid, widget.otherUserId],
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': authUser.uid,
        'lastSenderName': senderName,
      }, SetOptions(merge: true));

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) return const SizedBox();

    final firestore = ref.watch(firestoreProvider);
    final chatId = ChatMessage.getChatId(authUser.uid, widget.otherUserId);

    // Mark messages read when screen is open
    _markMessagesAsRead(chatId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot>(
          // Watch online status from users collection
          stream: firestore.collection('users').doc(widget.otherUserId).snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
            final isOnline = data['isOnline'] ?? false;
            final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();

            String statusText = 'Offline';
            if (isOnline) {
              statusText = 'Online';
            } else if (lastSeen != null) {
              final diff = DateTime.now().difference(lastSeen);
              if (diff.inMinutes < 1) {
                statusText = 'Last seen just now';
              } else if (diff.inHours < 1) statusText = 'Last seen ${diff.inMinutes}m ago';
              else if (diff.inDays < 1) statusText = 'Last seen ${diff.inHours}h ago';
              else statusText = 'Last seen ${DateFormat('MMM d').format(lastSeen)}';
            }

            return Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        widget.otherUserName.isNotEmpty
                            ? widget.otherUserName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.otherUserName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        color: isOnline
                            ? Colors.greenAccent
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
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
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation with\n${widget.otherUserName}',
                          style: AppTextStyles.bodySecondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final messages =
                    docs.map((d) => ChatMessage.fromFirestore(d)).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == authUser.uid;

                    bool showDate = index == 0 ||
                        !_isSameDay(
                            messages[index - 1].createdAt, message.createdAt);

                    // Show "seen" tick only on last message sent by me
                    final isLastFromMe = isMe &&
                        (index == messages.length - 1 ||
                            messages[index + 1].senderId != authUser.uid);

                    return Column(
                      children: [
                        if (showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                DateFormat('MMM d, yyyy')
                                    .format(message.createdAt),
                                style: AppTextStyles.caption,
                              ),
                            ),
                          ),
                        _MessageBubble(
                          message: message,
                          isMe: isMe,
                          showStatus: isLastFromMe,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Attachment button
                  GestureDetector(
                    onTap: _showAttachmentOptions,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: _isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary),
                            )
                          : const Icon(Icons.attach_file,
                              color: AppColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showStatus;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Builder(builder: (_) {
                final hasMedia = (message.mediaUrl ?? '').isNotEmpty;
                final isImage = message.mediaType == 'image';
                if (hasMedia && isImage) {
                  return GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(message.mediaUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      child: Image.network(
                        message.mediaUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 200,
                            height: 150,
                            color: AppColors.primaryLight,
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : AppColors.textHint,
                          ),
                        ),
                        if (isMe && showStatus) ...[
                          const SizedBox(width: 4),
                          _StatusTick(isRead: message.isRead),
                        ],
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _StatusTick extends StatelessWidget {
  final bool isRead;
  const _StatusTick({required this.isRead});

  @override
  Widget build(BuildContext context) {
    if (isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done, size: 12, color: Colors.blue.shade200),
          Transform.translate(
            offset: const Offset(-6, 0),
            child: Icon(Icons.done, size: 12, color: Colors.blue.shade200),
          ),
        ],
      );
    } else {
      return Icon(Icons.done, size: 12, color: Colors.white.withOpacity(0.6));
    }
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

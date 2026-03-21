import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sending, delivered, seen }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? mediaUrl;
  final String? mediaType;
  final DateTime createdAt;
  final bool isRead;
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.mediaUrl,
    this.mediaType,
    required this.createdAt,
    required this.isRead,
    this.status = MessageStatus.delivered,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    MessageStatus status = MessageStatus.delivered;
    if (data['isRead'] == true) status = MessageStatus.seen;

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      mediaUrl: data['mediaUrl'] as String?,
      mediaType: data['mediaType'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      status: status,
    );
  }

  static String getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}

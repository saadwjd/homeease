import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationHelper {
  static Future<void> sendNotification({
    required FirebaseFirestore firestore,
    required String recipientId,
    required String title,
    required String body,
  }) async {
    await firestore.collection('notifications').add({
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Call this when a booking is created
  static Future<void> notifyBookingCreated({
    required FirebaseFirestore firestore,
    required String providerId,
    required String userId,
    required String serviceType,
    required String userName,
    required String scheduledDate,
  }) async {
    // Notify provider
    await sendNotification(
      firestore: firestore,
      recipientId: providerId,
      title: 'New Booking Request!',
      body: '$userName has requested $serviceType on $scheduledDate. Tap to accept.',
    );
    // Notify user
    await sendNotification(
      firestore: firestore,
      recipientId: userId,
      title: 'Booking Submitted!',
      body: 'Your $serviceType request has been sent. Waiting for provider confirmation.',
    );
  }

  // Call this when provider accepts booking
  static Future<void> notifyBookingConfirmed({
    required FirebaseFirestore firestore,
    required String userId,
    required String providerName,
    required String serviceType,
    required String scheduledDate,
  }) async {
    await sendNotification(
      firestore: firestore,
      recipientId: userId,
      title: 'Booking Confirmed!',
      body: '$providerName confirmed your $serviceType booking on $scheduledDate.',
    );
  }

  // Call this when booking is cancelled
  static Future<void> notifyBookingCancelled({
    required FirebaseFirestore firestore,
    required String recipientId,
    required String serviceType,
    required String scheduledDate,
  }) async {
    await sendNotification(
      firestore: firestore,
      recipientId: recipientId,
      title: 'Booking Cancelled',
      body: '$serviceType booking on $scheduledDate has been cancelled.',
    );
  }
}

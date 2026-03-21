import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, confirmed, inProgress, completed, cancelled }

class BookingModel {
  final String id;
  final String userId;
  final String userName;
  final String providerId;
  final String providerName;
  final String serviceType;
  final DateTime scheduledDate;
  final String timeSlot;
  final String address;
  final double totalAmount;
  final BookingStatus status;
  final String? paymentId;
  final bool isPaid;
  final String? notes;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.userId,
    this.userName = '',
    required this.providerId,
    required this.providerName,
    required this.serviceType,
    required this.scheduledDate,
    required this.timeSlot,
    required this.address,
    required this.totalAmount,
    this.status = BookingStatus.pending,
    this.paymentId,
    this.isPaid = false,
    this.notes,
    required this.createdAt,
  });

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      serviceType: data['serviceType'] ?? '',
      scheduledDate:
          (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timeSlot: data['timeSlot'] ?? '',
      address: data['address'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: _statusFromString(data['status']),
      paymentId: data['paymentId'],
      isPaid: data['isPaid'] ?? false,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory BookingModel.fromMap(String id, Map<String, dynamic> data) {
    return BookingModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      serviceType: data['serviceType'] ?? '',
      scheduledDate:
          (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timeSlot: data['timeSlot'] ?? '',
      address: data['address'] ?? '',
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: _statusFromString(data['status']),
      paymentId: data['paymentId'],
      isPaid: data['isPaid'] ?? false,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'providerId': providerId,
      'providerName': providerName,
      'serviceType': serviceType,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'timeSlot': timeSlot,
      'address': address,
      'totalAmount': totalAmount,
      'status': _statusToString(status),
      'paymentId': paymentId,
      'isPaid': isPaid,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static BookingStatus _statusFromString(String? s) {
    switch (s) {
      case 'confirmed': return BookingStatus.confirmed;
      case 'inProgress': return BookingStatus.inProgress;
      case 'completed': return BookingStatus.completed;
      case 'cancelled': return BookingStatus.cancelled;
      default: return BookingStatus.pending;
    }
  }

  static String _statusToString(BookingStatus s) {
    switch (s) {
      case BookingStatus.confirmed: return 'confirmed';
      case BookingStatus.inProgress: return 'inProgress';
      case BookingStatus.completed: return 'completed';
      case BookingStatus.cancelled: return 'cancelled';
      default: return 'pending';
    }
  }

  BookingModel copyWith({BookingStatus? status, bool? isPaid, String? paymentId}) {
    return BookingModel(
      id: id,
      userId: userId,
      userName: userName,
      providerId: providerId,
      providerName: providerName,
      serviceType: serviceType,
      scheduledDate: scheduledDate,
      timeSlot: timeSlot,
      address: address,
      totalAmount: totalAmount,
      status: status ?? this.status,
      paymentId: paymentId ?? this.paymentId,
      isPaid: isPaid ?? this.isPaid,
      notes: notes,
      createdAt: createdAt,
    );
  }
}
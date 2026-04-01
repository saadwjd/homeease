import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/booking_model.dart';
import '../../../core/theme/app_theme.dart';
import 'rating_screen.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _isLoading = false;

  Future<void> _cancelBooking(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('bookings').doc(widget.bookingId).update({'status': 'cancelled'});
      await firestore.collection('notifications').add({
        'recipientId': booking.providerId,
        'title': 'Booking Cancelled',
        'body': '${booking.serviceType} booking on ${DateFormat('MMM d').format(booking.scheduledDate)} was cancelled.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('bookings').doc(widget.bookingId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final booking = BookingModel.fromMap(widget.bookingId, data);
          Color statusColor = AppColors.warning;
          if (booking.status == BookingStatus.confirmed) statusColor = AppColors.primary;
          if (booking.status == BookingStatus.completed) statusColor = AppColors.accent;
          if (booking.status == BookingStatus.cancelled) statusColor = AppColors.error;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(_statusIcon(booking.status), color: statusColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_statusTitle(booking.status), style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(_statusSubtitle(booking.status), style: TextStyle(color: statusColor.withOpacity(0.8), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(title: 'Service Details', children: [
                  _DetailRow(icon: Icons.build_outlined, label: 'Service', value: booking.serviceType),
                  _DetailRow(icon: Icons.person_outline, label: 'Provider', value: booking.providerName),
                  _DetailRow(icon: Icons.calendar_today_outlined, label: 'Date', value: DateFormat('EEEE, MMM d, yyyy').format(booking.scheduledDate)),
                  _DetailRow(icon: Icons.access_time_outlined, label: 'Time', value: booking.timeSlot),
                  _DetailRow(icon: Icons.location_on_outlined, label: 'Address', value: booking.address),
                  if ((booking.notes ?? '').isNotEmpty)
                    _DetailRow(icon: Icons.notes_outlined, label: 'Notes', value: booking.notes ?? ''),
                ]),
                const SizedBox(height: 16),
                _SectionCard(title: 'Payment', children: [
                  _DetailRow(icon: Icons.payments_outlined, label: 'Amount', value: 'Rs. ${booking.totalAmount.toInt()}', valueColor: AppColors.primary),
                  _DetailRow(
                    icon: booking.isPaid ? Icons.check_circle_outline : Icons.money_outlined,
                    label: 'Status',
                    value: booking.isPaid ? 'Paid via JazzCash' : 'Cash on service',
                    valueColor: booking.isPaid ? AppColors.accent : null,
                  ),
                ]),
                if (booking.status == BookingStatus.confirmed || booking.status == BookingStatus.pending) ...[
                  const SizedBox(height: 20),
                  const Text('Contact Provider', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.chat_outlined, label: 'Chat', color: AppColors.primary,
                          onTap: () => context.push('/chat/${booking.providerId}?name=${Uri.encodeComponent(booking.providerName)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.phone_outlined, label: 'Call', color: AppColors.accent,
                          onTap: () async {
                            final providerDoc = await firestore.collection('providers').doc(booking.providerId).get();
                            final phone = providerDoc.data()?['phone'] ?? '';
                            if (phone.isNotEmpty) {
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) launchUrl(uri);
                            } else {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provider phone not available')));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _cancelBooking(booking),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error), minimumSize: const Size(double.infinity, 50)),
                      icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Booking'),
                    ),
                  ),
                ],
                // Rate button for completed bookings
                if (booking.status == BookingStatus.completed) ...[ 
                  const SizedBox(height: 20),
                  FutureBuilder<DocumentSnapshot>(
                    future: firestore.collection('bookings').doc(widget.bookingId).get(),
                    builder: (context, snap) {
                      final isReviewed = (snap.data?.data() as Map<String, dynamic>?)?['isReviewed'] ?? false;
                      if (isReviewed) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.accent),
                              SizedBox(width: 10),
                              Text('You\'ve reviewed this service',
                                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }
                      return ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RatingScreen(
                                bookingId: widget.bookingId,
                                providerId: booking.providerId,
                                providerName: booking.providerName,
                                serviceType: booking.serviceType,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Rate This Service'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF9AB00),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _statusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending: return Icons.hourglass_empty;
      case BookingStatus.confirmed: return Icons.check_circle_outline;
      case BookingStatus.inProgress: return Icons.play_circle_outline;
      case BookingStatus.completed: return Icons.task_alt;
      case BookingStatus.cancelled: return Icons.cancel_outlined;
    }
  }

  String _statusTitle(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending: return 'Awaiting Confirmation';
      case BookingStatus.confirmed: return 'Booking Confirmed!';
      case BookingStatus.inProgress: return 'Service In Progress';
      case BookingStatus.completed: return 'Service Completed';
      case BookingStatus.cancelled: return 'Booking Cancelled';
    }
  }

  String _statusSubtitle(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending: return 'Waiting for provider to accept';
      case BookingStatus.confirmed: return 'Provider has accepted your booking';
      case BookingStatus.inProgress: return 'Your service is currently ongoing';
      case BookingStatus.completed: return 'Thank you for using Home Ease!';
      case BookingStatus.cancelled: return 'This booking has been cancelled';
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.heading3),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor ?? AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}

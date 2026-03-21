import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class BookingConfirmationScreen extends ConsumerWidget {
  final String bookingId;
  const BookingConfirmationScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreProvider);

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('bookings').doc(bookingId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final isPaid = data['isPaid'] ?? false;
          final providerName = data['providerName'] ?? '';
          final serviceType = data['serviceType'] ?? '';
          final timeSlot = data['timeSlot'] ?? '';
          final address = data['address'] ?? '';
          final amount = (data['totalAmount'] ?? 0.0).toDouble();

          DateTime scheduledDate = DateTime.now();
          if (data['scheduledDate'] != null) {
            scheduledDate = (data['scheduledDate'] as dynamic).toDate();
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.xl),

                  // Success icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.accent,
                      size: 64,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  const Text('Booking Confirmed!', style: AppTextStyles.heading1),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isPaid
                        ? 'Payment successful via JazzCash'
                        : 'Cash payment on service',
                    style: AppTextStyles.bodySecondary,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.person_outline,
                            label: 'Provider',
                            value: providerName,
                          ),
                          _DetailRow(
                            icon: Icons.build_outlined,
                            label: 'Service',
                            value: serviceType,
                          ),
                          _DetailRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Date',
                            value: DateFormat('EEEE, MMM d, yyyy')
                                .format(scheduledDate),
                          ),
                          _DetailRow(
                            icon: Icons.access_time,
                            label: 'Time',
                            value: timeSlot,
                          ),
                          _DetailRow(
                            icon: Icons.location_on_outlined,
                            label: 'Address',
                            value: address,
                          ),
                          const Divider(),
                          _DetailRow(
                            icon: Icons.payments_outlined,
                            label: 'Amount',
                            value: 'Rs. ${amount.toInt()}',
                            valueStyle: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  Text(
                    'Booking ID: $bookingId',
                    style: AppTextStyles.caption,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.userHome),
                      child: const Text('Back to Home'),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.userDashboard),
                      child: const Text('View My Bookings'),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

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
                Text(
                  value,
                  style: valueStyle ?? AppTextStyles.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
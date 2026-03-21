import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/models/booking_model.dart';
import '../../../core/theme/app_theme.dart';

const List<String> kTimeSlots = [
  '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
  '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM',
  '4:00 PM', '5:00 PM', '6:00 PM',
];

class BookingScreen extends ConsumerStatefulWidget {
  final String providerId;
  const BookingScreen({super.key, required this.providerId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime _selectedDay = DateTime.now().add(const Duration(days: 1));
  String? _selectedTimeSlot;
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String _paymentMethod = 'jazzcash'; // 'jazzcash' | 'cash'

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking(Map<String, dynamic> providerData) async {
    if (_selectedTimeSlot == null) {
      _showSnack('Please select a time slot', isError: true);
      return;
    }
    if (_addressController.text.isEmpty) {
      _showSnack('Please enter your service address', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = ref.read(firestoreProvider);
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null) throw Exception('Not logged in');

      final hourlyRate = (providerData['hourlyRate'] ?? 0.0).toDouble();

      final booking = BookingModel(
        id: '',
        userId: currentUser.uid,
        providerId: widget.providerId,
        providerName: providerData['name'] ?? '',
        serviceType: List<String>.from(providerData['skills'] ?? []).isNotEmpty
            ? providerData['skills'][0]
            : 'Home Service',
        scheduledDate: _selectedDay,
        timeSlot: _selectedTimeSlot!,
        address: _addressController.text.trim(),
        totalAmount: hourlyRate,
        isPaid: false,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Write booking to Firestore
      final docRef = await firestore
          .collection('bookings')
          .add(booking.toFirestore());

      // If JazzCash, simulate payment flow
      if (_paymentMethod == 'jazzcash') {
        await _processJazzCashPayment(docRef.id, hourlyRate);
      } else {
        // Cash — booking confirmed directly
        await docRef.update({'status': 'confirmed'});
      }

      if (mounted) {
        context.go('/booking-confirmation/${docRef.id}');
      }
    } catch (e) {
      _showSnack('Booking failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── JazzCash Integration ─────────────────────────────────────────────────
  // In a real app, you would call the JazzCash REST API from a Firebase Function.
  // The device sends booking details → your Firebase Function signs the request
  // with your JazzCash merchant credentials → JazzCash returns a payment URL.
  // Here we simulate that flow with a dialog.
  Future<void> _processJazzCashPayment(String bookingId, double amount) async {
    // Show payment dialog simulating JazzCash
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _JazzCashPaymentDialog(
        amount: amount,
        bookingId: bookingId,
      ),
    );

    if (confirmed == true) {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('bookings').doc(bookingId).update({
        'status': 'confirmed',
        'isPaid': true,
        'paymentId': 'JC-${DateTime.now().millisecondsSinceEpoch}',
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Book Service')),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            firestore.collection('providers').doc(widget.providerId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final providerData =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final hourlyRate = (providerData['hourlyRate'] ?? 0.0).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Provider Info ────────────────────────────────────────
                _ProviderSummaryCard(data: providerData),

                const SizedBox(height: AppSpacing.lg),

                // ── Date Picker ──────────────────────────────────────────
                const Text('Select Date', style: AppTextStyles.heading3),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: TableCalendar(
                    firstDay: DateTime.now(),
                    lastDay: DateTime.now().add(const Duration(days: 60)),
                    focusedDay: _selectedDay,
                    selectedDayPredicate: (day) =>
                        isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() => _selectedDay = selectedDay);
                    },
                    calendarStyle: const CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(color: AppColors.primary),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Time Slots ───────────────────────────────────────────
                const Text('Select Time', style: AppTextStyles.heading3),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kTimeSlots.map((slot) {
                    final isSelected = _selectedTimeSlot == slot;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTimeSlot = slot),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.backgroundLight,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.divider,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slot,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Address ──────────────────────────────────────────────
                const Text('Service Address', style: AppTextStyles.heading3),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Enter your full address...',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ── Notes ────────────────────────────────────────────────
                const Text('Additional Notes (optional)',
                    style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue or add any details...',
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Payment Method ───────────────────────────────────────
                const Text('Payment Method', style: AppTextStyles.heading3),
                const SizedBox(height: AppSpacing.sm),
                _PaymentMethodSelector(
                  selected: _paymentMethod,
                  onChanged: (val) => setState(() => _paymentMethod = val),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Price Summary ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount',
                          style: AppTextStyles.heading3),
                      Text(
                        'Rs. ${hourlyRate.toInt()}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Confirm Button ───────────────────────────────────────
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _confirmBooking(providerData),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _paymentMethod == 'jazzcash'
                              ? 'Pay with JazzCash'
                              : 'Confirm Booking (Cash)',
                        ),
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProviderSummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProviderSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: data['avatarUrl'] != null
                  ? NetworkImage(data['avatarUrl'])
                  : null,
              child: data['avatarUrl'] == null
                  ? Text(
                      (data['name'] ?? 'P')[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  List<String>.from(data['skills'] ?? []).join(', '),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Rs.${(data['hourlyRate'] ?? 0).toInt()}/hr',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PaymentMethodSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaymentOption(
          value: 'jazzcash',
          label: 'JazzCash',
          subtitle: 'Pay securely via JazzCash mobile account',
          icon: Icons.phone_android,
          iconColor: const Color(0xFFEB2127),
          selected: selected,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        _PaymentOption(
          value: 'cash',
          label: 'Cash on Service',
          subtitle: 'Pay in cash when service is completed',
          icon: Icons.money,
          iconColor: AppColors.accent,
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String selected;
  final ValueChanged<String> onChanged;

  const _PaymentOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight
              : AppColors.backgroundLight,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: selected,
              onChanged: (v) => onChanged(v!),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── JazzCash Payment Dialog ────────────────────────────────────────────────
class _JazzCashPaymentDialog extends StatefulWidget {
  final double amount;
  final String bookingId;

  const _JazzCashPaymentDialog(
      {required this.amount, required this.bookingId});

  @override
  State<_JazzCashPaymentDialog> createState() => _JazzCashPaymentDialogState();
}

class _JazzCashPaymentDialogState extends State<_JazzCashPaymentDialog> {
  final _mobileController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEB2127).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_android,
                color: Color(0xFFEB2127), size: 20),
          ),
          const SizedBox(width: 10),
          const Text('JazzCash Payment'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount to pay'),
                Text(
                  'Rs. ${widget.amount.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'JazzCash Mobile Number',
              hintText: '03XX-XXXXXXX',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'JazzCash PIN',
              prefixIcon: Icon(Icons.lock_outline),
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A payment request will be sent to your JazzCash account.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEB2127),
            minimumSize: const Size(120, 44),
          ),
          onPressed: _isProcessing
              ? null
              : () async {
                  setState(() => _isProcessing = true);
                  // Simulate API call delay
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) Navigator.pop(context, true);
                },
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('Pay Now', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

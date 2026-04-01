import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String providerId;
  final String providerName;
  final String serviceType;

  const RatingScreen({
    super.key,
    required this.bookingId,
    required this.providerId,
    required this.providerName,
    required this.serviceType,
  });

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      final firestore = ref.read(firestoreProvider);

      // Save review
      await firestore.collection('reviews').add({
        'providerId': widget.providerId,
        'userId': user.uid,
        'bookingId': widget.bookingId,
        'rating': _rating.toDouble(),
        'comment': _commentController.text.trim(),
        'serviceType': widget.serviceType,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update booking as reviewed
      await firestore.collection('bookings').doc(widget.bookingId).update({
        'isReviewed': true,
      });

      // Recalculate provider average rating
      final reviews = await firestore
          .collection('reviews')
          .where('providerId', isEqualTo: widget.providerId)
          .get();

      if (reviews.docs.isNotEmpty) {
        final total = reviews.docs.fold<double>(
          0,
          (sum, doc) => sum + ((doc.data()['rating'] ?? 0.0) as num).toDouble(),
        );
        final avg = total / reviews.docs.length;
        await firestore.collection('providers').doc(widget.providerId).update({
          'rating': double.parse(avg.toStringAsFixed(1)),
          'reviewCount': reviews.docs.length,
        });
      }

      // Send notification to provider
      await firestore.collection('notifications').add({
        'recipientId': widget.providerId,
        'title': 'New Review Received! ⭐',
        'body': 'You received a ${_rating}-star review for ${widget.serviceType}.',
        'type': 'review',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted! Thank you.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Provider info
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                widget.providerName.isNotEmpty
                    ? widget.providerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.providerName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.serviceType,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 40),

            // Star rating
            const Text(
              'How was your experience?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _ratingLabel(),
              style: TextStyle(
                fontSize: 14,
                color: _rating > 0 ? AppColors.primary : AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: index < _rating
                          ? const Color(0xFFF9AB00)
                          : AppColors.textHint,
                      size: 48,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Write a review (optional)',
                hintText:
                    'Share your experience with this provider...',
                alignLabelWithHint: true,
                filled: true,
                fillColor: AppColors.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quick tags
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Quick tags',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Professional',
                'On time',
                'Good value',
                'Friendly',
                'Quality work',
                'Would recommend',
              ].map((tag) {
                return GestureDetector(
                  onTap: () {
                    final current = _commentController.text;
                    if (!current.contains(tag)) {
                      _commentController.text =
                          current.isEmpty ? tag : '$current, $tag';
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      '+ $tag',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Submit Review',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Skip for now',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel() {
    switch (_rating) {
      case 1:
        return 'Poor — Not satisfied';
      case 2:
        return 'Fair — Below expectations';
      case 3:
        return 'Good — Met expectations';
      case 4:
        return 'Very Good — Exceeded expectations';
      case 5:
        return 'Excellent — Outstanding service!';
      default:
        return 'Tap a star to rate';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hero banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.support_agent, color: Colors.white, size: 48),
                SizedBox(height: 12),
                Text(
                  'How can we help you?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Our support team is available\nSun–Thu, 9 AM – 6 PM (PKT)',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const Text(
            'Contact Us',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Contact options
          _ContactTile(
            icon: Icons.email_outlined,
            color: AppColors.primary,
            title: 'Email Support',
            subtitle: 'support@homeease.pk',
            onTap: () => _launch('mailto:support@homeease.pk?subject=HomeEase%20Support'),
          ),
          _ContactTile(
            icon: Icons.phone_outlined,
            color: AppColors.accent,
            title: 'Call Us',
            subtitle: '+92 316 7635243',
            onTap: () => _launch('tel:+923167635243'),
          ),
          _ContactTile(
            icon: Icons.chat_outlined,
            color: const Color(0xFF25D366),
            title: 'WhatsApp',
            subtitle: 'Chat with us on WhatsApp',
            onTap: () => _launch('https://wa.me/923167635243?text=Hi%20HomeEase%20Support'),
          ),

          const SizedBox(height: 28),
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _FaqTile(
            question: 'How do I book a service?',
            answer:
                'Browse services, select a provider, choose a date and time, then confirm your booking. You\'ll receive a confirmation notification once the provider accepts.',
          ),
          _FaqTile(
            question: 'How do I cancel a booking?',
            answer:
                'Go to My Account → Bookings, tap on the booking you want to cancel, and select "Cancel Booking". Cancellations must be made at least 2 hours before the scheduled time.',
          ),
          _FaqTile(
            question: 'How are providers verified?',
            answer:
                'All providers go through an ID verification and background check process by the HomeEase team before their profiles go live.',
          ),
          _FaqTile(
            question: 'What payment methods are accepted?',
            answer:
                'We currently support JazzCash and cash on service. More payment methods are coming soon.',
          ),
          _FaqTile(
            question: 'How do I become a service provider?',
            answer:
                'Go to My Account → Settings → Become a Service Provider. Fill in your details, select your services, and submit. Our team will review and verify your profile.',
          ),

          const SizedBox(height: 28),
          const Text(
            'Report a Problem',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _ContactTile(
            icon: Icons.bug_report_outlined,
            color: AppColors.warning,
            title: 'Report a Bug',
            subtitle: 'Found an issue? Let us know',
            onTap: () => _launch(
                'mailto:bugs@homeease.pk?subject=Bug%20Report%20-%20HomeEase%20App'),
          ),
          _ContactTile(
            icon: Icons.flag_outlined,
            color: AppColors.error,
            title: 'Report a Provider',
            subtitle: 'Report inappropriate behaviour',
            onTap: () => _launch(
                'mailto:safety@homeease.pk?subject=Provider%20Report%20-%20HomeEase'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: onTap,
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(Icons.help_outline, color: AppColors.primary, size: 20),
        title: Text(
          widget.question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        children: [
          Text(widget.answer,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
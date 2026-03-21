import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About HomeEase'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: BackButton(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App branding
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.home_repair_service,
                      color: AppColors.primary, size: 48),
                ),
                const SizedBox(height: 14),
                const Text(
                  'HomeEase',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Version 1.0.0 (Build 1)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connecting homeowners with trusted,\nverified service professionals.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const _SectionHeader('Legal'),

          _AboutTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _launch('https://homeease-3e717.web.app'),
          ),
          _AboutTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => _launch('https://homeease-3e717.web.app'),
          ),
          _AboutTile(
            icon: Icons.gavel_outlined,
            title: 'User Agreement',
            onTap: () => _launch('https://homeease-3e717.web.app'),
          ),
          _AboutTile(
            icon: Icons.handyman_outlined,
            title: 'Provider Agreement',
            onTap: () => _launch('https://homeease-3e717.web.app'),
          ),
          _AboutTile(
            icon: Icons.cookie_outlined,
            title: 'Cookie Policy',
            onTap: () => _launch('https://homeease-3e717.web.app'),
          ),

          const SizedBox(height: 20),
          const _SectionHeader('Data & Permissions'),

          // Inline data usage card
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'What data we collect',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  _DataItem(
                    icon: Icons.person_outline,
                    text: 'Name, email, and phone number for account creation',
                  ),
                  _DataItem(
                    icon: Icons.location_on_outlined,
                    text: 'Location to show nearby providers (only when app is in use)',
                  ),
                  _DataItem(
                    icon: Icons.photo_camera_outlined,
                    text: 'Photos from your gallery only when you choose to upload',
                  ),
                  _DataItem(
                    icon: Icons.notifications_outlined,
                    text: 'Push notification token to send booking updates',
                  ),
                  _DataItem(
                    icon: Icons.lock_outline,
                    text: 'All data is encrypted and never sold to third parties',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const _SectionHeader('Open Source'),

          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This app is built using open-source software. Tap below to view the full list of licenses.',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'HomeEase',
                        applicationVersion: '1.0.0',
                        applicationLegalese:
                            '© 2024 HomeEase. All rights reserved.',
                      );
                    },
                    icon: const Icon(Icons.source_outlined, size: 18),
                    label: const Text('View Open Source Licenses'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const _SectionHeader('Company'),

          _AboutTile(
            icon: Icons.business_outlined,
            title: 'HomeEase Technologies (Pvt.) Ltd.',
            subtitle: 'Lahore, Pakistan',
            onTap: null,
          ),
          _AboutTile(
            icon: Icons.email_outlined,
            title: 'Contact',
            subtitle: 'support@homeease.pk',
            onTap: () => _launch('mailto:support@homeease.pk'),
          ),
          _AboutTile(
            icon: Icons.language_outlined,
            title: 'Website',
            subtitle: 'homeease-3e717.web.app',
            onTap: () => _launch('https://homeease-3e717.web.app'),
          ),

          const SizedBox(height: 28),
          const Center(
            child: Text(
              '© 2024 HomeEase Technologies (Pvt.) Ltd.\nAll rights reserved.',
              style: TextStyle(
                  color: AppColors.textHint, fontSize: 11, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _AboutTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12))
            : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: AppColors.textHint)
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _DataItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DataItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}
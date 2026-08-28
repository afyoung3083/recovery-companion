import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_components.dart';
import 'mobile_config.dart';

class PrivacyHealthInfoScreen extends StatelessWidget {
  const PrivacyHealthInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppPageHeader(
          title: 'Privacy & Health Information',
          subtitle: 'How Recovery Companion handles your recovery information and the limits of this app.',
          icon: Icons.health_and_safety_outlined,
        ),

        const AppSectionTitle(
          title: 'Published privacy policy',
          subtitle:
              'Read the current public Recovery Companion privacy policy.',
        ),

        AppSectionCard(
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('open-public-privacy-policy'),
              onPressed: () async {
                final uri = Uri.parse(MobileConfig.privacyPolicyUrl);

                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Public Privacy Policy'),
            ),
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Purpose',
          subtitle: 'Recovery support, not medical care.',
        ),

        const AppSectionCard(
          child: Column(
            children: [
              _PolicyRow(
                icon: Icons.favorite_outline,
                title: 'Recovery support',
                text: 'Recovery Companion provides tools for addiction recovery, reflection, routines, goals, fellowship, and personal recovery planning.',
              ),
              SizedBox(height: 18),
              _PolicyRow(
                icon: Icons.medical_information_outlined,
                title: 'Not a medical device',
                text: 'Recovery Companion is not a medical device and does not diagnose, treat, cure, or prevent any disease or medical condition.',
              ),
              SizedBox(height: 18),
              _PolicyRow(
                icon: Icons.person_outline,
                title: 'Professional care',
                text: 'The app does not replace a physician, licensed mental-health professional, therapist, sponsor, clergy member, or other qualified professional.',
              ),
              SizedBox(height: 18),
              _PolicyRow(
                icon: Icons.emergency_outlined,
                title: 'Not an emergency service',
                text: 'Recovery Companion is not an emergency or crisis-response service. If you or someone else may be in immediate danger, contact local emergency or crisis services.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Your recovery data',
          subtitle: 'Local-first by design.',
        ),

        const AppSectionCard(
          child: Column(
            children: [
              _PolicyRow(
                icon: Icons.phone_android_outlined,
                title: 'Stored on your device',
                text: 'Core recovery records are authoritative on your device and are stored in Recovery Companion local application storage.',
              ),
              SizedBox(height: 18),
              _PolicyRow(
                icon: Icons.lock_outline,
                title: 'Protected locally',
                text: 'Recovery Companion uses encrypted local storage for authoritative recovery data and disables Android application backup.',
              ),
              SizedBox(height: 18),
              _PolicyRow(
                icon: Icons.download_outlined,
                title: 'Export and deletion',
                text: 'You can prepare an export of Recovery Companion recovery records or permanently delete Recovery Companion-owned recovery data from Settings & Privacy.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'When information leaves your device',
          subtitle: 'Only for features that require an online service.',
        ),

        const AppSectionCard(
          child: Column(
            children: [
              _PolicyRow(
                icon: Icons.auto_awesome_outlined,
                title: 'AI reflections',
                text: 'Recovery information is sent for AI reflection only after you explicitly request an AI-powered reflection.',
              ),
              SizedBox(height: 18),
              _PolicyRow(
                icon: Icons.chat_bubble_outline,
                title: 'Companion chat',
                text: 'When you use Recovery Companion chat, the current conversation is transmitted so the service can respond in context.',
              ),
              SizedBox(height: 18),
              _PolicyRow(
                icon: Icons.cloud_off_outlined,
                title: 'No automatic recovery-record upload',
                text: 'Core recovery records are not automatically uploaded merely because you save or view them locally.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'AI limitations',
          subtitle: 'Use human judgment and real relationships.',
        ),

        const AppSectionCard(
          child: Column(
            children: [
              _PolicyRow(
                icon: Icons.warning_amber_outlined,
                title: 'AI can be wrong',
                text: 'AI-generated responses may be incomplete, inaccurate, or inappropriate for your circumstances.',
              ),
              SizedBox(height: 18),
              _PolicyRow(
                icon: Icons.groups_outlined,
                title: 'People come first',
                text: 'Use Recovery Companion to support, not replace, fellowship, professional care, trusted relationships, and your own judgment.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(text),
            ],
          ),
        ),
      ],
    );
  }
}

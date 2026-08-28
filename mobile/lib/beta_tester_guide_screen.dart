import 'package:flutter/material.dart';

import 'app_components.dart';
import 'mobile_config.dart';

class BetaTesterGuideScreen extends StatelessWidget {
  const BetaTesterGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppPageHeader(
          title: 'Closed Beta Tester Guide',
          subtitle: 'What to test, how to protect your privacy, and how to send useful feedback.',
          icon: Icons.science_outlined,
        ),

        const AppSectionTitle(
          title: 'You are testing a beta',
          subtitle: 'Expect rough edges and help us find them.',
        ),

        const AppSectionCard(
          child: Column(
            children: [
              _GuideRow(
                icon: Icons.info_outline,
                title: 'Beta software',
                text: 'This build is being tested before broader release. Features may change and bugs may still exist.',
              ),
              SizedBox(height: 18),
              _GuideRow(
                icon: Icons.build_outlined,
                title: 'Current build',
                text: 'Your beta diagnostics identify the installed Recovery Companion build so problems can be reproduced.',
              ),
              SizedBox(height: 18),
              _GuideRow(
                icon: Icons.update_outlined,
                title: 'Keep the app updated',
                text: 'Install beta updates when they become available so testing stays focused on the latest build.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'What we need you to test',
          subtitle: 'Use the app normally, but pay attention to these areas.',
        ),

        const AppSectionCard(
          child: Column(
            children: [
              _GuideRow(
                icon: Icons.login_outlined,
                title: 'First use',
                text: 'Try onboarding and setup. Note anything unclear, repetitive, or difficult to understand.',
              ),
              SizedBox(height: 18),
              _GuideRow(
                icon: Icons.check_circle_outline,
                title: 'Daily recovery',
                text: 'Use check-ins, journal, goals, routines, fellowship, and reminders as you normally would.',
              ),
              SizedBox(height: 18),
              _GuideRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Optional AI features',
                text: 'Try AI reflection or chat only when you choose to. Note responses that are confusing, unhelpful, or inappropriate.',
              ),
              SizedBox(height: 18),
              _GuideRow(
                icon: Icons.sync_outlined,
                title: 'Updates',
                text: 'After an app update, confirm your existing local recovery records and onboarding state are still present.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Protect your privacy',
          subtitle:
              'Beta feedback should not expose recovery details unnecessarily.',
        ),

        const AppSectionCard(
          child: Column(
            children: [
              _GuideRow(
                icon: Icons.lock_outline,
                title: 'Recovery records are sensitive',
                text: 'Do not paste journal entries, Step Work, chat text, names, or other sensitive recovery details into a bug report unless they are essential to understanding the problem.',
              ),
              SizedBox(height: 18),
              _GuideRow(
                icon: Icons.copy_outlined,
                title: 'Use safe diagnostics',
                text: 'Beta Feedback & Support can generate technical diagnostics without including authoritative recovery records, journal text, chat text, or API tokens.',
              ),
              SizedBox(height: 18),
              _GuideRow(
                icon: Icons.visibility_outlined,
                title: 'Review before sending',
                text: 'Read every feedback report before sending it and remove anything you do not want shared with the beta team.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Useful feedback',
          subtitle: 'Specific reports are much easier to reproduce.',
        ),

        const AppSectionCard(
          child: Column(
            children: [
              _GuideRow(
                icon: Icons.bug_report_outlined,
                title: 'Tell us what happened',
                text: 'Describe what you saw, what you expected, and the steps that led to the problem.',
              ),
              SizedBox(height: 18),
              _GuideRow(
                icon: Icons.touch_app_outlined,
                title: 'Usability matters too',
                text: 'Report screens, labels, workflows, or instructions that feel confusing even when nothing technically breaks.',
              ),
              SizedBox(height: 18),
              _GuideRow(
                icon: Icons.lightbulb_outline,
                title: 'Suggestions are welcome',
                text: 'Explain the recovery problem your idea would solve rather than only describing a feature.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(title: 'Beta build'),

        const AppSectionCard(
          child: _GuideRow(
            icon: Icons.phone_android_outlined,
            title: 'Recovery Companion',
            text: 'Build ${MobileConfig.betaBuildLabel}',
          ),
        ),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_components.dart';
import 'mobile_config.dart';

String betaPlatformLabel() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
}

String betaBuildModeLabel() {
  if (kReleaseMode) {
    return 'release';
  }

  if (kProfileMode) {
    return 'profile';
  }

  return 'debug';
}

String buildBetaDiagnostics({
  required String platform,
  required String buildMode,
}) {
  return [
    'Recovery Companion beta diagnostics',
    'App version: ${MobileConfig.betaBuildLabel}',
    'Platform: $platform',
    'Build mode: $buildMode',
    '',
    'Privacy note:',
    'This diagnostic block does not include recovery records, '
        'journal entries, chat text, API tokens, or other '
        'authoritative recovery data.',
  ].join('\n');
}

String buildBetaFeedbackReport({
  required String feedbackType,
  required String summary,
  required String expected,
  required String steps,
  required String diagnostics,
}) {
  final cleanSummary = summary.trim();
  final cleanExpected = expected.trim();
  final cleanSteps = steps.trim();

  return [
    'Recovery Companion Beta Feedback',
    '',
    'Type: $feedbackType',
    '',
    'What happened?',
    cleanSummary.isEmpty ? '(not provided)' : cleanSummary,
    '',
    'What did you expect?',
    cleanExpected.isEmpty ? '(not provided)' : cleanExpected,
    '',
    'Steps to reproduce / additional details:',
    cleanSteps.isEmpty ? '(not provided)' : cleanSteps,
    '',
    '---',
    diagnostics,
  ].join('\n');
}

class BetaFeedbackScreen extends StatefulWidget {
  const BetaFeedbackScreen({super.key});

  @override
  State<BetaFeedbackScreen> createState() => _BetaFeedbackScreenState();
}

class _BetaFeedbackScreenState extends State<BetaFeedbackScreen> {
  final TextEditingController _summaryController = TextEditingController();

  final TextEditingController _expectedController = TextEditingController();

  final TextEditingController _stepsController = TextEditingController();

  String _feedbackType = 'Bug';
  String? _statusMessage;

  String get _diagnostics {
    return buildBetaDiagnostics(
      platform: betaPlatformLabel(),
      buildMode: betaBuildModeLabel(),
    );
  }

  String get _report {
    return buildBetaFeedbackReport(
      feedbackType: _feedbackType,
      summary: _summaryController.text,
      expected: _expectedController.text,
      steps: _stepsController.text,
      diagnostics: _diagnostics,
    );
  }

  Future<void> _copyReport() async {
    await Clipboard.setData(ClipboardData(text: _report));

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage =
          'Beta report copied. Paste it into the '
          'support channel, issue, email, or message '
          'you are using with the beta team.';
    });
  }

  Future<void> _copyDiagnostics() async {
    await Clipboard.setData(ClipboardData(text: _diagnostics));

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = 'Safe diagnostic information copied.';
    });
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _expectedController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppPageHeader(
          title: 'Beta Feedback & Support',
          subtitle: 'Report a problem or tell us what would make the app more useful.',
          icon: Icons.bug_report_outlined,
        ),

        if (_statusMessage != null) ...[
          AppStatusMessage(
            title: _statusMessage!,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 20),
        ],

        const AppSectionTitle(
          title: 'Tell us what happened',
          subtitle: 'Do not include sensitive recovery details unless they are essential to explaining the problem.',
        ),

        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('beta-feedback-type'),
                initialValue: _feedbackType,
                decoration: const InputDecoration(labelText: 'Feedback type'),
                items: const [
                  DropdownMenuItem(
                    value: 'Bug',
                    child: Text('Bug / something broke'),
                  ),
                  DropdownMenuItem(
                    value: 'Usability',
                    child: Text('Confusing or hard to use'),
                  ),
                  DropdownMenuItem(
                    value: 'Suggestion',
                    child: Text('Suggestion / idea'),
                  ),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _feedbackType = value;
                  });
                },
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('beta-feedback-summary'),
                controller: _summaryController,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  hintText:
                      'Example: I tapped Save and the screen did not change.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('beta-feedback-expected'),
                controller: _expectedController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What did you expect?',
                  hintText:
                      'Example: I expected the entry to appear immediately.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('beta-feedback-steps'),
                controller: _stepsController,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Steps or additional details',
                  hintText:
                      '1. Open Journal\n'
                      '2. Add an entry\n'
                      '3. Tap Save\n'
                      '4. Describe what happened',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        const AppSectionTitle(
          title: 'Safe diagnostics',
          subtitle: 'Technical context helps reproduce bugs without attaching your recovery records.',
        ),

        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DiagnosticRow(
                label: 'App version',
                value: MobileConfig.betaBuildLabel,
              ),
              const SizedBox(height: 10),
              _DiagnosticRow(label: 'Platform', value: betaPlatformLabel()),
              const SizedBox(height: 10),
              _DiagnosticRow(label: 'Build mode', value: betaBuildModeLabel()),
              const SizedBox(height: 16),
              Text(
                'Not included: recovery records, '
                'journal text, chat text, API tokens, '
                'or other private recovery content.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('copy-beta-diagnostics'),
                  onPressed: _copyDiagnostics,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy Diagnostics Only'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('copy-beta-report'),
            onPressed: _copyReport,
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Copy Complete Beta Report'),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Copying places this report on your '
          'system clipboard until it is replaced.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    );
  }
}

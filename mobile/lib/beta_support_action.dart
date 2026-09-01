import 'package:flutter/material.dart';

import 'beta_feedback_screen.dart';
import 'beta_tester_guide_screen.dart';

enum BetaSupportDestination { testerGuide, feedback }

Future<void> openBetaSupportDestination(
  BuildContext context,
  BetaSupportDestination destination,
) async {
  late final String title;
  late final Widget screen;

  switch (destination) {
    case BetaSupportDestination.testerGuide:
      title = 'Closed Beta Tester Guide';
      screen = const BetaTesterGuideScreen();
      break;

    case BetaSupportDestination.feedback:
      title = 'Beta Feedback & Support';
      screen = const BetaFeedbackScreen();
      break;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: screen,
      ),
    ),
  );
}

class BetaSupportAction extends StatelessWidget {
  const BetaSupportAction({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BetaSupportDestination>(
      key: const ValueKey('beta-support-action'),
      tooltip: 'Beta help and feedback',
      position: PopupMenuPosition.under,
      onSelected: (destination) async {
        await openBetaSupportDestination(context, destination);
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem<BetaSupportDestination>(
            key: ValueKey('beta-support-tester-guide'),
            value: BetaSupportDestination.testerGuide,
            child: Row(
              children: [
                Icon(Icons.science_outlined),
                SizedBox(width: 12),
                Flexible(
                  child: Text('Tester Guide', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          PopupMenuItem<BetaSupportDestination>(
            key: ValueKey('beta-support-feedback'),
            value: BetaSupportDestination.feedback,
            child: Row(
              children: [
                Icon(Icons.bug_report_outlined),
                SizedBox(width: 12),
                Flexible(
                  child: Text('Send Feedback', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ];
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.science_outlined),
            SizedBox(width: 6),
            Text('Beta', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

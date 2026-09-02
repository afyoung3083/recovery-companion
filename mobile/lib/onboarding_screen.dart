import 'package:flutter/material.dart';

import 'beta_support_action.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();

  int _page = 0;
  bool _finishing = false;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.favorite_outline,
      title: 'Recovery support for real life',
      body:
          'Recovery Companion helps you reflect, build consistent '
          'recovery practices, and identify the next right thing. '
          'It supports your recovery relationships; it does not '
          'replace your sponsor, fellowship, therapist, clergy, '
          'or Higher Power.',
    ),
    _OnboardingPageData(
      icon: Icons.shield_outlined,
      title: 'Your recovery data stays with you',
      body:
          'Your authoritative recovery records are stored encrypted '
          'on this device. Normal recovery features continue to work '
          'without a connection.',
    ),
    _OnboardingPageData(
      icon: Icons.psychology_outlined,
      title: 'You control what AI sees',
      body:
          'AI features run only when you explicitly request them. '
          'The app sends only the specific entry or locally prepared '
          'summary needed for that request?not your entire recovery '
          'history.',
    ),
    _OnboardingPageData(
      icon: Icons.route_outlined,
      title: 'Start with today',
      body:
          'You do not need to configure everything at once. Begin '
          'with Daily Recovery, add goals and routines when useful, '
          'and let the app grow with your recovery practice.',
    ),
  ];

  Future<void> _next() async {
    if (_page < _pages.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_finishing) {
      return;
    }

    setState(() {
      _finishing = true;
    });

    try {
      await widget.onComplete();
    } finally {
      if (mounted) {
        setState(() {
          _finishing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      key: const ValueKey('first-run-onboarding'),
      body: SafeArea(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(top: 4, right: 8),
                child: BetaSupportAction(),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) {
                  setState(() {
                    _page = value;
                  });
                },
                itemBuilder: (context, index) {
                  return _OnboardingPage(
                    data: _pages[index],
                    pageNumber: index + 1,
                    pageCount: _pages.length,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        key: ValueKey('onboarding-dot-$index'),
                        width: index == _page ? 22 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: index == _page
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('onboarding-next'),
                      onPressed: _finishing ? null : _next,
                      icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
                      label: Text(
                        _finishing
                            ? 'Starting...'
                            : isLast
                            ? 'Start Recovery Companion'
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.pageNumber,
    required this.pageCount,
  });

  final _OnboardingPageData data;
  final int pageNumber;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(
              data.icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 28),
          Text(
            '$pageNumber of $pageCount',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

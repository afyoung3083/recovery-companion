import 'package:flutter/material.dart';

import 'initial_setup_screen.dart';
import 'initial_setup_service.dart';
import 'onboarding_screen.dart';
import 'onboarding_store.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    required this.child,
    this.store,
    this.initialSetupService,
    super.key,
  });

  final Widget child;
  final OnboardingStore? store;
  final InitialSetupService? initialSetupService;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final OnboardingStore _store;

  bool? _complete;
  bool _showInitialSetup = false;
  Object? _error;

  @override
  void initState() {
    super.initState();

    _store = widget.store ?? OnboardingStore();

    OnboardingStore.changes.addListener(_handleOnboardingStoreChanged);

    _load();
  }

  @override
  void dispose() {
    OnboardingStore.changes.removeListener(_handleOnboardingStoreChanged);

    super.dispose();
  }

  void _handleOnboardingStoreChanged() {
    _load(resetFlow: true);
  }

  Future<void> _load({bool resetFlow = false}) async {
    try {
      final complete = await _store.isComplete();

      if (!mounted) {
        return;
      }

      setState(() {
        _complete = complete;
        _error = null;

        if (resetFlow && !complete) {
          _showInitialSetup = false;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
      });
    }
  }

  Future<void> _openInitialSetup() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _showInitialSetup = true;
    });
  }

  Future<void> _finishSetup(InitialSetupDraft draft) async {
    final service =
        widget.initialSetupService ?? await InitialSetupService.openDefault();

    await service.apply(draft);
    await _markComplete();
  }

  Future<void> _skipSetup() async {
    await _markComplete();
  }

  Future<void> _markComplete() async {
    await _store.markComplete();

    if (!mounted) {
      return;
    }

    setState(() {
      _complete = true;
      _showInitialSetup = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to start Recovery Companion.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_complete == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_complete == true) {
      return widget.child;
    }

    if (_showInitialSetup) {
      return InitialSetupScreen(onFinish: _finishSetup, onSkip: _skipSetup);
    }

    return OnboardingScreen(onComplete: _openInitialSetup);
  }
}

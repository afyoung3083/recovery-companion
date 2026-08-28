import 'package:flutter/material.dart';

import 'onboarding_screen.dart';
import 'onboarding_store.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({required this.child, this.store, super.key});

  final Widget child;
  final OnboardingStore? store;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final OnboardingStore _store;

  bool? _complete;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? OnboardingStore();
    _load();
  }

  Future<void> _load() async {
    try {
      final complete = await _store.isComplete();

      if (!mounted) {
        return;
      }

      setState(() {
        _complete = complete;
        _error = null;
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

  Future<void> _completeOnboarding() async {
    await _store.markComplete();

    if (!mounted) {
      return;
    }

    setState(() {
      _complete = true;
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

    return OnboardingScreen(onComplete: _completeOnboarding);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_components.dart';
import 'package:mobile/app_theme.dart';

void main() {
  test('AppTheme provides Recovery Companion design defaults', () {
    final theme = AppTheme.light();

    expect(theme.useMaterial3, isTrue);

    expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);

    expect(theme.cardTheme.elevation, 0);

    expect(theme.navigationBarTheme.height, 72);
  });

  testWidgets('shared page header renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppPageHeader(
            title: 'Daily Recovery',
            subtitle: 'Focus on the next right thing.',
            icon: Icons.favorite_outline,
          ),
        ),
      ),
    );

    expect(find.text('Daily Recovery'), findsOneWidget);

    expect(find.text('Focus on the next right thing.'), findsOneWidget);

    expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
  });

  testWidgets('shared status message supports retry action', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppStatusMessage(
            title: 'Unable to load',
            message: 'Try again.',
            icon: Icons.cloud_off_outlined,
            actionLabel: 'Retry',
            onAction: () {
              pressed = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Retry'));

    expect(pressed, isTrue);
  });
}

import 'package:beat_the_bot/core/theme.dart';
import 'package:beat_the_bot/widgets/celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the celebration shows its text and closes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showCelebration(
                  context,
                  title: 'RANK UP',
                  badge: 'ELITE',
                  subtitle: 'You are now ELITE. Zed noticed.',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('RANK UP'), findsOneWidget);
    expect(find.text('ELITE'), findsOneWidget);
    expect(find.textContaining('Zed noticed'), findsOneWidget);

    await tester.pumpAndSettle(); // lets the confetti finish
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('RANK UP'), findsNothing);
  });
}

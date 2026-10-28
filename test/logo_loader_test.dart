import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquagas/widgets/logo_loader.dart';

void main() {
  testWidgets('LogoLoader animates without layout errors at several sizes',
      (tester) async {
    for (final size in [64.0, 104.0, 200.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: LogoLoader(size: size, label: 'Loading…')),
        ),
      ));
      // Step through a few seconds of the loop (letters flip, wave ripples,
      // shine sweeps). pumpAndSettle would never finish: it repeats forever.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(LogoLoader), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    // Tear down so the repeating controller is disposed.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

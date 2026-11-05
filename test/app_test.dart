import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:seed_stash/main.dart';

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    testWidgets('native shell on $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await tester.pumpWidget(const SeedStashApp());
        expect(find.text('Your packet library starts here.'), findsOneWidget);
        switch (platform) {
          case TargetPlatform.iOS:
            expect(find.byType(CupertinoApp), findsOneWidget);
            expect(find.byType(MaterialApp), findsNothing);
          case TargetPlatform.windows:
            expect(find.byType(fluent.FluentApp), findsOneWidget);
            expect(find.byType(MaterialApp), findsNothing);
          case TargetPlatform.android:
            expect(find.byType(MaterialApp), findsOneWidget);
            expect(find.byType(CupertinoApp), findsNothing);
          default:
            fail('unexpected platform');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}

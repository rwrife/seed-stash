import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;

void main() => runApp(const SeedStashApp());

class SeedStashApp extends StatelessWidget {
  const SeedStashApp({super.key});

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const CupertinoApp(
          title: 'Seed Stash',
          home: CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(middle: Text('Seed Stash')),
            child: SafeArea(
              child: Center(child: Text('Your packet library starts here.')),
            ),
          ),
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return fluent.FluentApp(
          title: 'Seed Stash',
          home: fluent.NavigationView(
            titleBar: const fluent.TitleBar(title: Text('Seed Stash')),
            content: const fluent.Center(
              child: Text('Your packet library starts here.'),
            ),
          ),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return material.MaterialApp(
          title: 'Seed Stash',
          home: material.Scaffold(
            appBar: material.AppBar(title: const material.Text('Seed Stash')),
            body: const material.Center(
              child: material.Text('Your packet library starts here.'),
            ),
          ),
        );
    }
  }
}

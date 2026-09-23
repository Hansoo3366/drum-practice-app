import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/piano_app.dart';
import 'package:page_a_diddle/app/theme/app_system_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSystemUi.restoreAppChrome(Brightness.light);
  runApp(const ProviderScope(child: PianoApp()));
}

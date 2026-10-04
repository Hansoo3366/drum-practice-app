import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/piano_app.dart';
import 'package:page_a_diddle/app/product.dart';
import 'package:page_a_diddle/app/theme/app_system_ui.dart';
import 'package:page_a_diddle/core/platform/stall_watch.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  isPianoProduct = true;
  await AppSystemUi.restoreAppChrome(Brightness.light);
  watchForStalls();
  runApp(const ProviderScope(child: PianoApp()));
}

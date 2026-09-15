import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/app_state.dart';
import 'core/native_bridge.dart';
import 'services/update_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  final state = await AppState.boot();

  // Paint the first frame, then refresh content + reminders in the background.
  runApp(VSystemApp(state: state));
  unawaited(_afterFirstFrame(state));
}

Future<void> _afterFirstFrame(AppState st) async {
  await WidgetsBinding.instance.endOfFrame;
  try {
    await Reminders.apply(st);
  } catch (_) {}

  // Auto-sync the content file at most once every 6 hours.
  final last = st.lastSyncAt;
  final stale = last == null ||
      DateTime.now().difference(last) > const Duration(hours: 6);
  if (stale) {
    try {
      await st.syncContent();
    } catch (_) {}
  }

  // Once a day, quietly check whether a newer APK was published.
  try {
    await UpdateChecker.maybeNotify(st);
  } catch (_) {}
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/app_state.dart';
import 'core/native_bridge.dart';
import 'services/prayer_service.dart';
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

  // Prayer-time notifications: re-arms the 7-day batch (no-op without a city).
  try {
    await Prayers.apply(st);
  } catch (_) {}

  // Bring the home-screen widget up to date (no-op when it is not installed).
  try {
    await st.refreshWidget();
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

  // Quietly check for a newer APK: every 6 h normally, every 20 h while an
  // update is already pending (see UpdateChecker).
  try {
    await UpdateChecker.maybeNotify(st);
  } catch (_) {}
}

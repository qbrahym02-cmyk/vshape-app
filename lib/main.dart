import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/app_state.dart';
import 'core/native_bridge.dart';
import 'services/exercise_images.dart';
import 'services/prayer_service.dart';
import 'services/update_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  final state = await AppState.boot();

  // Coming back from the home screen: a widget tap may have changed the water
  // counter in the shared preferences, so re-read it and repaint the widget.
  WidgetsBinding.instance.addObserver(_ResumeRefresh(state));

  // Paint the first frame, then refresh content + reminders in the background.
  runApp(VSystemApp(state: state));
  unawaited(_afterFirstFrame(state));
}

/// Keeps the UI honest after the home-screen widget wrote to the same store.
class _ResumeRefresh with WidgetsBindingObserver {
  _ResumeRefresh(this.st);
  final AppState st;

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) return;
    st.noteBestStreak();
    st.ping();
    st.refreshWidget();
  }
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

  // Make the exercise-photo cache readable synchronously from build().
  try {
    await ExerciseImages.prime();
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

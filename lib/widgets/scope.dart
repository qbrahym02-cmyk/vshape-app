import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/l10n.dart';

/// Provides [AppState] to the whole tree and rebuilds on every change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope not found in the widget tree');
    return s!.notifier!;
  }

  /// Reads the state without subscribing to rebuilds.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension L10nX on BuildContext {
  AppState get st => AppScope.of(this);
  L10n get l10n => L10n(AppScope.of(this).isArabic);
  bool get isAr => AppScope.of(this).isArabic;
}

void snack(BuildContext context, String msg, {Color? color}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: const Duration(milliseconds: 2200),
    ),
  );
}

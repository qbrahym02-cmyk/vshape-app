import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native_bridge.dart';
import '../core/theme.dart';
import 'common.dart';
import 'scope.dart';

/// Count-down for the 90-second rest between sets.
///
/// Lives above the tabs (an [Overlay] entry owned by [RestTimerScope]) so it
/// keeps running while you switch between Today / Water / Training.
class RestTimerController extends ChangeNotifier {
  Timer? _ticker;
  DateTime? _endsAt;
  int _total = 0;
  int _left = 0;
  bool _paused = false;
  String? _label;
  bool _arabic = true;

  int get total => _total;
  int get left => _left;
  bool get running => _total > 0;
  bool get paused => _paused;
  String? get label => _label;
  double get progress => _total == 0 ? 0 : (1 - _left / _total).clamp(0.0, 1.0);

  /// Starts (or restarts) the countdown. [label] is shown next to the seconds,
  /// e.g. the exercise name. [arabic] localises the "rest is over"
  /// notification.
  void start(int seconds, {String? label, bool? arabic}) {
    final s = seconds.clamp(5, 3600);
    if (arabic != null) _arabic = arabic;
    _total = s;
    _left = s;
    _label = label;
    _paused = false;
    _endsAt = DateTime.now().add(Duration(seconds: s));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    notifyListeners();
  }

  void add(int seconds) {
    if (!running) return;
    _total += seconds;
    _left += seconds;
    if (!_paused && _endsAt != null) {
      _endsAt = _endsAt!.add(Duration(seconds: seconds));
    }
    notifyListeners();
  }

  void togglePause() {
    if (!running) return;
    if (_paused) {
      _paused = false;
      _endsAt = DateTime.now().add(Duration(seconds: _left));
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    } else {
      _paused = true;
      _ticker?.cancel();
    }
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _total = 0;
    _left = 0;
    _paused = false;
    _label = null;
    notifyListeners();
  }

  void _tick() {
    final end = _endsAt;
    if (end == null || _paused) return;
    final left = end.difference(DateTime.now()).inMilliseconds;
    final nowLeft = (left / 1000).ceil();
    if (nowLeft != _left) {
      _left = nowLeft < 0 ? 0 : nowLeft;
      notifyListeners();
    }
    if (left <= 0) {
      _ticker?.cancel();
      _ticker = null;
      _total = 0;
      _left = 0;
      _label = null;
      notifyListeners();
      _announceDone();
    }
  }

  /// Sound + vibration + a notification, so "rest is over" is noticed even
  /// with the phone face down on the floor.
  Future<void> _announceDone() async {
    HapticFeedback.heavyImpact();
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    await Native.vibrate(600);
    await Native.notify(
      id: 9101,
      title: '⏱️ V-System',
      body: _arabic ? 'خلصت الراحة — المجموعة الجاية 💪' : 'Rest is over - next set 💪',
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Puts a [RestTimerController] in the tree and renders the floating bar.
class RestTimerScope extends StatefulWidget {
  const RestTimerScope({super.key, required this.child});

  final Widget child;

  static RestTimerController of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<_InheritedRestTimer>();
    assert(s != null, 'RestTimerScope not found in the widget tree');
    return s!.controller;
  }

  /// Null instead of throwing - for widgets that may be pumped outside a shell.
  static RestTimerController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InheritedRestTimer>()?.controller;

  @override
  State<RestTimerScope> createState() => _RestTimerScopeState();
}

class _RestTimerScopeState extends State<RestTimerScope> {
  final RestTimerController controller = RestTimerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedRestTimer(
      controller: controller,
      child: widget.child,
    );
  }
}

class _InheritedRestTimer extends InheritedWidget {
  const _InheritedRestTimer({required this.controller, required super.child});

  final RestTimerController controller;

  @override
  bool updateShouldNotify(_InheritedRestTimer old) => old.controller != controller;
}

/// The floating countdown card. Render it wherever it should appear
/// (HomeShell parks it above the navigation bar); it is empty while idle.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({super.key, required this.controller});

  final RestTimerController controller;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.running) return const SizedBox.shrink();
        final left = controller.left;
        final t = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Material(
            color: C.surface2,
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.violet.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: controller.progress,
                          strokeWidth: 4,
                          backgroundColor: C.violet.withValues(alpha: 0.18),
                          valueColor: const AlwaysStoppedAnimation(C.violet),
                        ),
                        Text(
                          '$left',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14, color: C.violet),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          st.isArabic ? 'راحة بين المجموعات' : 'Rest between sets',
                          style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (controller.label != null)
                          Text(
                            controller.label!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.add(30),
                    child: const Text('+30', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: controller.paused
                        ? (st.isArabic ? 'متابعة' : 'Resume')
                        : (st.isArabic ? 'إيقاف مؤقت' : 'Pause'),
                    onPressed: controller.togglePause,
                    icon: Icon(controller.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded),
                  ),
                  IconButton(
                    tooltip: st.isArabic ? 'تخطي' : 'Skip',
                    onPressed: controller.stop,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tappable "rest" chip: starts the countdown for this exercise.
class RestPill extends StatelessWidget {
  const RestPill({super.key, required this.seconds, this.label});

  final int seconds;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final st = context.st;
    final c = RestTimerScope.maybeOf(context);
    return GestureDetector(
      onTap: c == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              c.start(seconds, label: label, arabic: st.isArabic);
            },
      child: Pill(
        '${seconds}${l.seconds} ${l.rest} ⏱',
        color: C.blue,
        icon: Icons.timer_outlined,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../screens/food_screen.dart';
import '../screens/more_screen.dart';
import '../screens/today_screen.dart';
import '../screens/training_screen.dart';
import '../screens/water_screen.dart';
import '../widgets/scope.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();

  /// Lets other screens jump to a tab (e.g. "open today's workout").
  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  static void goTo(BuildContext context, int index) => of(context)?.go(index);
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  void go(int i) {
    if (!mounted) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final l = context.l10n;
    final t = Theme.of(context);

    final pages = [
      TodayScreen(key: const PageStorageKey('today'), onOpenWorkout: () => go(3)),
      const WaterScreen(key: PageStorageKey('water')),
      const FoodScreen(key: PageStorageKey('food')),
      const TrainingScreen(key: PageStorageKey('training')),
      const MoreScreen(key: PageStorageKey('more')),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (st.pendingUpdate != null) _UpdateStrip(onTap: () => go(4)),
          Container(height: 1, color: t.dividerColor.withValues(alpha: 0.5)),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.today_rounded),
                label: l.today,
              ),
              NavigationDestination(
                icon: const Icon(Icons.water_drop_outlined),
                selectedIcon: const Icon(Icons.water_drop, color: C.cyan),
                label: l.water,
              ),
              NavigationDestination(
                icon: const Icon(Icons.restaurant_outlined),
                selectedIcon: const Icon(Icons.restaurant, color: C.orange),
                label: l.food,
              ),
              NavigationDestination(
                icon: const Icon(Icons.fitness_center_outlined),
                selectedIcon: const Icon(Icons.fitness_center, color: C.violet),
                label: l.training,
              ),
              NavigationDestination(
                icon: const Icon(Icons.more_horiz_rounded),
                label: l.more,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpdateStrip extends StatelessWidget {
  const _UpdateStrip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = context.st;
    final info = st.pendingUpdate;
    if (info == null) return const SizedBox.shrink();
    return Material(
      color: C.green.withValues(alpha: 0.14),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.system_update_rounded, size: 18, color: C.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  st.isArabic
                      ? 'فيه نسخة جديدة من التطبيق: ${info.versionName} — اضغط للتحديث'
                      : 'New app version available: ${info.versionName} - tap to update',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'widgets/rest_timer.dart';
import 'widgets/scope.dart';

class VSystemApp extends StatelessWidget {
  const VSystemApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final isAr = state.isArabic;
          return MaterialApp(
            title: 'V-System',
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            locale: state.locale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                  // App-level so the rest countdown survives tab switches and
                  // pushed routes (Progress, Rules, Settings...).
                  child: RestTimerScope(child: child ?? const SizedBox.shrink()),
                ),
              );
            },
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}

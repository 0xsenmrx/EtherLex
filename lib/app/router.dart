import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion/spring_value.dart';
import '../core/motion/springs.dart';
import '../design_system/theme/ether_theme.dart';
import '../features/activity/presentation/activity_page.dart';
import '../features/assignments/presentation/assignments_page.dart';
import '../features/auth/domain/auth_provider.dart';
import '../features/auth/presentation/setup_page.dart';
import '../features/calendar/presentation/calendar_page.dart';
import '../features/files/presentation/files_page.dart';
import '../features/grades/presentation/grades_page.dart';
import 'shell/app_shell.dart';

final SpringCurve _slideCurve = SpringCurve(Springs.smooth);

CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondary, child) {
      final fadeIn = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = CurvedAnimation(parent: animation, curve: _slideCurve);
      final fadeOut = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: secondary, curve: const Interval(0, 0.6, curve: Curves.easeIn)),
      );
      return FadeTransition(
        opacity: fadeOut,
        child: FadeTransition(
          opacity: fadeIn,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.018), end: Offset.zero).animate(slide),
            child: child,
          ),
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/assignments',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      final signedIn = auth.value != null;
      if (!signedIn) return loc == '/setup' ? null : '/setup';
      if (loc == '/setup' || loc == '/splash') return '/assignments';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const _Splash(),
        ),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (context, state) => _page(state, const SetupPage()),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/assignments',
            pageBuilder: (context, state) => _page(state, const AssignmentsPage()),
          ),
          GoRoute(
            path: '/activity',
            pageBuilder: (context, state) => _page(state, const ActivityPage()),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => _page(state, const CalendarPage()),
          ),
          GoRoute(
            path: '/grades',
            pageBuilder: (context, state) => _page(state, const GradesPage()),
          ),
          GoRoute(
            path: '/files',
            pageBuilder: (context, state) => _page(state, const FilesPage()),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.colors.canvas);
}

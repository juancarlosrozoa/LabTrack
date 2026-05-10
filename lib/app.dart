import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'shared/router/app_router.dart';

class LabTrackApp extends ConsumerWidget {
  const LabTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authEventListenerProvider); // keep auth-event listener alive
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'LabTrack',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

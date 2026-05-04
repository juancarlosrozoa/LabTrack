import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/remote/supabase_client.dart';
import '../../features/auth/providers/lab_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/lab_picker_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/product_detail_screen.dart';
import '../../features/movements/screens/movements_screen.dart';
import '../../features/movements/screens/register_movement_screen.dart';
import '../../features/movements/screens/scan_count_screen.dart';
import '../../features/weekly_count/screens/weekly_count_screen.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/products/screens/add_edit_product_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../data/models/movement.dart';
import '../shell/app_shell.dart';
import 'go_router_refresh_stream.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final selectedLab = ref.watch(selectedLabProvider);

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(
      supabase.auth.onAuthStateChange.cast<dynamic>(),
    ),
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentUser != null;
      final location   = state.matchedLocation;

      if (!isLoggedIn) {
        return location == '/login' ? null : '/login';
      }

      if (location == '/login') {
        return selectedLab == null ? '/lab-picker' : '/dashboard';
      }

      if (selectedLab == null && location != '/lab-picker') {
        return '/lab-picker';
      }

      return null;
    },
    routes: [
      // ── Public ──────────────────────────────────
      GoRoute(
        path:    '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path:    '/lab-picker',
        builder: (_, _) => const LabPickerScreen(),
      ),

      // ── Main app shell with bottom nav ──────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          // Dashboard
          StatefulShellBranch(routes: [
            GoRoute(
              path:    '/dashboard',
              builder: (_, _) => const DashboardScreen(),
            ),
          ]),

          // Inventory
          StatefulShellBranch(routes: [
            GoRoute(
              path:    '/inventory',
              builder: (_, _) => const InventoryScreen(),
              routes: [
                GoRoute(
                  path:    'product/:id',
                  builder: (_, state) => ProductDetailScreen(
                    productId: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ]),

          // Movements
          StatefulShellBranch(routes: [
            GoRoute(
              path:    '/movements',
              builder: (_, _) => const MovementsScreen(),
              routes: [
                GoRoute(
                  path:    'entry',
                  builder: (_, _) =>
                      const RegisterMovementScreen(type: MovementType.entry),
                ),
                GoRoute(
                  path:    'exit',
                  builder: (_, _) =>
                      const RegisterMovementScreen(type: MovementType.exit),
                ),
                GoRoute(
                  path:    'return',
                  builder: (_, _) =>
                      const RegisterMovementScreen(type: MovementType.returnItem),
                ),
                GoRoute(
                  path:    'scan-count',
                  builder: (_, _) => const ScanCountScreen(),
                ),
              ],
            ),
          ]),

          // Weekly Count
          StatefulShellBranch(routes: [
            GoRoute(
              path:    '/weekly-count',
              builder: (_, _) => const WeeklyCountScreen(),
            ),
          ]),

          // Reports
          StatefulShellBranch(routes: [
            GoRoute(
              path:    '/reports',
              builder: (_, _) => const ReportsScreen(),
            ),
          ]),
        ],
      ),

      // ── Outside shell (full-screen flows) ───────
      GoRoute(
        path: '/products',
        builder: (_, _) => const ProductsScreen(),
        routes: [
          GoRoute(
            path:    'add',
            builder: (_, _) => const AddEditProductScreen(),
          ),
          GoRoute(
            path:    'edit/:id',
            builder: (_, state) => AddEditProductScreen(
              productId: state.pathParameters['id'],
            ),
          ),
        ],
      ),
      GoRoute(
        path:    '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );

  ref.listen(selectedLabProvider, (_, _) => router.refresh());

  return router;
});

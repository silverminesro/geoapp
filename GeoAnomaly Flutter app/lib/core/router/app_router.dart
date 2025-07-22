import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/map/screens/map_screen.dart';
import '../../features/map/screens/zone_detail_screen.dart';
import '../../features/detector/detector_screen.dart';
import '../../features/detector/models/detector_model.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/enhanced_inventory_detail_screen.dart';
import '../../features/inventory/models/inventory_item_model.dart';
import '../../core/models/zone_model.dart';
import '../theme/app_theme.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // 🔐 Auth routes
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // 🗺️ Map routes
    GoRoute(
      path: '/map',
      name: 'map',
      builder: (context, state) {
        // ✅ FIXED: MapScreen doesn't take extras parameter
        return const MapScreen();
      },
    ),

    // 🎯 Zone detail route
    GoRoute(
      path: '/zone/:id',
      name: 'zone_detail',
      builder: (context, state) {
        final zoneId = state.pathParameters['id']!;
        final Zone? zoneData = state.extra as Zone?;

        return ZoneDetailScreen(
          zoneId: zoneId,
          zoneData: zoneData,
        );
      },
    ),

    // 🔍 Detector screen route
    GoRoute(
      path: '/zone/:zoneId/detector',
      name: 'detector',
      builder: (context, state) {
        final zoneId = state.pathParameters['zoneId']!;
        final detector = state.extra as Detector;
        return DetectorScreen(zoneId: zoneId, detector: detector);
      },
    ),

    // 🎒 Inventory routes
    GoRoute(
      path: '/inventory',
      name: 'inventory',
      builder: (context, state) => const InventoryScreen(),
    ),

    // 💎 Inventory item detail route - ✅ FIXED parameter name
    GoRoute(
      path: '/inventory/detail',
      name: 'inventory_detail',
      builder: (context, state) {
        final item =
            state.extra as InventoryItem; // ✅ FIXED: Changed variable name
        return EnhancedInventoryDetailScreen(
            item: item); // ✅ FIXED: Use 'item' parameter
      },
    ),

    // 👤 Profile route
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => _buildProfilePlaceholder(context),
    ),

    // 🔍 Zone scanner route
    GoRoute(
      path: '/scanner',
      name: 'scanner',
      builder: (context, state) => _buildScannerPlaceholder(context),
    ),
  ],
);

// Helper method for profile placeholder
Widget _buildProfilePlaceholder(BuildContext context) {
  return Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    appBar: AppBar(
      title: Text(
        'Profile',
        style: GameTextStyles.clockTime.copyWith(
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Profile Screen',
              style: GameTextStyles.header,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon!',
              style: GameTextStyles.clockLabel,
            ),
            const SizedBox(height: 32),

            // Navigation buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/map'),
                icon: const Icon(Icons.map),
                label: const Text('Back to Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/inventory'),
                icon: const Icon(Icons.inventory_2),
                label: const Text('View Inventory'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper method for scanner placeholder
Widget _buildScannerPlaceholder(BuildContext context) {
  return Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    appBar: AppBar(
      title: Text(
        'Zone Scanner',
        style: GameTextStyles.clockTime.copyWith(
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.radar,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Zone Scanner',
              style: GameTextStyles.header,
            ),
            const SizedBox(height: 8),
            Text(
              'Advanced scanning features coming soon!',
              style: GameTextStyles.clockLabel,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Animated scanning indicator
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/map'),
                icon: const Icon(Icons.map),
                label: const Text('Back to Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

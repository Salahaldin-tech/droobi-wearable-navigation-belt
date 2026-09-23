import 'package:flutter/material.dart';
import 'location_test_screen.dart';
import 'ble_test_screen.dart';
import 'destination_search_test_screen.dart';
import 'routing_test_screen.dart';
import 'gps_routing_test_screen.dart';
import 'compass_test_screen.dart';
import 'direction_test_screen.dart';
import 'route_progress_test_screen.dart';
import 'navigation_direction_test_screen.dart';
import 'gps_filter_test_screen.dart';

/// TEMPORARY dev-only menu. Routes between the per-stage test
/// screens used to validate individual service layers (BLE, search,
/// etc.) in isolation. No longer the app's home screen as of Stage 8
/// - reachable from Settings for ongoing development/debugging only.
class DevTestMenu extends StatelessWidget {
  const DevTestMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev Test Menu')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('BLE Test Screen (Stage 5)'),
            subtitle: const Text('Scan, connect, send commands to the belt'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BleTestScreen()),
            ),
          ),
          ListTile(
            title: const Text('Destination Search Test Screen (Stage 7)'),
            subtitle: const Text('Query the destination search service directly'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DestinationSearchTestScreen(),
              ),
            ),
          ),
          ListTile(
            title: const Text('Routing Test Screen (Phase 2 Step 1)'),
            subtitle: const Text('Verify OSRM foot routing near campus'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoutingTestScreen()),
            ),
          ),ListTile(
  leading: const Icon(Icons.location_on),
  title: const Text('Location Test'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LocationTestScreen(),
      ),
    );
  },
),ListTile(
  leading: const Icon(Icons.navigation),
  title: const Text('GPS + Routing Test'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GpsRoutingTestScreen(),
      ),
    );
  },
),ListTile(
  leading: const Icon(Icons.explore),
  title: const Text('Compass Test'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CompassTestScreen(),
      ),
    );
  },
),ListTile(
  leading: const Icon(Icons.navigation),
  title: const Text('Direction Test'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DirectionTestScreen(),
      ),
    );
  },
),
ListTile(
  leading: const Icon(Icons.alt_route),
  title: const Text('Route Progress Test'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RouteProgressTestScreen(),
      ),
    );
  },
),ListTile(
  leading: const Icon(Icons.navigation),
  title: const Text('Navigation Direction Test'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const NavigationDirectionTestScreen(),
      ),
    );
  },
),ListTile(
  leading: const Icon(Icons.gps_fixed),
  title: const Text('GPS Filter Test'),
  subtitle: const Text(
    'Test GPS accuracy and jump filtering',
  ),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const GpsFilterTestScreen(),
      ),
    );
  },
),
        ],
      ),
    );
  }
}

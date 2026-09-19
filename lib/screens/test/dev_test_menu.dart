import 'package:flutter/material.dart';

import 'ble_test_screen.dart';
import 'destination_search_test_screen.dart';
import 'routing_test_screen.dart';

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
          ),
        ],
      ),
    );
  }
}

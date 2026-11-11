import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:droobi/services/navigation/navigation_trace_logger.dart';

void main() {
  group('NavigationTraceLogger', () {
    test('keeps only the most recent events', () {
      final logger = NavigationTraceLogger(maximumEvents: 2);

      logger.record('gps', fields: {'accuracy_m': 5});
      logger.record('compass', fields: {'heading_deg': 90});
      logger.record('state', fields: {'state': 'navigating'});

      expect(logger.events, hasLength(2));
      expect(logger.events.first['event'], 'compass');
      expect(logger.events.last['event'], 'state');
    });

    test('exports valid JSON lines', () {
      final logger = NavigationTraceLogger();
      logger.record('navigation_snapshot', fields: {
        'state': 'positionUncertain',
        'remaining_route_m': 12.5,
      });

      final decoded = jsonDecode(logger.exportJsonLines());
      expect(decoded['event'], 'navigation_snapshot');
      expect(decoded['remaining_route_m'], 12.5);
    });

    test('does not require or record raw coordinates', () {
      final logger = NavigationTraceLogger();
      logger.record('gps_accepted', fields: {
        'accuracy_m': 4,
        'speed_mps': 1.2,
      });

      expect(logger.events.single.containsKey('latitude'), isFalse);
      expect(logger.events.single.containsKey('longitude'), isFalse);
    });
  });
}

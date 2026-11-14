import 'package:flutter_test/flutter_test.dart';
import 'package:droobi/models/navigation_direction.dart';
import 'package:droobi/services/navigation/relative_direction_engine.dart';

void main() {
  group('RelativeDirectionEngine', () {
    test('initializes with the correct direction', () {
      final engine = RelativeDirectionEngine();
      expect(engine.update(0), NavigationDirection.forward);
    });

    test('does not switch at the original sector boundary', () {
      final engine = RelativeDirectionEngine();
      final t0 = DateTime.utc(2026, 1, 1);
      engine.update(0, timestamp: t0);
      expect(
        engine.update(25, timestamp: t0.add(const Duration(milliseconds: 100))),
        NavigationDirection.forward,
      );
    });

    test('switches after boundary and confirmation duration', () {
      final engine = RelativeDirectionEngine();
      final t0 = DateTime.utc(2026, 1, 1);
      engine.update(0, timestamp: t0);
      engine.update(35, timestamp: t0.add(const Duration(milliseconds: 10)));
      expect(
        engine.update(35, timestamp: t0.add(const Duration(milliseconds: 600))),
        NavigationDirection.forwardRight,
      );
    });
  });
}

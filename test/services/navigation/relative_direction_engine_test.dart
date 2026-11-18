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

    test('a sweep through an intermediate sector does not restart the wait',
        () {
      final engine = RelativeDirectionEngine();
      final t0 = DateTime.utc(2026, 1, 1);
      DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
      engine.update(0, timestamp: at(0));
      // Leaves forward (beyond boundary + hysteresis) at 100 ms, passes
      // through forwardLeft and settles in left by 300 ms.
      engine.update(-35, timestamp: at(100));
      engine.update(-60, timestamp: at(200));
      for (var ms = 300; ms < 1100; ms += 50) {
        expect(engine.update(-90, timestamp: at(ms)), NavigationDirection.forward,
            reason: 'still within the 1000 ms large-jump wait at $ms ms');
      }
      // 1000 ms after leaving forward, not 1000 ms after reaching left.
      expect(engine.update(-90, timestamp: at(1100)), NavigationDirection.left);
    });

    test('returning to the confirmed sector cancels a pending change', () {
      final engine = RelativeDirectionEngine();
      final t0 = DateTime.utc(2026, 1, 1);
      DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
      engine.update(0, timestamp: at(0));
      engine.update(-90, timestamp: at(100));
      engine.update(-90, timestamp: at(700));
      engine.update(0, timestamp: at(800)); // back to forward
      // The wait starts again from the next departure at 900 ms.
      engine.update(-90, timestamp: at(900));
      expect(engine.update(-90, timestamp: at(1500)), NavigationDirection.forward);
      expect(engine.update(-90, timestamp: at(1900)), NavigationDirection.left);
    });

    test('a two-sector jump must also settle in its final sector', () {
      final engine = RelativeDirectionEngine();
      final t0 = DateTime.utc(2026, 1, 1);
      DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
      engine.update(0, timestamp: at(0));
      engine.update(-90, timestamp: at(0));
      // Away for 1000 ms, but only just arrived in backLeft.
      engine.update(-135, timestamp: at(950));
      expect(engine.update(-135, timestamp: at(1050)), NavigationDirection.forward);
      expect(engine.update(-135, timestamp: at(1200)), NavigationDirection.backLeft);
    });
  });
}

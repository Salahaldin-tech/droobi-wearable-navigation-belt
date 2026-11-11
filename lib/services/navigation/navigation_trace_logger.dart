import 'dart:convert';

/// Bounded navigation trace buffer.
///
/// It deliberately excludes precise position coordinates. It records GPS
/// quality, compass heading, navigation state, route progress and decisions
/// so field observations can be reviewed without storing a location trail.
class NavigationTraceLogger {
  NavigationTraceLogger({this.maximumEvents = 1200})
      : assert(maximumEvents > 0);

  final int maximumEvents;
  final List<Map<String, Object?>> _events = [];

  List<Map<String, Object?>> get events => List.unmodifiable(
        _events.map((entry) => Map<String, Object?>.unmodifiable(entry)),
      );

  void record(
    String event, {
    DateTime? timestamp,
    Map<String, Object?> fields = const {},
  }) {
    _events.add({
      'timestamp':
          (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
      'event': event,
      ...fields,
    });

    if (_events.length > maximumEvents) {
      _events.removeRange(0, _events.length - maximumEvents);
    }
  }

  String exportJsonLines() =>
      _events.map(jsonEncode).join('\n');

  void clear() => _events.clear();
}

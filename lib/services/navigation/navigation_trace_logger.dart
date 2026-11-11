import 'dart:convert';

/// Bounded, privacy-conscious navigation diagnostics.
///
/// Exact latitude/longitude values are intentionally not recorded. The log
/// retains sensor quality, route progress, confidence transitions and
/// guidance decisions needed to diagnose field-test failures.
class NavigationTraceLogger {
  NavigationTraceLogger({this.maximumEvents = 1200})
      : assert(maximumEvents > 0);

  final int maximumEvents;
  final List<Map<String, Object?>> _events = [];

  List<Map<String, Object?>> get events => List.unmodifiable(
        _events.map((event) => Map<String, Object?>.unmodifiable(event)),
      );

  void record(
    String event, {
    DateTime? timestamp,
    Map<String, Object?> fields = const {},
  }) {
    final entry = <String, Object?>{
      'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
      'event': event,
      ...fields,
    };
    _events.add(entry);
    if (_events.length > maximumEvents) {
      _events.removeRange(0, _events.length - maximumEvents);
    }
  }

  String exportJsonLines() =>
      _events.map((event) => jsonEncode(event)).join('\n');

  void clear() => _events.clear();
}

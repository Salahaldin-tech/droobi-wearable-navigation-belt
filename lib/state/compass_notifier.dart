import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/navigation/compass_service.dart';

final compassServiceProvider =
    Provider<CompassService>((ref) {
  return CompassService();
});
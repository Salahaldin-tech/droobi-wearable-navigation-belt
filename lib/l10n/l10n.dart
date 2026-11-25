import 'package:flutter/widgets.dart';

export 'app_language.dart';

/// Lightweight bilingual helpers.
///
/// The app keeps its English and Arabic copy side by side at the call site
/// (the same pattern PageHelpButton and AboutUsScreen already used), and
/// picks one based on the active [Locale]. Because the lookup goes through
/// [Localizations.localeOf], every widget that uses it rebuilds as soon as
/// the language is switched in Settings.
extension L10nContext on BuildContext {
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';

  /// Returns [ar] when the interface is Arabic, otherwise [en].
  String tr(String en, String ar) => isArabic ? ar : en;

  /// Localized short unit for metres.
  String get metersUnit => isArabic ? 'م' : 'm';

  /// Formats a distance in metres/kilometres for the active language.
  String formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters < 1000) return '${meters.round()} $metersUnit';
    return '${(meters / 1000).toStringAsFixed(1)} ${isArabic ? 'كم' : 'km'}';
  }

  /// Letter spacing is only applied to Latin text: spacing Arabic glyphs
  /// apart breaks the connected letter forms.
  double letterSpacing(double latinSpacing) => isArabic ? 0 : latinSpacing;

  /// Display name for a search city. The stored/selected value (used by the
  /// search service) stays the original English name.
  String cityName(String city) =>
      isArabic ? (_arabicCityNames[city] ?? city) : city;

  /// Translates a message produced by the service/state layer.
  ///
  /// Services keep producing their original English messages (their logic is
  /// unchanged); this only changes what is shown on screen. Unknown messages
  /// are returned unchanged.
  String localizeMessage(String message) {
    if (!isArabic) return message;
    return ServiceMessages.arabic(message) ?? message;
  }
}

const Map<String, String> _arabicCityNames = {
  'Ramallah': 'رام الله',
  'East Jerusalem': 'القدس الشرقية',
  'Hebron': 'الخليل',
  'Nablus': 'نابلس',
  'Jenin': 'جنين',
  'Bethlehem': 'بيت لحم',
  'Jericho': 'أريحا',
  'Tulkarm': 'طولكرم',
  'Qalqilya': 'قلقيلية',
  'Tubas': 'طوباس',
  'Salfit': 'سلفيت',
  'Gaza City': 'مدينة غزة',
  'Khan Yunis': 'خان يونس',
  'Rafah': 'رفح',
  'Jabalia': 'جباليا',
  'Deir al-Balah': 'دير البلح',
};

/// Arabic translations for the fixed messages that services and notifiers
/// surface in the UI (auth, GPS, routing, search and voice errors).
abstract final class ServiceMessages {
  static const Map<String, String> _exact = {
    // Auth
    "That email address doesn't look valid. Please check and try again.":
        'يبدو أن البريد الإلكتروني غير صالح. يرجى التحقق منه والمحاولة مرة أخرى.',
    'An account already exists with that email. Try signing in instead.':
        'يوجد حساب مسجّل بهذا البريد الإلكتروني. جرّب تسجيل الدخول بدلًا من ذلك.',
    'That password is too weak. Please choose a stronger password.':
        'كلمة المرور ضعيفة جدًا. يرجى اختيار كلمة مرور أقوى.',
    'Email or password is incorrect. Please try again.':
        'البريد الإلكتروني أو كلمة المرور غير صحيحة. يرجى المحاولة مرة أخرى.',
    'Network error. Please check your connection and try again.':
        'حدث خطأ في الشبكة. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.',
    'Something went wrong. Please try again.':
        'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
    'Passwords do not match.': 'كلمتا المرور غير متطابقتين.',

    // Location / GPS
    'Location services are disabled. Please enable GPS.':
        'خدمات الموقع متوقفة. يرجى تفعيل GPS.',
    'Location permission was denied.': 'تم رفض إذن الوصول إلى الموقع.',
    'Location permission was permanently denied. Please enable it from the app settings.':
        'تم رفض إذن الموقع بشكل دائم. يرجى تفعيله من إعدادات التطبيق.',
    'Location services were turned off. Enable GPS to resume navigation.':
        'تم إيقاف خدمات الموقع. فعّل GPS لاستئناف الملاحة.',

    // Navigation
    'Campus routing service is unavailable.':
        'خدمة توجيه الحرم الجامعي غير متاحة.',
    'Could not get a good GPS fix. Move to an open area and try again.':
        'تعذّر الحصول على إشارة GPS دقيقة. انتقل إلى مكان مفتوح وحاول مرة أخرى.',
    'The routing service returned no path.': 'لم تُرجع خدمة التوجيه أي مسار.',
    'No reachable OSM pedestrian route was found for this destination.':
        'لم يُعثر على مسار مشاة يمكن الوصول إليه لهذه الوجهة.',
    'Waiting for compass heading. Hold the phone flat or start walking.':
        'بانتظار تحديد اتجاه البوصلة. أمسك الهاتف بشكل أفقي أو ابدأ بالمشي.',
    'Navigation error': 'خطأ في الملاحة',

    // Routing
    'Network error while calculating route. Please check your connection.':
        'حدث خطأ في الشبكة أثناء حساب المسار. يرجى التحقق من اتصالك.',
    'Could not reach the routing service.': 'تعذّر الوصول إلى خدمة التوجيه.',
    'No walkable path was found within the snap radius of the start or destination (OSRM code: NoSegment).':
        'لم يُعثر على ممر مشاة قريب من نقطة البداية أو الوجهة (رمز OSRM: NoSegment).',
    'Received an unexpected response from the routing service.':
        'تم استلام استجابة غير متوقعة من خدمة التوجيه.',
    'No route found between those points.':
        'لم يُعثر على مسار بين هاتين النقطتين.',
    'OpenStreetMap returned an invalid response.':
        'أرجع OpenStreetMap استجابة غير صالحة.',

    // Destination search
    'Network error while searching. Please check your connection and try again.':
        'حدث خطأ في الشبكة أثناء البحث. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
    'Could not reach the search service. Please try again.':
        'تعذّر الوصول إلى خدمة البحث. يرجى المحاولة مرة أخرى.',
    'Received an unexpected response from the search service.':
        'تم استلام استجابة غير متوقعة من خدمة البحث.',

    // Voice
    "Sorry, I didn't catch that. Please try again.":
        'عذرًا، لم أتمكن من فهم ذلك. يرجى المحاولة مرة أخرى.',
    'Please speak Arabic only.': 'يرجى التحدث بالعربية فقط.',
    'Please speak English only.': 'يرجى التحدث بالإنجليزية فقط.',
    'Voice recognition failed. Please try again.':
        'فشل التعرّف على الصوت. يرجى المحاولة مرة أخرى.',
  };

  /// Messages that embed dynamic values. `$1`, `$2` are replaced with the
  /// regular-expression groups.
  static final List<(RegExp, String)> _patterns = [
    (
      RegExp(r'^Could not get the current GPS location: (.*)$', dotAll: true),
      r'تعذّر الحصول على موقع GPS الحالي: $1',
    ),
    (RegExp(r'^GPS stream error: (.*)$', dotAll: true), r'خطأ في بيانات GPS: $1'),
    (
      RegExp(r'^Could not monitor GPS service status: (.*)$', dotAll: true),
      r'تعذّرت مراقبة حالة خدمة GPS: $1',
    ),
    (
      RegExp(r'^Route recovery is temporarily unavailable: (.*)$', dotAll: true),
      r'استعادة المسار غير متاحة مؤقتًا: $1',
    ),
    (
      RegExp(
        r'^Waiting for compass heading \((.*)\)\. Hold the phone flat or start walking\.$',
        dotAll: true,
      ),
      r'بانتظار تحديد اتجاه البوصلة ($1). أمسك الهاتف بشكل أفقي أو ابدأ بالمشي.',
    ),
    (
      RegExp(r'^Campus routing server is not configured\.(.*)$', dotAll: true),
      r'خادم توجيه الحرم الجامعي غير مُعدّ.$1',
    ),
    (
      RegExp(r'^No walking route found \(OSRM code: (.+)\)\.$'),
      r'لم يُعثر على مسار مشي (رمز OSRM: $1).',
    ),
    (
      RegExp(r'^Routing failed \(status (\d+)\)\.$'),
      r'فشل حساب المسار (رمز الحالة $1).',
    ),
    (
      RegExp(r'^No walking route found between those points \(OSRM code: (.+)\)\.$'),
      r'لم يُعثر على مسار مشي بين هاتين النقطتين (رمز OSRM: $1).',
    ),
    (
      RegExp(
        r'^The routing server did not return a pedestrian route \(travel mode: (.+)\)\. '
        r'Campus navigation needs an OSRM server built with the foot profile\.$',
      ),
      r'لم يُرجع خادم التوجيه مسارًا للمشاة (وضع التنقل: $1). تحتاج ملاحة الحرم الجامعي إلى خادم OSRM مُعدّ لملف المشي (foot).',
    ),
    (
      RegExp(r'^Your position is ([\d.]+) m from the nearest walkable path \(limit (\d+) m\)\.$'),
      r'موقعك يبعد $1 م عن أقرب ممر مشاة (الحد المسموح $2 م).',
    ),
    (
      RegExp(r'^The destination is ([\d.]+) m from the nearest walkable path \(limit (\d+) m\)\.$'),
      r'الوجهة تبعد $1 م عن أقرب ممر مشاة (الحد المسموح $2 م).',
    ),
    (
      RegExp(r'^GRAPH_CONNECTIVITY: (.*)$', dotAll: true),
      r'تعذّر إيجاد مسار متصل ضمن شبكة ممرات الحرم الجامعي. ($1)',
    ),
    (
      RegExp(r'^OpenStreetMap Overpass returned HTTP (\d+)\.$'),
      r'أرجع خادم OpenStreetMap Overpass رمز HTTP $1.',
    ),
    (
      RegExp(r'^Destination search failed \(status (\d+)\)\. Please try again\.$'),
      r'فشل البحث عن الوجهة (رمز الحالة $1). يرجى المحاولة مرة أخرى.',
    ),
  ];

  /// Returns the Arabic version of [message], or null if it is not known.
  static String? arabic(String message) {
    final exact = _exact[message];
    if (exact != null) return exact;

    for (final (pattern, template) in _patterns) {
      final match = pattern.firstMatch(message);
      if (match == null) continue;
      var result = template;
      for (var group = match.groupCount; group >= 1; group--) {
        result = result.replaceAll('\$$group', match.group(group) ?? '');
      }
      return result;
    }
    return null;
  }
}

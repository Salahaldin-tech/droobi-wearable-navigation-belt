import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/destination.dart';
import '../../models/lat_lon.dart';
import '../../screens/navigation/live_navigation_screen.dart';
import '../../screens/university/university_locations_screen.dart';
import '../../state/destination_search_notifier.dart';
import '../../state/favorites_notifier.dart';
import '../../widgets/page_help_button.dart';

class _AppTheme {
  const _AppTheme._();

  static const background = Color(0xFFF7F7F9);
  static const surface = Colors.white;
  static const fieldFill = Color(0xFFF2F3F5);
  static const fieldBorder = Color(0xFFE6E7EB);
  static const textPrimary = Color(0xFF16181D);
  static const textSecondary = Color(0xFF55585F);
  static const hint = Color(0xFF8B9099);
  static const accent = Color(0xFF2F6FED);
  static const trending = Color(0xFF1E9E5A);
  static const error = Color(0xFFE0483E);
  static const cardShadow = [
    BoxShadow(color: Color(0x141A1D29), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

class _Category {
  const _Category(this.label, this.icon, this.color, this.query,
      {this.isCampus = false});

  final String label;
  final IconData icon;
  final Color color;
  final String query;
  final bool isCampus;
}

const _categories = [
  _Category('University', Icons.school, Color(0xFF2F6FED), '', isCampus: true),
  _Category('Restaurants', Icons.restaurant, Color(0xFFF2994A), 'restaurant'),
  _Category('Cafés', Icons.local_cafe, Color(0xFF8D6E63), 'cafe'),
  _Category('Pharmacy', Icons.local_pharmacy, Color(0xFFE0483E), 'pharmacy'),
  _Category('Hospital', Icons.local_hospital, Color(0xFFEB5757), 'hospital'),
  _Category('Supermarket', Icons.shopping_cart, Color(0xFF27AE60), 'supermarket'),
  _Category('Bank', Icons.account_balance, Color(0xFF6C63FF), 'bank'),
  _Category('Mosque', Icons.mosque, Color(0xFF00897B), 'mosque'),
];

const _trendingSearches = [
  'Cafeteria', 'Library', 'Gate 3', 'Pharmacy',
  'Hospital', 'Supermarket', 'Bank', 'Restaurants',
];

class _SearchHistory {
  static final List<String> items = [];

  static void add(String query) {
    items.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    items.insert(0, query);
    if (items.length > 8) items.removeLast();
  }

  static void clear() => items.clear();
}

enum _CampusMatch { none, ambiguous, definite }

class _CampusQuery {
  const _CampusQuery._();

  static final _definite = <RegExp>[
    RegExp(r'\b(aaup|campus)\b', caseSensitive: false),
    RegExp(r'\barab american\b', caseSensitive: false),
    RegExp(r'\bgate\s*\d+\b', caseSensitive: false),
    RegExp(r'بوابة\s*\d+'),
    RegExp(r'الأمريكية|الامريكية'),
  ];

  static final _ambiguous = <RegExp>[
    RegExp(
      r'\b(university|college|faculty|cafeteria|library|lab|labs|laboratory|'
      r'gate|hall|auditorium|building|dean|department|registrar)\b',
      caseSensitive: false,
    ),
    RegExp(r'جامعة|كلية|كافتيريا|مكتبة|مختبر|بوابة|قاعة|مبنى|عمادة'),
  ];

  static final _genericWords = RegExp(
    r'\b(aaup|campus|arab american university|arab american|university)\b'
    r'|الجامعة العربية الأمريكية|الجامعة العربية الامريكية|الجامعة|جامعة',
    caseSensitive: false,
  );

  // These are names/aliases of places represented in the campus guide.
  // Ambiguous queries only open the campus page when they match one of these.
  static const _campusPlaceNames = <String>[
    'cafeteria', 'library', 'gate 1', 'gate 2', 'gate 3', 'gate 4',
    'faculty of allied medical sciences', 'allied medical sciences',
    'faculty of arts and education', 'faculty of arts',
    'faculty of business', 'faculty of dentistry', 'dentistry',
    'faculty of engineering', 'engineering and information technology',
    'faculty of information technology', 'information technology',
    'faculty of law', 'administration', 'auditorium',
    'كافتيريا', 'المكتبة', 'مكتبة', 'بوابة 1', 'بوابة 2', 'بوابة 3',
    'كلية الهندسة', 'كلية الأعمال', 'كلية الاعمال', 'كلية طب الأسنان',
    'كلية تكنولوجيا المعلومات', 'كلية الآداب والتربية',
  ];

  static _CampusMatch classify(String query) {
    final q = query.toLowerCase().trim();
    if (_definite.any((pattern) => pattern.hasMatch(q))) {
      return _CampusMatch.definite;
    }
    if (_ambiguous.any((pattern) => pattern.hasMatch(q))) {
      return _CampusMatch.ambiguous;
    }
    return _CampusMatch.none;
  }

  static bool hasCampusPlaceMatch(String query) {
    final q = normalize(clean(query));
    if (q.isEmpty) return false;
    return _campusPlaceNames.any((name) {
      final candidate = normalize(name);
      // Only route when the full campus alias is present; substring
      // matching in the opposite direction would misroute short queries
      // such as "art" to the campus guide.
      return q == candidate || q.contains(candidate);
    });
  }

  static String clean(String query) => query
      .replaceAll(_genericWords, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState
    extends ConsumerState<DestinationSearchScreen> {
  final _controller = TextEditingController();
  String? _campusSuggestion;

  @override
  void initState() {
    super.initState();
    final existingQuery = ref.read(destinationSearchProvider).query;
    if (existingQuery.isNotEmpty) _controller.text = existingQuery;
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    if (_controller.text.trim().isEmpty) {
      final state = ref.read(destinationSearchProvider);
      if (state.query.isNotEmpty ||
          state.results.isNotEmpty ||
          state.errorMessage != null ||
          state.isLoading) {
        ref.read(destinationSearchProvider.notifier).clear();
      }
    }

    // Rebuild while typing so the suffix changes between search and clear.
    if (mounted) {
      setState(() {
        if (_controller.text.trim().isEmpty) {
          _campusSuggestion = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    FocusScope.of(context).unfocus();
    ref.read(destinationSearchProvider.notifier).clear();
    setState(() => _campusSuggestion = null);
  }

  void _runSearch() => _submit(_controller.text);

  void _submit(String raw) {
    final query = raw.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    FocusScope.of(context).unfocus();
    setState(() => _SearchHistory.add(query));

    final match = _CampusQuery.classify(query);
    if (match == _CampusMatch.definite) {
      setState(() => _campusSuggestion = null);
      _openUniversity(query);
      return;
    }

    if (match == _CampusMatch.ambiguous &&
        _CampusQuery.hasCampusPlaceMatch(query)) {
      setState(() => _campusSuggestion = null);
      _openUniversity(query);
      return;
    }

    setState(() {
      _campusSuggestion =
          match == _CampusMatch.ambiguous ? query : null;
    });
    ref.read(destinationSearchProvider.notifier).search(query);
  }

  void _openUniversity(String query) {
    final cleaned = _CampusQuery.clean(query);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UniversityLocationsScreen(
          initialQuery: cleaned.isEmpty ? null : cleaned,
        ),
      ),
    );
  }

  Future<void> _addToFavorites(Destination destination) async {
    final label = await showDialog<String>(
      context: context,
      builder: (context) =>
          _FavoriteLabelDialog(initialLabel: destination.name),
    );
    if (label == null || label.trim().isEmpty) return;

    await ref.read(favoritesActionsProvider).addFavorite(
          label: label.trim(),
          destination: destination,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _AppTheme.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text('Added "${label.trim()}" to Favorites'),
        ),
      );
    }
  }

  void _openLiveNavigation(Destination destination) {
    final latLon = LatLon(
      latitude: destination.latitude,
      longitude: destination.longitude,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveNavigationScreen(destination: latLon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(destinationSearchProvider);
    final showDiscover =
        !state.isLoading && state.query.isEmpty && state.results.isEmpty;

    return Scaffold(
      backgroundColor: _AppTheme.background,
      appBar: AppBar(
        backgroundColor: _AppTheme.background,
        elevation: 0,
        centerTitle: false,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Search Destination',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
            SizedBox(width: 4),
            PageHelpButton(
              title: 'Search Destination',
              titleAr: 'البحث عن وجهة',
              description:
                  'Use the field at the top to search outside the university. University-related places can open the campus guide. Clear the field to return to search history, categories, and trending searches.',
              descriptionAr:
                  'استخدم حقل البحث في الأعلى للبحث عن الأماكن خارج الجامعة. يمكن أن تفتح الأماكن المتعلقة بالجامعة دليل الحرم الجامعي. امسح الحقل للعودة إلى سجل البحث والتصنيفات وعمليات البحث الشائعة.',
              tips: [
                'Type a place and press Search or submit the keyboard.',
                'Tap a result row to start Live Navigation, or tap its star to save it to Favorites.',
                'Searches such as Gate 3 or Cafeteria can open the University page. Other campus-like searches show a campus shortcut when appropriate.',
                'Tap the clear (×) icon in the field to restore the discovery sections.',
              ],
              tipsAr: [
                'اكتب اسم المكان واضغط Search أو أرسل البحث من لوحة المفاتيح.',
                'اضغط صف النتيجة لبدء الملاحة المباشرة، أو اضغط النجمة لحفظها في المفضلة.',
                'عمليات بحث مثل Gate 3 أو Cafeteria يمكن أن تفتح صفحة الجامعة. أما عمليات البحث الأخرى المشابهة لأماكن الجامعة فتُظهر اختصارًا للبحث داخل الحرم عند الحاجة.',
                'اضغط رمز المسح (×) في الحقل لإظهار أقسام الاستكشاف مجددًا.',
              ],
              color: _AppTheme.accent,
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: _AppTheme.textPrimary),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchBar(state),
                  const SizedBox(height: 12),
                  if (state.isLoading)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        backgroundColor: _AppTheme.fieldFill,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_AppTheme.accent),
                      ),
                    ),
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: _AppTheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (!state.isLoading &&
                      state.errorMessage == null &&
                      state.results.isEmpty &&
                      state.query.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'No results found.',
                        style: TextStyle(color: _AppTheme.textSecondary),
                      ),
                    ),
                  if (_campusSuggestion != null) ...[
                    const SizedBox(height: 8),
                    _buildCampusSuggestion(_campusSuggestion!),
                  ],
                  if (state.results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final destination in state.results) ...[
                      _buildResultTile(destination),
                      const SizedBox(height: 8),
                    ],
                  ],
                  if (showDiscover) ..._buildDiscovery(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(DestinationSearchState state) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            textField: true,
            label: 'Search destination',
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              style: const TextStyle(color: _AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Where do you want to go?',
                labelStyle: const TextStyle(color: _AppTheme.hint),
                suffixIcon: _controller.text.isEmpty
                    ? const Icon(Icons.search, color: _AppTheme.hint)
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: _AppTheme.fieldFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _AppTheme.fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _AppTheme.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: _AppTheme.accent, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: state.isLoading ? null : _runSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppTheme.accent,
              disabledBackgroundColor: _AppTheme.accent.withOpacity(0.5),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampusSuggestion(String query) {
    return Material(
      color: _AppTheme.accent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openUniversity(query),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.school, color: _AppTheme.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Looking for “$query” on campus?',
                  style: const TextStyle(
                    color: _AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Search on campus',
                style: TextStyle(
                  color: _AppTheme.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultTile(Destination destination) {
    return Container(
      decoration: BoxDecoration(
        color: _AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _AppTheme.cardShadow,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _AppTheme.accent.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_on_outlined,
            color: _AppTheme.accent,
            size: 17,
          ),
        ),
        title: Text(
          destination.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: (destination.address ?? '').isEmpty
            ? null
            : Text(
                destination.address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
        trailing: IconButton(
          tooltip: 'Add to Favorites',
          icon: const Icon(Icons.star_border),
          color: _AppTheme.accent,
          onPressed: () => _addToFavorites(destination),
        ),
        onTap: () => _openLiveNavigation(destination),
      ),
    );
  }

  List<Widget> _buildDiscovery() {
    return [
      if (_SearchHistory.items.isNotEmpty) ...[
        Row(
          children: [
            const Expanded(child: _SectionTitle('Your history')),
            TextButton(
              onPressed: () => setState(_SearchHistory.clear),
              style: TextButton.styleFrom(
                foregroundColor: _AppTheme.textSecondary,
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final query in _SearchHistory.items)
              _QueryChip(
                label: query,
                color: _AppTheme.accent,
                icon: Icons.history,
                onTap: () => _submit(query),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
      const _SectionTitle('Search by category'),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (final category in _categories) ...[
              _CategoryTile(
                category: category,
                onTap: () => category.isCampus
                    ? _openUniversity('')
                    : _submit(category.query),
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _SectionTitle('Trending searches'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final query in _trendingSearches)
            _QueryChip(
              label: query,
              color: _AppTheme.trending,
              onTap: () => _submit(query),
            ),
        ],
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(
          text,
          style: const TextStyle(
            color: _AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      );
}

class _QueryChip extends StatelessWidget {
  const _QueryChip({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _AppTheme.fieldFill,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final _Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(category.icon, color: category.color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _FavoriteLabelDialog extends StatefulWidget {
  const _FavoriteLabelDialog({required this.initialLabel});
  final String initialLabel;

  @override
  State<_FavoriteLabelDialog> createState() => _FavoriteLabelDialogState();
}

class _FavoriteLabelDialogState extends State<_FavoriteLabelDialog> {
  late final TextEditingController _labelController =
      TextEditingController(text: widget.initialLabel);

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: _AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add to Favorites',
          style: TextStyle(
            color: _AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: _labelController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Label',
            filled: true,
            fillColor: _AppTheme.fieldFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_labelController.text),
            style: FilledButton.styleFrom(backgroundColor: _AppTheme.accent),
            child: const Text('Save'),
          ),
        ],
      );
}

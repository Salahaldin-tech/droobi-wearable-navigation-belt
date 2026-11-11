
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/lat_lon.dart';
import '../../services/campus_map/campus_map_source.dart';
import '../../screens/navigation/live_navigation_screen.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/page_help_button.dart';

import '../../core/theme/app_colors.dart';

class UniversityLocationsScreen extends StatefulWidget {
  const UniversityLocationsScreen({super.key, this.initialQuery});

  /// Optional query supplied by destination search (for example, "Gate 3").
  final String? initialQuery;

  @override
  State<UniversityLocationsScreen> createState() =>
      _UniversityLocationsScreenState();
}

class _UniversityLocationsScreenState
    extends State<UniversityLocationsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = AppColors.brown;
  static const Color _pageBackground = AppColors.cream;
  static const Color _cardColor = AppColors.cream;
  static const Color _textColor = AppColors.brown;
  static const Color _secondaryText = AppColors.brown;

  // Only the first items (the ones visible when the screen opens) animate.
  static const int _maxAnimatedItems = 10;

  late final AnimationController _backgroundController;

  // ---------------------------------------------------------------------
  // CATEGORY FILTER + SEARCH
  //
  // Category labels and destinations are loaded from the verified map.
  // ---------------------------------------------------------------------
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = '';
  List<_CampusLocation> _campusLocations = [];
  bool _isLoadingLocations = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
      _searchQuery = initialQuery.toLowerCase();
    }

    _loadQgisLocations();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Respect the system "remove animations" setting.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      _backgroundController.stop();
    } else if (!_backgroundController.isAnimating) {
      _backgroundController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Fade + small upward slide when the item first appears.
  /// Items start slightly later one after another (stagger).
  /// [index] is the position of the item on screen, from the top.
  Widget _animatedItem(BuildContext context, int index, Widget child) {
    if (index >= _maxAnimatedItems ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    final delayMs = index * 60;
    final totalMs = 400 + delayMs;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(
        delayMs / totalMs,
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // All selectable destinations and category labels are read from the
  // verified V3 campus GeoJSON. No campus names or coordinates are hardcoded.
  List<String> get _categories => _campusLocations
      .map((location) => location.category)
      .toSet()
      .toList()
    ..sort();

  List<_CampusLocation> _itemsForCategory(String category) =>
      _campusLocations
          .where((location) => location.category == category)
          .toList();

  List<_CampusLocation> _visibleItems() {
    final items = _searchQuery.isEmpty || _selectedCategory.isEmpty
        ? _itemsForCategory(_selectedCategory)
        : _campusLocations;
    if (_searchQuery.isEmpty) return items;
    return items.where((item) {
      return item.name.toLowerCase().contains(_searchQuery) ||
          item.nameAr.toLowerCase().contains(_searchQuery) ||
          item.aliases.any((alias) => alias.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          // =====================================================================
          // UNIVERSITY BACKGROUND
          // =====================================================================

          Positioned.fill(
            child: Image.asset(
              'assets/images/uni_bg.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return const SizedBox.shrink();
              },
            ),
          ),

          // =====================================================================
          // LIGHT FOG
          //
          // A thin white layer keeps the map clearly visible behind the
          // rounded card, while most of it is now covered by that card.
          // =====================================================================

          Positioned.fill(
            child: Container(
              color: AppColors.cream.withValues(alpha: 1),
            ),
          ),

          // =====================================================================
          // SOFT ANIMATED GRADIENT
          // Very light blue and mint tints that drift slowly.
          // =====================================================================

          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _backgroundController,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(
                      _backgroundController.value,
                    );

                    return DecoratedBox(
                      decoration: BoxDecoration(
                        
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // =====================================================================
          // CONTENT
          //
          // Header, search, filters, grid and bottom nav sit directly over
          // the animated background — no outer card/container wrapping them.
          // =====================================================================

          SafeArea(
            child: _isLoadingLocations
                ? const Center(
                    child: CircularProgressIndicator(color: _primaryBlue),
                  )
                : _loadError != null
                    ? _buildErrorState(_loadError!)
                    : _buildCard(context),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CARD CONTENT (fixed header/search/filters + scroll-if-needed grid)
  // ===========================================================================

  Widget _buildCard(BuildContext context) {
    int order = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _animatedItem(context, order++, _buildHeader()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _animatedItem(context, order++, _buildSearchField()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: _animatedItem(context, order++, _buildFilterPills()),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _buildGrid(
            context,
            startIndex: order,
          ),
        ),
        const DroobiBottomNav(
          currentItem: DroobiNavItem.university,
        ),
      ],
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAMPUS GUIDE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _secondaryText,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Arab American University',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'LyonArabic', fontSize: 27, fontWeight: FontWeight.w900),
              ),
            ),
            PageHelpButton(
              title: 'University',
              titleAr: 'الجامعة',
              description:
                'The page shows destinations loaded from the verified campus map. Use the search field to find a mapped place, or choose one of the category filters generated from the map data. The bottom navigation bar stays at the bottom.',
              descriptionAr:
                'تعرض الصفحة الوجهات الموجودة في خريطة الجامعة المعتمدة. استخدم البحث للوصول إلى موقع مرسوم على الخريطة، أو اختر أحد التصنيفات المستخرجة من بيانات الخريطة. يبقى شريط التنقل في الأسفل.',
              tips: [
                  'Near the top, tap the search field labeled “Search buildings, gates, facilities” and type a name. Matching locations remain in the grid below; if none match, a “No matches” message appears.',
                  'Below the search field, swipe the map-derived category chips and select a category to filter the mapped destinations.',
                  'Below the filters, browse the campus cards arranged in two columns. Tap a card to select that location; if the location is available, the app opens its next location/navigation action. Unavailable locations show an unavailable message.',
                ],
              tipsAr: [
                  'قرب أعلى الشاشة، اضغط حقل “Search buildings, gates, facilities” واكتب اسمًا. تبقى المواقع المطابقة في الشبكة أسفل الحقل؛ وإذا لم توجد نتائج تظهر رسالة “No matches”.',
                  'أسفل حقل البحث، مرّر تصنيفات المواقع المستخرجة من الخريطة واختر تصنيفًا لعرض وجهاته فقط.',
                  'أسفل التصنيفات، تصفح بطاقات مواقع الجامعة المرتبة في عمودين. اضغط بطاقة لاختيار الموقع؛ إذا كان متاحًا يفتح التطبيق إجراء الموقع أو الملاحة التالي، وإذا لم يكن متاحًا تظهر رسالة توضح ذلك.',
                ],
              color: _primaryBlue,
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // SEARCH FIELD
  // ===========================================================================

  Widget _buildSearchField() {
    return Semantics(
      textField: true,
      label: 'Search campus locations',
      child: AppSearchBar(
        controller: _searchController,
        hintText: 'Search buildings, gates, facilities',
        showSearchIcon: true,
      ),
    );
  }

  // ===========================================================================
  // FILTER PILLS
  // ===========================================================================

  Widget _buildFilterPills() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Semantics(
            button: true,
            selected: isSelected,
            label: category,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? _primaryBlue : AppColors.cream,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _primaryBlue : _primaryBlue.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.cream : _primaryBlue,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // GRID (two columns, scrolls internally only if the category overflows)
  // ===========================================================================

  Widget _buildGrid(
    BuildContext context, {
    required int startIndex,
  }) {
    final items = _visibleItems();

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No matches in $_selectedCategory.',
          style: const TextStyle(fontSize: 13, color: _secondaryText),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        return _animatedItem(
          context,
          startIndex + index,
          _buildLocationCard(
            context: context,
            item: items[index],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // LOCATION CARD
  // ===========================================================================

  /// Picks a more specific icon per place instead of reusing one generic
  /// pin for every card — colleges get a school icon, gates get a door
  /// icon, and each facility gets its own icon by name.
  IconData _iconForItem(_CampusLocation item) {
    final category = item.category.toLowerCase();
    if (category.contains('gate') || category.contains('entrance')) {
      return Icons.sensor_door_outlined;
    }
    if (category.contains('college') || category.contains('faculty') ||
        category.contains('building')) {
      return Icons.school_outlined;
    }
    if (category.contains('food') || category.contains('cafe')) {
      return Icons.local_cafe_outlined;
    }
    return Icons.place_outlined;
  }

  Widget _buildLocationCard({
    required BuildContext context,
    required _CampusLocation item,
  }) {

    return AppCard(
      padding: EdgeInsets.zero,
      child: Semantics(
      button: true,
      enabled: true,
      label: item.name,
      hint: 'Double tap to navigate to this mapped campus location.',
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleLocationSelect(context, item),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    _iconForItem(item),
                    size: 16,
                    color: _primaryBlue,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _loadQgisLocations() async {
    try {
      final source = await rootBundle.loadString(
        CampusMapSource.nodesAsset,
      );
      final collection = CampusMapSource.decodeAndValidate(
        source,
        expectedLayer: CampusMapSource.nodesLayer,
      );
      final features = collection['features'] as List<dynamic>;
      final grouped = <String, List<_CampusNodeRecord>>{};

      for (final feature in features) {
        if (feature is! Map<String, dynamic>) continue;
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null || geometry['type'] != 'Point') continue;
        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.length < 2) continue;
        final longitude = (coordinates[0] as num?)?.toDouble();
        final latitude = (coordinates[1] as num?)?.toDouble();
        if (latitude == null || longitude == null ||
            latitude < -90 || latitude > 90 ||
            longitude < -180 || longitude > 180) continue;

        final id = _readMapProperty(
          properties,
          const ['node_id', 'nodeid', 'id', 'node', '_source_fid'],
        );
        if (id == null || id.isEmpty) continue;
        final rawNodeType = _readMapProperty(
          properties,
          const ['node_type', 'feature_type', 'type'],
        );
        if (rawNodeType != null &&
            rawNodeType.toLowerCase().contains('junction')) {
          continue;
        }
        final rawName = _readMapProperty(
          properties,
          const ['name', 'node_name', 'building_name', 'label', 'description'],
        );
        final name = (rawName == null || rawName.isEmpty) ? id : rawName;
        final nameAr = _readMapProperty(
              properties,
              const ['name_ar', 'namearabic', 'label_ar', 'building_name_ar'],
            ) ?? name;
        final rawCategory = _readMapProperty(
          properties,
          const ['category', 'location_category', 'node_type', 'feature_type', 'type'],
        );
        final category = _displayCategory(rawCategory);
        final rawAliases = _readMapProperty(
          properties,
          const ['aliases', 'alias', 'search_terms'],
        );
        final aliases = rawAliases == null
            ? <String>[]
            : rawAliases.split(RegExp(r'[;,|]')).map((value) => value.trim())
                .where((value) => value.isNotEmpty).toList();
        final groupId = _readMapProperty(
          properties,
          const ['place_id', 'location_id', 'building_id', 'parent_id', 'group_id'],
        );
        final groupKey = (groupId == null || groupId.isEmpty)
            ? _normalize(name)
            : groupId.trim().toLowerCase();
        final record = _CampusNodeRecord(
          name: name,
          nameAr: nameAr,
          category: category,
          point: LatLon(latitude: latitude, longitude: longitude),
          aliases: aliases,
        );
        grouped.putIfAbsent(groupKey, () => <_CampusNodeRecord>[]).add(record);
      }

      final parsed = grouped.values.map((records) {
        final first = records.first;
        final uniqueAliases = records.expand((record) => record.aliases).toSet().toList();
        return _CampusLocation(
          name: first.name,
          nameAr: first.nameAr,
          category: first.category,
          aliases: uniqueAliases,
          points: records.map((record) => record.point).toList(),
        );
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (parsed.isEmpty) {
        throw const FormatException(
          'The verified main-branch campus map contains no selectable point locations.',
        );
      }
      if (!mounted) return;
      setState(() {
        _campusLocations = parsed;
        final categories = _categories;
        if (_selectedCategory.isEmpty && categories.isNotEmpty) {
          _selectedCategory = categories.first;
        }
        _isLoadingLocations = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocations = false;
        _loadError = error;
      });
    }
  }

  String? _readMapProperty(
    Map<String, dynamic> properties,
    List<String> candidates,
  ) {
    final normalized = <String, dynamic>{
      for (final entry in properties.entries)
        entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''):
            entry.value,
    };
    for (final candidate in candidates) {
      final value = normalized[
        candidate.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')
      ];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  String _displayCategory(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campus';
    final words = value.trim().replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ').split(' ');
    return words.map((word) => word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase()).join(' ');
  }

  String _normalize(String value) => value.trim().toLowerCase()
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  // ===========================================================================
  // LOCATION SELECT
  // ===========================================================================

  void _handleLocationSelect(
    BuildContext context,
    _CampusLocation item,
  ) {
    final candidates = item.points;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveNavigationScreen(
          destination: candidates.first,
          destinationCandidates: candidates.length > 1 ? candidates : null,
          campusNavigation: true,
        ),
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.brown.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Could not load university locations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: _secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampusNodeRecord {
  const _CampusNodeRecord({
    required this.name,
    required this.nameAr,
    required this.category,
    required this.point,
    required this.aliases,
  });

  final String name;
  final String nameAr;
  final String category;
  final LatLon point;
  final List<String> aliases;
}

class _CampusLocation {
  const _CampusLocation({
    required this.name,
    required this.nameAr,
    required this.category,
    required this.aliases,
    required this.points,
  });

  final String name;
  final String nameAr;
  final String category;
  final List<String> aliases;
  final List<LatLon> points;
}

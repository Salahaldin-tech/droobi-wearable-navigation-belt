import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/university_location.dart';
import '../../state/university_locations_notifier.dart';
import '../../widgets/droobi_bottom_nav.dart';

class UniversityLocationsScreen extends ConsumerStatefulWidget {
  const UniversityLocationsScreen({super.key});

  @override
  ConsumerState<UniversityLocationsScreen> createState() =>
      _UniversityLocationsScreenState();
}

class _UniversityLocationsScreenState
    extends ConsumerState<UniversityLocationsScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF2F80ED);
  static const Color _pageBackground = Color(0xFFF4F5F7);
  static const Color _cardColor = Color(0xFFF5F5F5);
  static const Color _textColor = Color(0xFF111111);
  static const Color _secondaryText = Color(0xFF6B7280);

  // Only the first items (the ones visible when the screen opens) animate.
  static const int _maxAnimatedItems = 10;

  late final AnimationController _backgroundController;

  // ---------------------------------------------------------------------
  // CATEGORY FILTER + SEARCH
  //
  // New, additive UI state — doesn't touch _colleges/_gates/_facilities,
  // _findLocation, _handleLocationSelect, or _showUnavailableMessage.
  // Picking a category just changes which of the existing lists is
  // rendered; typing a search query just narrows that list by name.
  // ---------------------------------------------------------------------
  static const List<String> _categories = ['Colleges', 'Gates', 'Facilities'];
  String _selectedCategory = _categories.first;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

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

  // ===========================================================================
  // FIGMA DATA
  // ===========================================================================

  static const List<_UniversityItem> _colleges = [
    _UniversityItem(
      name: 'Faculty of Allied Medical Sciences',
      nameAr: 'كلية العلوم الطبية المساعدة',
      aliases: [
        'Faculty of Allied Medical Sciences',
        'Allied Medical Sciences',
        'AMS',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Arts and Education',
      nameAr: 'كلية الآداب والتربية',
      aliases: [
        'Faculty of Arts and Education',
        'Faculty of Arts',
        'Arts and Education',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Business',
      nameAr: 'كلية الأعمال',
      aliases: [
        'Faculty of Business',
        'Business',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Dentistry',
      nameAr: 'كلية طب الأسنان',
      aliases: [
        'Faculty of Dentistry',
        'Dentistry',
        'DEN-A',
        'DEN-B',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Engineering',
      nameAr: 'كلية الهندسة',
      aliases: [
        'Faculty of Engineering',
        'Faculty of Engineering and Information Technology',
        'Faculty of Engineering and IT',
        'Engineering and Information Technology',
        'EIT',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Information Technology',
      nameAr: 'كلية تكنولوجيا المعلومات',
      aliases: [
        'Faculty of Information Technology',
        'Information Technology',
        'IT',
        'EIT',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Law',
      nameAr: 'كلية القانون',
      aliases: [
        'Faculty of Law',
        'Law',
        'LAW',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Medicine',
      nameAr: 'كلية الطب',
      aliases: [
        'Faculty of Medicine',
        'Medicine',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Nursing',
      nameAr: 'كلية التمريض',
      aliases: [
        'Faculty of Nursing',
        'Nursing',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Pharmacy',
      nameAr: 'كلية الصيدلة',
      aliases: [
        'Faculty of Pharmacy',
        'Pharmacy',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Science',
      nameAr: 'كلية العلوم',
      aliases: [
        'Faculty of Science',
        'Faculty of Sciences',
        'Science',
        'A&S',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Sports Sciences',
      nameAr: 'كلية علوم الرياضة',
      aliases: [
        'Faculty of Sports Sciences',
        'Sports Sciences',
      ],
    ),
  ];

  static const List<_UniversityItem> _gates = [
    _UniversityItem(
      name: 'Gate 1',
      nameAr: 'البوابة ١',
      aliases: [
        'Gate 1',
        'G1',
      ],
    ),
    _UniversityItem(
      name: 'Gate 2',
      nameAr: 'البوابة ٢',
      aliases: [
        'Gate 2',
        'G2',
      ],
    ),
    _UniversityItem(
      name: 'Gate 3',
      nameAr: 'البوابة ٣',
      aliases: [
        'Gate 3',
        'G3',
        'Gate 3 University Visitors Gate',
      ],
    ),
    _UniversityItem(
      name: 'Gate 4',
      nameAr: 'البوابة ٤',
      aliases: [
        'Gate 4',
        'G4',
      ],
    ),
    _UniversityItem(
      name: 'Gate 5',
      nameAr: 'البوابة ٥',
      aliases: [
        'Gate 5',
        'G5',
      ],
    ),
  ];

  static const List<_UniversityItem> _facilities = [
    _UniversityItem(
      name: 'Cafeteria',
      nameAr: 'الكافتيريا',
      aliases: [
        'Cafeteria',
        'Shopping Center',
        'SC',
      ],
    ),
    _UniversityItem(
      name: 'Administration',
      nameAr: 'الإدارة',
      aliases: [
        'Administration',
        'Administrative Departments Building',
        'AD',
        'Presidential Building',
        'PR',
      ],
    ),
    _UniversityItem(
      name: 'Library',
      nameAr: 'المكتبة',
      aliases: [
        'Library',
      ],
    ),
  ];

  List<_UniversityItem> _itemsForCategory(String category) {
    switch (category) {
      case 'Gates':
        return _gates;
      case 'Facilities':
        return _facilities;
      case 'Colleges':
      default:
        return _colleges;
    }
  }

  List<_UniversityItem> _visibleItems() {
    // While searching, look across every category (not just the selected
    // pill) so a query always finds a match regardless of which filter is
    // active. With no query, fall back to just the selected category.
    final items = _searchQuery.isEmpty
        ? _itemsForCategory(_selectedCategory)
        : [..._colleges, ..._gates, ..._facilities];

    if (_searchQuery.isEmpty) {
      return items;
    }

    return items
        .where(
          (item) =>
              item.name.toLowerCase().contains(_searchQuery) ||
              item.nameAr.contains(_searchQuery),
        )
        .toList();
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(universityLocationsProvider);

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
              color: Colors.white.withValues(alpha: 1),
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
                        gradient: LinearGradient(
                          begin: Alignment.lerp(
                            Alignment.topLeft,
                            Alignment.topRight,
                            t,
                          )!,
                          end: Alignment.lerp(
                            Alignment.bottomRight,
                            Alignment.bottomLeft,
                            t,
                          )!,
                          colors: [
                            const Color(0xFFDCEBFF).withValues(alpha: 0.30),
                            Colors.white.withValues(alpha: 0.05),
                            const Color(0xFFD9F5EA).withValues(alpha: 0.25),
                          ],
                        ),
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
            child: locationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: _primaryBlue,
                ),
              ),
              error: (error, _) => _buildErrorState(error),
              data: (locations) => _buildCard(context, locations),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CARD CONTENT (fixed header/search/filters + scroll-if-needed grid)
  // ===========================================================================

  Widget _buildCard(
    BuildContext context,
    List<UniversityLocation> locations,
  ) {
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
            locations,
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
    return const Column(
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
        Text(
          'Arab American University',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
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
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14, color: _textColor),
        decoration: InputDecoration(
          hintText: 'Search buildings, gates, facilities',
          hintStyle: const TextStyle(fontSize: 14, color: _secondaryText),
          suffixIcon: const Icon(
            Icons.search,
            size: 20,
            color: _secondaryText,
          ),
          filled: true,
          fillColor: _cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
          ),
        ),
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
                  color: isSelected ? _primaryBlue : Colors.white,
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
                    color: isSelected ? Colors.white : _primaryBlue,
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
    BuildContext context,
    List<UniversityLocation> locations, {
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
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) {
        return _animatedItem(
          context,
          startIndex + index,
          _buildLocationCard(
            context: context,
            item: items[index],
            locations: locations,
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
  IconData _iconForItem(_UniversityItem item) {
    if (_colleges.contains(item)) {
      return Icons.school_outlined;
    }
    if (_gates.contains(item)) {
      return Icons.sensor_door_outlined;
    }

    switch (item.name) {
      case 'Cafeteria':
        return Icons.local_cafe_outlined;
      case 'Administration':
        return Icons.apartment_outlined;
      case 'Library':
        return Icons.menu_book_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  Widget _buildLocationCard({
    required BuildContext context,
    required _UniversityItem item,
    required List<UniversityLocation> locations,
  }) {
    final location = _findLocation(item, locations);
    final isAvailable = location != null;

    return Semantics(
      button: true,
      enabled: isAvailable,
      label: item.name,
      hint: isAvailable
          ? 'Double tap to select this location.'
          : 'This location is not available yet.',
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isAvailable
              ? () {
                  _handleLocationSelect(context, item, location);
                }
              : () {
                  _showUnavailableMessage(context, item);
                },
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
                    color: _primaryBlue.withValues(alpha: isAvailable ? 0.14 : 0.06),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    _iconForItem(item),
                    size: 16,
                    color: isAvailable
                        ? _primaryBlue
                        : _primaryBlue.withValues(alpha: 0.4),
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
                        color: isAvailable
                            ? _textColor
                            : _textColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FIND LOCATION
  // ===========================================================================

  UniversityLocation? _findLocation(
    _UniversityItem item,
    List<UniversityLocation> locations,
  ) {
    for (final location in locations) {
      final locationName = _normalize(location.name);

      for (final alias in item.aliases) {
        final normalizedAlias = _normalize(alias);

        if (locationName == normalizedAlias ||
            locationName.contains(normalizedAlias) ||
            normalizedAlias.contains(locationName)) {
          return location;
        }
      }
    }

    return null;
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ===========================================================================
  // LOCATION SELECT
  // ===========================================================================

  void _handleLocationSelect(
    BuildContext context,
    _UniversityItem item,
    UniversityLocation location,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Selected ${item.name}',
          ),
        ),
      );

    // GPS + routing will be connected
    // in the GPS/routing stage.
    //
    // The selected coordinates are available:
    // location.latitude
    // location.longitude
  }

  // ===========================================================================
  // UNAVAILABLE LOCATION
  // ===========================================================================

  void _showUnavailableMessage(
    BuildContext context,
    _UniversityItem item,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${item.name} is not available yet.',
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
                color: Colors.grey.shade400,
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

// ==============================================================================
// UNIVERSITY ITEM
// ==============================================================================

class _UniversityItem {
  const _UniversityItem({
    required this.name,
    required this.nameAr,
    required this.aliases,
  });

  final String name;
  final String nameAr;
  final List<String> aliases;
}
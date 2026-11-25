import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/campus_destination.dart';
import '../../screens/navigation/live_navigation_screen.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/page_header.dart';
import '../../widgets/page_help_button.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/l10n.dart';

class UniversityLocationsScreen extends ConsumerStatefulWidget {
  const UniversityLocationsScreen({super.key, this.initialQuery});

  /// Optional query supplied by destination search (for example, "Gate 3").
  final String? initialQuery;

  @override
  ConsumerState<UniversityLocationsScreen> createState() =>
      _UniversityLocationsScreenState();
}

class _UniversityLocationsScreenState
    extends ConsumerState<UniversityLocationsScreen>
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

    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
      _searchQuery = initialQuery.toLowerCase();
    }

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
  // UNIVERSITY LOCATION LABELS — coordinates live in campus_destination.dart,
  // keyed by these exact names (fixed entrance points from the JOSM map).
  // ===========================================================================

  static const List<_UniversityItem> _colleges = [
    _UniversityItem(
      name: 'Allied Medical Sciences – AMS-A',
      nameAr: 'كلية العلوم الطبية المساعدة – المبنى A',
      aliases: [
        'Faculty of Allied Medical Sciences',
        'Allied Medical Sciences',
        'AMS',
        'AMS-A',
      ],
    ),
    _UniversityItem(
      name: 'Allied Medical Sciences – AMS-B',
      nameAr: 'كلية العلوم الطبية المساعدة – المبنى B',
      aliases: [
        'Faculty of Allied Medical Sciences',
        'Allied Medical Sciences',
        'AMS',
        'AMS-B',
      ],
    ),
    _UniversityItem(
      name: 'Faculty of Arts and Education',
      nameAr: 'كلية الآداب والتربية',
      aliases: [
        'Faculty of Arts and Education',
        'Faculty of Arts and Sciences',
        'Faculty of Arts',
        'Arts and Education',
        'Arts and Sciences',
        'كلية الآداب والعلوم',
        'كلية الآداب والتربية',
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
      name: 'Dentistry – DEN-A',
      nameAr: 'كلية طب الأسنان – المبنى A',
      aliases: [
        'Faculty of Dentistry',
        'Dentistry',
        'DEN-A',
      ],
    ),
    _UniversityItem(
      name: 'Dentistry – DEN-B',
      nameAr: 'كلية طب الأسنان – المبنى B',
      aliases: [
        'Faculty of Dentistry',
        'Dentistry',
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
        'Sports Hall',
        'SH',
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
      ],
    ),
    _UniversityItem(
      name: 'Deanship of Admission and Registration',
      nameAr: 'عمادة القبول والتسجيل',
      aliases: [
        'Deanship of Admission and Registration',
        'Admission and Registration',
        'Admission',
        'Registration',
        'DAR',
      ],
    ),
    _UniversityItem(
      name: 'Presidential Building',
      nameAr: 'مبنى الرئاسة',
      aliases: [
        'Presidential Building',
        'Presidency',
        'PR',
      ],
    ),
    _UniversityItem(
      name: 'International Soccer Stadium',
      nameAr: 'ملعب كرة القدم الدولي',
      aliases: [
        'International Soccer Stadium',
        'Soccer Stadium',
        'Stadium',
        'ISS',
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

  String _categoryLabel(BuildContext context, String category) {
    switch (category) {
      case 'Gates':
        return context.tr('Gates', 'البوابات');
      case 'Facilities':
        return context.tr('Facilities', 'المرافق');
      case 'Colleges':
      default:
        return context.tr('Colleges', 'الكليات');
    }
  }

  /// Location name in the active language (navigation still uses [name]).
  String _itemLabel(BuildContext context, _UniversityItem item) =>
      context.isArabic ? item.nameAr : item.name;

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
              item.nameAr.contains(_searchQuery) ||
              item.aliases.any(
                (alias) => alias.toLowerCase().contains(_searchQuery),
              ),
        )
        .toList();
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

          // Render the original University choices immediately. OSM is
          // queried only after the user taps a destination card.
          SafeArea(
            child: _buildCard(context),
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
          // Header at the top of the safe area, like every other page.
          padding: EdgeInsets.zero,
          child: _animatedItem(context, order++, _buildHeader()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: _animatedItem(context, order++, _buildSearchField()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
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
    // Shared page header. The former "Campus guide" eyebrow text was removed.
    return PageHeader(
      title: context.tr(
        'Arab American University',
        'الجامعة العربية الأمريكية',
      ),
      help: const PageHelpButton(
              title: 'University',
              titleAr: 'الجامعة',
              description:
                'The page is arranged from top to bottom: the campus title, a search field, a horizontally scrolling row of category filters, then campus location cards in a two-column grid. The bottom navigation bar stays at the bottom.',
              descriptionAr:
                'ترتيب الصفحة من الأعلى للأسفل: عنوان الجامعة، ثم حقل البحث، ثم صف أفقي قابل للتمرير لأزرار التصنيفات، وبعده بطاقات مواقع الجامعة ضمن شبكة من عمودين. يبقى شريط التنقل في الأسفل.',
              tips: [
                  'Near the top, tap the search field labeled “Search buildings, gates, facilities” and type a name. Matching locations remain in the grid below; if none match, a “No matches” message appears.',
                  'Directly below the search field, swipe the category chips left or right and tap Colleges, Gates, or Facilities. The selected chip turns blue and the grid refreshes.',
                  'Below the filters, browse the campus cards arranged in two columns. Tap a card to select that location; if the location is available, the app opens its next location/navigation action. Unavailable locations show an unavailable message.',
                ],
              tipsAr: [
                  'قرب أعلى الشاشة، اضغط حقل «ابحث عن المباني والبوابات والمرافق» واكتب اسمًا. تبقى المواقع المطابقة في الشبكة أسفل الحقل؛ وإذا لم توجد نتائج تظهر رسالة «لا توجد نتائج».',
                  'أسفل حقل البحث مباشرة، مرّر أزرار التصنيفات أفقيًا، ثم اضغط الكليات أو البوابات أو المرافق. يظهر التصنيف المحدد بلون داكن وتتحدث الشبكة.',
                  'أسفل التصنيفات، تصفح بطاقات مواقع الجامعة المرتبة في عمودين. اضغط بطاقة لاختيار الموقع؛ إذا كان متاحًا يفتح التطبيق إجراء الموقع أو الملاحة التالي، وإذا لم يكن متاحًا تظهر رسالة توضح ذلك.',
                ],
              color: _primaryBlue,
            ),
    );
  }

  // ===========================================================================
  // SEARCH FIELD
  // ===========================================================================

  Widget _buildSearchField() {
    return Semantics(
      textField: true,
      label: context.tr('Search campus locations', 'ابحث في مواقع الحرم الجامعي'),
      child: AppSearchBar(
        controller: _searchController,
        hintText: context.tr(
          'Search buildings, gates, facilities',
          'ابحث عن المباني والبوابات والمرافق',
        ),
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
            label: _categoryLabel(context, category),
            excludeSemantics: true,
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
                  _categoryLabel(context, category),
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
          context.tr(
            'No matches in $_selectedCategory.',
            'لا توجد نتائج في ${_categoryLabel(context, _selectedCategory)}.',
          ),
          style: const TextStyle(fontSize: 13, color: _secondaryText),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
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
      case 'Deanship of Admission and Registration':
        return Icons.assignment_ind_outlined;
      case 'Presidential Building':
        return Icons.account_balance_outlined;
      case 'International Soccer Stadium':
        return Icons.sports_soccer_outlined;
      case 'Library':
        return Icons.menu_book_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  Widget _buildLocationCard({
    required BuildContext context,
    required _UniversityItem item,
  }) {
    // Availability is checked on tap against the fixed coordinates in
    // campus_destination.dart; cards without one show an "unavailable" message.
    const isAvailable = true;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Semantics(
      button: true,
      enabled: isAvailable,
      label: _itemLabel(context, item),
      hint: isAvailable
          ? context.tr(
              'Double tap to select this location.',
              'انقر مرتين لاختيار هذا الموقع.',
            )
          : context.tr(
              'This location is not available yet.',
              'هذا الموقع غير متاح بعد.',
            ),
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
                      _itemLabel(context, item),
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
      ),
    );
  }

  // ===========================================================================
  // FIND LOCATION
  // ===========================================================================

  // Fixed destination coordinates live in lib/models/campus_destination.dart.
  // They are destination points only; the route is calculated dynamically
  // from the user's current GPS position by the campus OSRM flow.

  // ===========================================================================
  // LOCATION SELECT
  // ===========================================================================

  void _handleLocationSelect(
    BuildContext context,
    _UniversityItem item,
  ) {
    final destination = campusDestinationByName(item.name)?.position;

    if (destination == null) {
      _showUnavailableMessage(context, item);
      return;
    }

    // University destinations must activate the campus-only navigation
    // pipeline: campus OSRM client, accuracy-aware compass samples, and
    // platform-aware true-north correction. Home navigation remains unchanged.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveNavigationScreen(
          destination: destination,
          campusNavigation: true,
        ),
      ),
    );
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
            context.tr(
              '${item.name} is not available yet.',
              '${item.nameAr} غير متاح بعد.',
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
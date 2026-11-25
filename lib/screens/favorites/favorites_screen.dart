import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/destination.dart';
import '../../models/favorite_location.dart';
import '../../models/lat_lon.dart';
import '../../services/location/location_service.dart';
import '../../state/favorites_notifier.dart';
import '../../state/location_notifier.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../../widgets/app_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/page_help_button.dart';
import '../destination/destination_search_screen.dart';
import '../navigation/live_navigation_screen.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/l10n.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with TickerProviderStateMixin {
  static const Color _primaryBlue = AppColors.brown;
  static const Color _cardColor = AppColors.cream;
  static const Color _textColor = AppColors.brown;
  static const Color _secondaryText = AppColors.brown;

  late final AnimationController _backgroundController;
  late final AnimationController _headerAnimation;

  bool _showAddOptions = false;
  bool _addingCurrentLocation = false;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _headerAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _headerAnimation.dispose();
    super.dispose();
  }

  // ===========================================================================
  // OPEN FAVORITE IN LIVE NAVIGATION
  // ===========================================================================

  void _openFavoriteNavigation(
    BuildContext context,
    FavoriteLocation favorite,
  ) {
    final destination = LatLon(
      latitude: favorite.latitude,
      longitude: favorite.longitude,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveNavigationScreen(
          destination: destination,
        ),
      ),
    );
  }

  // ===========================================================================
  // REMOVE FAVORITE
  // ===========================================================================

  Future<void> _removeFavorite(
    BuildContext context,
    FavoriteLocation favorite,
  ) async {
    await ref.read(favoritesActionsProvider).removeFavorite(favorite.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              '"${favorite.label}" removed from Favorites',
              'تمت إزالة «${favorite.label}» من المفضلة',
            ),
          ),
        ),
      );
  }

  // ===========================================================================
  // ADD OPTIONS
  // ===========================================================================

  void _toggleAddOptions() {
    setState(() {
      _showAddOptions = !_showAddOptions;
    });
  }

  void _openSearchLocation() {
    setState(() {
      _showAddOptions = false;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DestinationSearchScreen(),
      ),
    );
  }

  // ===========================================================================
  // ADD CURRENT LOCATION
  // ===========================================================================

  Future<void> _addCurrentLocation() async {
    if (_addingCurrentLocation) {
      return;
    }

    setState(() {
      _showAddOptions = false;
      _addingCurrentLocation = true;
    });

    try {
      final locationService = ref.read(locationServiceProvider);

      final fix = await locationService.getCurrentLocationFix();

      if (!mounted) {
        return;
      }

      final destination = Destination(
        name: 'Current Location',
        latitude: fix.position.latitude,
        longitude: fix.position.longitude,
      );

      // The dialog owns its own TextEditingController now, so it gets
      // disposed only after the dialog is fully removed from the tree.
      final label = await showDialog<String>(
        context: context,
        builder: (_) => const _AddFavoriteLabelDialog(),
      );

      if (!mounted) {
        return;
      }

      if (label == null || label.trim().isEmpty) {
        return;
      }

      await ref.read(favoritesActionsProvider).addFavorite(
            label: label.trim(),
            destination: destination,
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Added "${label.trim()}" to Favorites',
                'تمت إضافة «${label.trim()}» إلى المفضلة',
              ),
            ),
          ),
        );
    } on LocationFailure catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.localizeMessage(error.message)),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Could not get your current location. Please try again.',
                'تعذّر تحديد موقعك الحالي. يرجى المحاولة مرة أخرى.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _addingCurrentLocation = false;
        });
      }
    }
  }

  // ===========================================================================
  // ANIMATED HEADER / CONTENT
  // ===========================================================================

  Widget _fadeSlide(
    Animation<double> animation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _animatedItem(
    BuildContext context,
    int index,
    Widget child,
  ) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 350 + (index * 70)),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // ===========================================================================
  // ADD OPTION BUTTON
  // ===========================================================================

  Widget _buildAddOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppColors.cream,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _secondaryText,
                    ),
                  ),
                ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          // MAP BACKGROUND
          Positioned.fill(
            child: Image.asset(
              'assets/images/Favorites_bg.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),

          // LIGHT FOG
          Positioned.fill(
            child: Container(
              color: AppColors.cream.withValues(alpha: 0.90),
            ),
          ),

          // SOFT ANIMATED GRADIENT
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

          // MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    // Header starts at the top of the safe area, at the same
                    // height as every other page title.
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER
                        _fadeSlide(
                          _headerAnimation,
                          PageHeader(
                            horizontalPadding: 0,
                            title: context.tr('Favorites', 'المفضلة'),
                            help: const PageHelpButton(
                                    title: 'Favorites',
                                    titleAr: 'المفضلة',
                                    description:
                'The page title is near the top-left. Saved places appear below it as a vertically scrolling list of full-width cards, one card per row. The blue + button floats near the bottom-right.',
                                    descriptionAr:
                'عنوان الصفحة قرب أعلى اليمين. تظهر الأماكن المحفوظة أسفله في قائمة عمودية قابلة للتمرير، على شكل بطاقات بعرض الصفحة، بطاقة واحدة في كل صف. يطفو زر + قرب أسفل يسار الشاشة.',
                                    tips: [
                  'Tap the blue + button near the bottom-right. Two option cards appear directly above it: Search Location and Add Current Location.',
                  'Tap Search Location in the options above the + button. The destination search page opens; its results appear as vertical rows. Tap the star icon at the right end of a result row to save that place, then complete the label dialog if shown.',
                  'Tap Add Current Location in the options above the + button. A dialog appears in the center; enter a label in its text field and tap Save at the bottom of the dialog. The saved place appears as a new card in the vertical list.',
                  'Tap a saved-place card in the list to open Live Navigation. To remove one, tap the trash-can icon on the right side of that card; the card disappears from the list.',
                ],
              tipsAr: [
                  'اضغط زر + قرب أسفل يسار الشاشة. سيظهر فوقه مباشرة خياران على شكل بطاقتين: «البحث عن موقع» و«إضافة الموقع الحالي».',
                  'اضغط «البحث عن موقع» في الخيارات فوق زر +. ستفتح شاشة البحث عن وجهة وتظهر نتائجها على شكل صفوف عمودية. اضغط رمز النجمة في أقصى يسار صف النتيجة لحفظ المكان، ثم أكمل نافذة التسمية إن ظهرت.',
                  'اضغط «إضافة الموقع الحالي» في الخيارات فوق زر +. ستظهر نافذة في منتصف الشاشة؛ اكتب اسمًا في حقل النص واضغط «حفظ» أسفل النافذة. يظهر المكان المحفوظ كبطاقة جديدة في القائمة العمودية.',
                  'اضغط بطاقة المكان المحفوظ ضمن القائمة لفتح الملاحة المباشرة إليه. ولحذفه، اضغط رمز سلة المهملات في الجهة اليسرى من البطاقة؛ فتختفي البطاقة من القائمة.',
                ],
                                    color: _primaryBlue,
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // FAVORITES
                        Expanded(
                          child: favoritesAsync.when(
                            loading: () {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            error: (error, stackTrace) {
                              return Center(
                                child: Text(
                                  context.tr(
                                    'Unable to load Favorites.',
                                    'تعذّر تحميل المفضلة.',
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.brown,
                                    fontSize: 15,
                                  ),
                                ),
                              );
                            },
                            data: (favorites) {
                              if (favorites.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_border,
                                        size: 64,
                                        color: _secondaryText,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        context.tr(
                                          'No Favorites yet',
                                          'لا توجد أماكن مفضلة بعد',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: _textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        context.tr(
                                          'Add places from Search.',
                                          'أضف أماكن من صفحة البحث.',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: _secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 16,
                                ),
                                itemCount: favorites.length,
                                separatorBuilder: (_, __) {
                                  return const SizedBox(height: 12);
                                },
                                itemBuilder: (context, index) {
                                  final favorite = favorites[index];

                                  return _animatedItem(
                                    context,
                                    index,
                                    _buildFavoriteCard(
                                      context,
                                      ref,
                                      favorite,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // SHARED BOTTOM NAVIGATION
                const DroobiBottomNav(
                  currentItem: DroobiNavItem.favorites,
                ),
              ],
            ),
          ),

          // ADD OPTIONS + FAB
          PositionedDirectional(
            end: 20,
            bottom: 115,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_showAddOptions) ...[
                    _buildAddOption(
                      icon: Icons.search,
                      title: context.tr('Search Location', 'البحث عن موقع'),
                      subtitle: context.tr(
                        'Find a place to save',
                        'اعثر على مكان لحفظه',
                      ),
                      onTap: _openSearchLocation,
                    ),
                    const SizedBox(height: 10),
                    _buildAddOption(
                      icon: Icons.my_location,
                      title: context.tr(
                        'Add Current Location',
                        'إضافة الموقع الحالي',
                      ),
                      subtitle: context.tr(
                        'Save where you are now',
                        'احفظ مكانك الحالي',
                      ),
                      onTap: _addCurrentLocation,
                    ),
                    const SizedBox(height: 14),
                  ],
                  Semantics(
                    button: true,
                    label: _showAddOptions
                        ? context.tr(
                            'Close add location options',
                            'إغلاق خيارات إضافة موقع',
                          )
                        : context.tr(
                            'Add favorite location',
                            'إضافة موقع مفضل',
                          ),
                    child: FloatingActionButton(
                      heroTag: 'favorites_add_fab',
                      backgroundColor: _primaryBlue,
                      foregroundColor: AppColors.cream,
                      elevation: 5,
                      onPressed:
                          _addingCurrentLocation ? null : _toggleAddOptions,
                      child: _addingCurrentLocation
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.cream,
                              ),
                            )
                          : AnimatedRotation(
                              turns: _showAddOptions ? 0.125 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.add,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FAVORITE CARD
  // ===========================================================================

  Widget _buildFavoriteCard(
    BuildContext context,
    WidgetRef ref,
    FavoriteLocation favorite,
  ) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Semantics(
      container: true,
      label: context.tr(
        'Favorite location: ${favorite.label}',
        'موقع مفضل: ${favorite.label}',
      ),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openFavoriteNavigation(context, favorite),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.cream,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${favorite.latitude.toStringAsFixed(5)}, '
                        '${favorite.longitude.toStringAsFixed(5)}',
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: context.tr(
                    'Remove ${favorite.label} from Favorites',
                    'إزالة ${favorite.label} من المفضلة',
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: _secondaryText,
                    ),
                    onPressed: () => _removeFavorite(context, favorite),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: _secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// =============================================================================
// ADD FAVORITE LABEL DIALOG
// Owns its own TextEditingController so it's disposed only when the dialog's
// State is actually removed (after the exit animation).
// =============================================================================

class _AddFavoriteLabelDialog extends StatefulWidget {
  const _AddFavoriteLabelDialog();

  @override
  State<_AddFavoriteLabelDialog> createState() =>
      _AddFavoriteLabelDialogState();
}

class _AddFavoriteLabelDialogState extends State<_AddFavoriteLabelDialog> {
  late final TextEditingController _controller;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The default label follows the interface language.
    if (!_initialized) {
      _initialized = true;
      _controller = TextEditingController(
        text: context.tr('Current Location', 'الموقع الحالي'),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Add Current Location', 'إضافة الموقع الحالي')),
      content: Semantics(
        textField: true,
        label: context.tr('Favorite location label', 'اسم الموقع المفضل'),
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: InputDecoration(
            labelText: context.tr('Label', 'الاسم'),
            hintText: context.tr(
              'e.g. Home, Work, School',
              'مثل: المنزل، العمل، المدرسة',
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel', 'إلغاء')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(context.tr('Save', 'حفظ')),
        ),
      ],
    );
  }
}
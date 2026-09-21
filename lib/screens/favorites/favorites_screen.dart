import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/favorite_location.dart';
import '../../state/favorites_notifier.dart';
import '../../widgets/droobi_bottom_nav.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() =>
      _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with TickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF2F80ED);
  static const Color _cardColor = Color(0xFFF5F5F5);
  static const Color _textColor = Color(0xFF111111);
  static const Color _secondaryText = Color(0xFF6B7280);
  static const Color _heartColor = Color(0xFFEB5757);

  late final AnimationController _entranceController;
  late final AnimationController _backgroundController;
  late final Animation<double> _headerAnimation;

  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _headerAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Respect the system "remove animations" setting.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      _entranceController.value = 1.0;
      _backgroundController.stop();
    } else {
      if (!_entranceStarted) {
        _entranceStarted = true;
        _entranceController.forward();
      }

      if (!_backgroundController.isAnimating) {
        _backgroundController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  /// Fade + small upward slide, driven by the entrance animation.
  Widget _fadeSlide(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ),
        ),
        child: child,
      ),
    );
  }

  /// Each card fades and slides up when it first appears.
  /// The first cards start slightly later than each other (stagger).
  Widget _animatedItem(BuildContext context, int index, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    final delayMs = (index < 6 ? index : 6) * 120;
    final totalMs = 800 + delayMs;

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

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: Colors.white,

      body: Stack(
        children: [
          // =====================================================================
          // FAVORITES BACKGROUND
          // =====================================================================

          Positioned.fill(
            child: Image.asset(
              'assets/images/Favorites_bg.png',
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
          // A thin white layer (0.10) keeps the map clearly visible.
          // =====================================================================

          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(
                alpha: 1,
              ),
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
                            const Color(0xFFDCEBFF)
                                .withValues(alpha: 0.30),
                            Colors.white.withValues(alpha: 0.05),
                            const Color(0xFFD9F5EA)
                                .withValues(alpha: 0.25),
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
          // MAIN CONTENT
          // =====================================================================

          SafeArea(
            child: Column(
              children: [
                // =================================================================
                // MAIN CONTENT
                // =================================================================

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // =========================================================
                        // HEADER
                        // =========================================================

                        _fadeSlide(
                          _headerAnimation,
                          const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Favorites',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                  color: _textColor,
                                ),
                              ),

                              SizedBox(height: 4),

                              Text(
                                'المفضلة',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // =========================================================
                        // FAVORITES LIST
                        // =========================================================

                        Expanded(
                          child: favoritesAsync.when(
                            // -----------------------------------------------------
                            // LOADING
                            // -----------------------------------------------------

                            loading: () {
                              return const Center(
                                child:
                                    CircularProgressIndicator(
                                  color: _primaryBlue,
                                ),
                              );
                            },

                            // -----------------------------------------------------
                            // ERROR
                            // -----------------------------------------------------

                            error: (error, _) {
                              return _buildErrorState(error);
                            },

                            // -----------------------------------------------------
                            // DATA
                            // -----------------------------------------------------

                            data: (favorites) {
                              // Favorites still come only from Firestore.
                              // No demo or hardcoded locations.

                              if (favorites.isEmpty) {
                                return _buildEmptyState();
                              }

                              return ListView.separated(
                                padding:
                                    const EdgeInsets.only(
                                  top: 4,
                                  bottom: 16,
                                ),
                                itemCount: favorites.length,
                                separatorBuilder: (
                                  _,
                                  __,
                                ) {
                                  return const SizedBox(
                                    height: 12,
                                  );
                                },
                                itemBuilder: (
                                  context,
                                  index,
                                ) {
                                  final favorite =
                                      favorites[index];

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

                // =================================================================
                // SHARED BOTTOM NAVIGATION
                // =================================================================

                const DroobiBottomNav(
                  currentItem:
                      DroobiNavItem.favorites,
                ),
              ],
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
    return Semantics(
      container: true,
      label:
          'Favorite location: ${favorite.label}',
      child: Material(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(12),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(12),

          // ---------------------------------------------------------------------
          // SELECT FAVORITE
          // ---------------------------------------------------------------------

          onTap: () {
            // GPS + routing will be connected
            // in the navigation stage.

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    'Selected ${favorite.label}',
                  ),
                ),
              );
          },

          child: Padding(
            padding:
                const EdgeInsets.all(16),

            child: Row(
              children: [
                // -----------------------------------------------------------------
                // LOCATION ICON
                // -----------------------------------------------------------------

                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      const BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // -----------------------------------------------------------------
                // FAVORITE NAME
                // -----------------------------------------------------------------

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.label,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w500,
                          color:
                              _textColor,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'موقع مفضل',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              _secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // -----------------------------------------------------------------
                // HEART / REMOVE
                // -----------------------------------------------------------------

                Semantics(
                  button: true,
                  label:
                      'Remove ${favorite.label} from Favorites',
                  hint:
                      'Double tap to remove this favorite',
                  child: IconButton(
                    tooltip:
                        'Remove from Favorites',

                    constraints:
                        const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),

                    padding:
                        EdgeInsets.zero,

                    icon: const Icon(
                      Icons.favorite,
                      size: 22,
                      color: _heartColor,
                    ),

                    // -------------------------------------------------------------
                    // REMOVE FAVORITE
                    // -------------------------------------------------------------

                    onPressed: () async {
                      try {
                        await ref
                            .read(
                              favoritesActionsProvider,
                            )
                            .removeFavorite(
                              favorite.id,
                            );
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(
                          context,
                        )
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not remove this favorite.',
                                ),
                              ),
                            );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Semantics(
        liveRegion: true,
        label:
            'No favorites yet. لا توجد مفضلات حتى الآن.',
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.star_outline,
              size: 64,
              color:
                  Colors.grey.shade300,
            ),

            const SizedBox(height: 16),

            const Text(
              'No favorites yet',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color:
                    _secondaryText,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'لا توجد مفضلات حتى الآن',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:
                    Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState(
    Object error,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color:
                    Colors.grey.shade400,
              ),

              const SizedBox(height: 16),

              const Text(
                'Could not load favorites.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w500,
                  color:
                      _textColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                error.toString(),
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 12,
                  color:
                      _secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/favorite_location.dart';
import '../../models/lat_lon.dart';
import '../../state/favorites_notifier.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../navigation/live_navigation_screen.dart';

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
  static const Color _secondaryText = Color(0xFF666666);

  late final AnimationController _backgroundController;
  late final AnimationController _headerAnimation;

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
    await ref
        .read(favoritesActionsProvider)
        .removeFavorite(favorite.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '"${favorite.label}" removed from Favorites',
          ),
        ),
      );
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
      duration: Duration(
        milliseconds: 350 + (index * 70),
      ),
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ),
      curve: Curves.easeOutCubic,
      builder: (
        context,
        value,
        child,
      ) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              0,
              20 * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // =====================================================================
          // MAP BACKGROUND
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
          // =====================================================================

          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(
                alpha: 0.90,
              ),
            ),
          ),

          // =====================================================================
          // SOFT ANIMATED GRADIENT
          // =====================================================================

          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _backgroundController,
                  builder: (
                    context,
                    child,
                  ) {
                    final t =
                        Curves.easeInOut.transform(
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
                            Colors.white.withValues(
                              alpha: 0.05,
                            ),
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
                        // =======================================================
                        // HEADER
                        // =======================================================

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
                                  fontWeight:
                                      FontWeight.w500,
                                  color: _textColor,
                                ),
                              ),
                              SizedBox(height: 4),
                             
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // =======================================================
                        // FAVORITES
                        // =======================================================

                        Expanded(
                          child: favoritesAsync.when(
                            loading: () {
                              return const Center(
                                child:
                                    CircularProgressIndicator(),
                              );
                            },
                            error: (
                              error,
                              stackTrace,
                            ) {
                              return Center(
                                child: Text(
                                  'Unable to load Favorites.',
                                  style:
                                      const TextStyle(
                                    color: Colors.red,
                                    fontSize: 15,
                                  ),
                                ),
                              );
                            },
                            data: (
                              favorites,
                            ) {
                              if (favorites.isEmpty) {
                                return const Center(
                                  child: Column(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons
                                            .star_border,
                                        size: 64,
                                        color:
                                            _secondaryText,
                                      ),
                                      SizedBox(
                                        height: 16,
                                      ),
                                      Text(
                                        'No Favorites yet',
                                        style:
                                            TextStyle(
                                          fontSize: 18,
                                          fontWeight:
                                              FontWeight
                                                  .w500,
                                          color:
                                              _textColor,
                                        ),
                                      ),
                                      SizedBox(
                                        height: 6,
                                      ),
                                      Text(
                                        'Add places from Search.',
                                        style:
                                            TextStyle(
                                          fontSize: 14,
                                          color:
                                              _secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding:
                                    const EdgeInsets.only(
                                  top: 4,
                                  bottom: 16,
                                ),
                                itemCount:
                                    favorites.length,
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

          // -------------------------------------------------------------------
          // SELECT FAVORITE
          // -------------------------------------------------------------------

          onTap: () => _openFavoriteNavigation(
            context,
            favorite,
          ),

          // -------------------------------------------------------------------
          // CARD
          // -------------------------------------------------------------------

          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ----------------------------------------------------------------
                // LOCATION ICON
                // ----------------------------------------------------------------

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

                // ----------------------------------------------------------------
                // FAVORITE NAME
                // ----------------------------------------------------------------

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
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${favorite.latitude.toStringAsFixed(5)}, '
                        '${favorite.longitude.toStringAsFixed(5)}',
                        style:
                            const TextStyle(
                          fontSize: 12,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),

                // ----------------------------------------------------------------
                // DELETE
                // ----------------------------------------------------------------

                Semantics(
                  button: true,
                  label:
                      'Remove ${favorite.label} from Favorites',
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: _secondaryText,
                    ),
                    onPressed: () =>
                        _removeFavorite(
                      context,
                      favorite,
                    ),
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/favorite_location.dart';
import '../../state/favorites_notifier.dart';
import '../../widgets/droobi_bottom_nav.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2F80ED);
  static const Color _cardColor = Color(0xFFF5F5F5);
  static const Color _textColor = Color(0xFF111111);
  static const Color _secondaryText = Color(0xFF6B7280);
  static const Color _heartColor = Color(0xFFEB5757);

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ==============================================================
            // MAIN CONTENT
            // ==============================================================

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
                    // ========================================================
                    // HEADER
                    // ========================================================

                    const Text(
                      'Favorites',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: _textColor,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'المفضلة',
                      style: TextStyle(
                        fontSize: 14,
                        color: _secondaryText,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ========================================================
                    // FAVORITES LIST
                    // ========================================================

                    Expanded(
                      child: favoritesAsync.when(
                        // ----------------------------------------------------
                        // LOADING
                        // ----------------------------------------------------

                        loading: () {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _primaryBlue,
                            ),
                          );
                        },

                        // ----------------------------------------------------
                        // ERROR
                        // ----------------------------------------------------

                        error: (error, _) {
                          return _buildErrorState(error);
                        },

                        // ----------------------------------------------------
                        // DATA
                        // ----------------------------------------------------

                        data: (favorites) {
                          // IMPORTANT:
                          // No hardcoded/demo favorites.
                          // The list comes only from Firestore.

                          if (favorites.isEmpty) {
                            return _buildEmptyState();
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.only(
                              top: 4,
                              bottom: 16,
                            ),
                            itemCount: favorites.length,
                            separatorBuilder: (_, __) {
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

                              return _buildFavoriteCard(
                                context,
                                ref,
                                favorite,
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

            // ==============================================================
            // SHARED BOTTOM NAVIGATION
            // ==============================================================

            const DroobiBottomNav(
              currentItem:
                  DroobiNavItem.favorites,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // FAVORITE CARD
  // =========================================================================

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

          // ---------------------------------------------------------------
          // SELECT FAVORITE
          // ---------------------------------------------------------------

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
                // ---------------------------------------------------------
                // LOCATION ICON
                // ---------------------------------------------------------

                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      const BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // ---------------------------------------------------------
                // FAVORITE NAME
                // ---------------------------------------------------------

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

                // ---------------------------------------------------------
                // HEART / REMOVE
                // ---------------------------------------------------------

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

  // =========================================================================
  // EMPTY STATE
  // =========================================================================

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

  // =========================================================================
  // ERROR STATE
  // =========================================================================

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
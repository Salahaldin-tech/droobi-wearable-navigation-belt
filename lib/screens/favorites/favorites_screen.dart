import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/destination.dart';
import '../../models/favorite_location.dart';
import '../../models/lat_lon.dart';
import '../../services/location/location_service.dart';
import '../../state/favorites_notifier.dart';
import '../../state/location_notifier.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../destination/destination_search_screen.dart';
import '../navigation/live_navigation_screen.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with TickerProviderStateMixin {
  static const Color _primaryBlue = Color(0xFF2F80ED);
  static const Color _cardColor = Color(0xFFF5F5F5);
  static const Color _textColor = Color(0xFF111111);
  static const Color _secondaryText = Color(0xFF666666);

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
          content: Text('"${favorite.label}" removed from Favorites'),
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
            content: Text('Added "${label.trim()}" to Favorites'),
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
            content: Text(error.message),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not get your current location. Please try again.',
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
      color: Colors.white,
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
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Column(
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
      backgroundColor: Colors.white,
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
              color: Colors.white.withValues(alpha: 0.90),
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

          // MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER
                        _fadeSlide(
                          _headerAnimation,
                          const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // FAVORITES
                        Expanded(
                          child: favoritesAsync.when(
                            loading: () {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            error: (error, stackTrace) {
                              return const Center(
                                child: Text(
                                  'Unable to load Favorites.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 15,
                                  ),
                                ),
                              );
                            },
                            data: (favorites) {
                              if (favorites.isEmpty) {
                                return const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_border,
                                        size: 64,
                                        color: _secondaryText,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No Favorites yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: _textColor,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Add places from Search.',
                                        style: TextStyle(
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
          Positioned(
            right: 20,
            bottom: 115,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_showAddOptions) ...[
                    _buildAddOption(
                      icon: Icons.search,
                      title: 'Search Location',
                      subtitle: 'Find a place to save',
                      onTap: _openSearchLocation,
                    ),
                    const SizedBox(height: 10),
                    _buildAddOption(
                      icon: Icons.my_location,
                      title: 'Add Current Location',
                      subtitle: 'Save where you are now',
                      onTap: _addCurrentLocation,
                    ),
                    const SizedBox(height: 14),
                  ],
                  Semantics(
                    button: true,
                    label: _showAddOptions
                        ? 'Close add location options'
                        : 'Add favorite location',
                    child: FloatingActionButton(
                      heroTag: 'favorites_add_fab',
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      onPressed:
                          _addingCurrentLocation ? null : _toggleAddOptions,
                      child: _addingCurrentLocation
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
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
    return Semantics(
      container: true,
      label: 'Favorite location: ${favorite.label}',
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
                    color: Colors.white,
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
                  label: 'Remove ${favorite.label} from Favorites',
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'Current Location');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Current Location'),
      content: Semantics(
        textField: true,
        label: 'Favorite location label',
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'e.g. Home, Work, School',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
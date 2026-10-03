import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/destination.dart';
import '../../models/lat_lon.dart';
import '../../screens/navigation/live_navigation_screen.dart';
import '../../state/destination_search_notifier.dart';
import '../../state/favorites_notifier.dart';

// ---------------------------------------------------------------------------
// THEME
// Light background (as before). Text is mostly black/dark gray, with blue
// kept for accents (buttons, icons, links, focus states).
// ---------------------------------------------------------------------------
class _AppTheme {
  const _AppTheme._();

  static const background = Color(0xFFF7F7F9);
  static const surface = Colors.white;
  static const fieldFill = Color(0xFFF2F3F5);
  static const fieldBorder = Color(0xFFE6E7EB);

  static const textPrimary = Color(0xFF16181D);
  static const textSecondary = Color(0xFF55585F);
  static const hint = Color(0xFFB0B3BA);

  static const accent = Color(0xFF2F6FED);
  static const error = Color(0xFFE0483E);

  static const cardShadow = [
    BoxShadow(
      color: Color(0x141A1D29),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}

/// Real Destination Search screen.
///
/// Search results can be:
/// - Added to Favorites
/// - Selected as the destination for Live Navigation
class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState
    extends ConsumerState<DestinationSearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();

    // If the voice flow already produced a recognized
    // and confirmed query, prefill it and search immediately.
    final existingQuery =
        ref.read(destinationSearchProvider).query;

    if (existingQuery.isNotEmpty) {
      _controller.text = existingQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ================================================================
  // SEARCH
  // ================================================================

  void _runSearch() {
    final query = _controller.text;

    if (query.trim().isEmpty) {
      return;
    }

    ref
        .read(destinationSearchProvider.notifier)
        .search(query);
  }

  // ================================================================
  // ADD TO FAVORITES
  // ================================================================

  Future<void> _addToFavorites(
    Destination destination,
  ) async {
    // The dialog owns and disposes its own TextEditingController (see
    // _FavoriteLabelDialog below). Disposing a controller manually right
    // after showDialog() resolves here used to race the dialog's own
    // close/unmount, which is what caused the
    // "'_dependents.isEmpty': is not true." framework assertion — the
    // favorite was still added, but the TextField hadn't fully unmounted
    // yet when its controller was torn down.
    final label = await showDialog<String>(
      context: context,
      builder: (context) => _FavoriteLabelDialog(
        initialLabel: destination.name,
      ),
    );

    if (label == null || label.trim().isEmpty) {
      return;
    }

    await ref
        .read(favoritesActionsProvider)
        .addFavorite(
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
          content: Text(
            'Added "$label" to Favorites',
          ),
        ),
      );
    }
  }

  // ================================================================
  // OPEN LIVE NAVIGATION
  // ================================================================

  void _openLiveNavigation(
    Destination destination,
  ) {
    final latLon = LatLon(
      latitude: destination.latitude,
      longitude: destination.longitude,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveNavigationScreen(
          destination: latLon,
        ),
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(destinationSearchProvider);

    return Scaffold(
      backgroundColor: _AppTheme.background,
      appBar: AppBar(
        backgroundColor: _AppTheme.background,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Search Destination',
          style: TextStyle(
            color: _AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: _AppTheme.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            // --------------------------------------------------------
            // SEARCH BAR
            // --------------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: 'Search destination',
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: _AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Where do you want to go?',
                        labelStyle: const TextStyle(color: _AppTheme.hint),
                        filled: true,
                        fillColor: _AppTheme.fieldFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
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
                          borderSide: const BorderSide(color: _AppTheme.accent, width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) =>
                          _runSearch(),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Semantics(
                  button: true,
                  label: 'Search',
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : _runSearch,
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
                ),
              ],
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------------
            // LOADING
            // --------------------------------------------------------

            if (state.isLoading)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(
                  backgroundColor: _AppTheme.fieldFill,
                  valueColor: AlwaysStoppedAnimation<Color>(_AppTheme.accent),
                ),
              ),

            // --------------------------------------------------------
            // ERROR
            // --------------------------------------------------------

            if (state.errorMessage != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding:
                      const EdgeInsets.only(top: 8),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(
                      color: _AppTheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            // --------------------------------------------------------
            // NO RESULTS
            // --------------------------------------------------------

            if (!state.isLoading &&
                state.errorMessage == null &&
                state.results.isEmpty &&
                state.query.isNotEmpty)
              const Padding(
                padding:
                    EdgeInsets.only(top: 16),
                child: Text(
                  'No results found.',
                  style: TextStyle(color: _AppTheme.textSecondary),
                ),
              ),

            const SizedBox(height: 8),

            // --------------------------------------------------------
            // RESULTS
            // --------------------------------------------------------

            Expanded(
              child: ListView.separated(
                itemCount:
                    state.results.length,
                separatorBuilder:
                    (_, __) =>
                        const SizedBox(height: 8),
                itemBuilder:
                    (context, index) {
                  final destination =
                      state.results[index];

                  return Container(
                    decoration: BoxDecoration(
                      color: _AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _AppTheme.cardShadow,
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
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

                      trailing: Semantics(
                        button: true,
                        label:
                            'Add ${destination.name} '
                            'to Favorites',
                        child: IconButton(
                          icon: const Icon(
                            Icons.star_border,
                          ),
                          color: _AppTheme.accent,
                          onPressed: () =>
                              _addToFavorites(
                            destination,
                          ),
                        ),
                      ),

                      // ------------------------------------------------
                      // SELECT DESTINATION
                      // ------------------------------------------------
                      //
                      // Instead of returning the destination to
                      // another screen, the real production flow now
                      // opens Live Navigation directly.
                      //
                      onTap: () =>
                          _openLiveNavigation(
                        destination,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Add to Favorites" label dialog.
///
/// This owns its TextEditingController internally and disposes it in its
/// own State.dispose(), so the controller's lifecycle is always correctly
/// synced with the dialog's actual element lifecycle — rather than being
/// disposed manually by the caller right after showDialog() returns, which
/// can race the dialog's close animation and trigger a framework assertion.
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
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        'Add to Favorites',
        style: TextStyle(
          color: _AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Semantics(
        textField: true,
        label: 'Favorite label',
        child: TextField(
          controller: _labelController,
          style: const TextStyle(color: _AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Label',
            labelStyle: const TextStyle(color: _AppTheme.textSecondary),
            filled: true,
            fillColor: _AppTheme.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AppTheme.fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AppTheme.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AppTheme.accent, width: 1.5),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(foregroundColor: _AppTheme.textSecondary),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_labelController.text);
          },
          style: FilledButton.styleFrom(
            backgroundColor: _AppTheme.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
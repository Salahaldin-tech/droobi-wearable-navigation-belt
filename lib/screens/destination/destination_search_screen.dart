import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/destination.dart';
import '../../state/destination_search_notifier.dart';
import '../../state/favorites_notifier.dart';

/// Real Destination Search screen. Reuses the exact same
/// destinationSearchProvider validated in the Stage 7 test screen -
/// no changes to the search service layer were needed.
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
    // If the voice flow already produced a recognized+confirmed query,
    // prefill it and search immediately.
    final existingQuery = ref.read(destinationSearchProvider).query;
    if (existingQuery.isNotEmpty) {
      _controller.text = existingQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch() {
    final query = _controller.text;
    if (query.trim().isEmpty) return;
    ref.read(destinationSearchProvider.notifier).search(query);
  }

  Future<void> _addToFavorites(Destination destination) async {
    final labelController = TextEditingController(text: destination.name);
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Favorites'),
        content: Semantics(
          textField: true,
          label: 'Favorite label',
          child: TextField(
            controller: labelController,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(labelController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (label == null || label.trim().isEmpty) return;
    await ref.read(favoritesActionsProvider).addFavorite(
          label: label.trim(),
          destination: destination,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "$label" to Favorites')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(destinationSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Destination')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: 'Search destination',
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Where do you want to go?',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _runSearch(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'Search',
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : _runSearch,
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.isLoading) const LinearProgressIndicator(),
            if (state.errorMessage != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            if (!state.isLoading &&
                state.errorMessage == null &&
                state.results.isEmpty &&
                state.query.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('No results found.'),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: state.results.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final destination = state.results[index];
                  return ListTile(
                    title: Text(destination.name),
                    subtitle: Text(destination.address ?? ''),
                    trailing: Semantics(
                      button: true,
                      label: 'Add ${destination.name} to Favorites',
                      child: IconButton(
                        icon: const Icon(Icons.star_border),
                        onPressed: () => _addToFavorites(destination),
                      ),
                    ),
                    onTap: () {
                      // Selecting a destination to start navigation is
                      // wired up in the GPS/routing stage - out of
                      // scope here. For now this just confirms the
                      // selection is registered.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected ${destination.name}')),
                      );
                    },
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

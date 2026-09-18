import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/destination.dart';
import '../../state/destination_search_notifier.dart';

/// TEMPORARY screen for Stage 7 validation only.
///
/// Purpose: prove the destination search service layer (Places API
/// (New) Text Search) returns real, correctly-parsed results before
/// any real Destination Search UI, voice input, or routing exists.
///
/// This screen is NOT part of the final Droobi UI and should be
/// removed/replaced once the real Destination Search screen (later
/// stage) is built.
class DestinationSearchTestScreen extends ConsumerStatefulWidget {
  const DestinationSearchTestScreen({super.key});

  @override
  ConsumerState<DestinationSearchTestScreen> createState() =>
      _DestinationSearchTestScreenState();
}

class _DestinationSearchTestScreenState
    extends ConsumerState<DestinationSearchTestScreen> {
  final TextEditingController _controller = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(destinationSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Droobi - Destination Search Test (Stage 7)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Search destination',
                      hintText: 'e.g. "Arab American University"',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _runSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: state.isLoading ? null : _runSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.isLoading) const LinearProgressIndicator(),
            if (state.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            if (!state.isLoading &&
                state.errorMessage == null &&
                state.results.isEmpty &&
                state.query.isNotEmpty)
              const Text('No results found.'),
            Expanded(
              child: ListView.separated(
                itemCount: state.results.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) =>
                    _DestinationResultTile(destination: state.results[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationResultTile extends StatelessWidget {
  const _DestinationResultTile({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(destination.name),
      subtitle: Text(
        '${destination.address ?? "No address returned"}\n'
        'lat: ${destination.latitude}, lng: ${destination.longitude}',
      ),
      isThreeLine: true,
    );
  }
}

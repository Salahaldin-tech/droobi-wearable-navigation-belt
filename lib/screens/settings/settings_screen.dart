import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/belt_connection_state.dart';
import '../../core/enums/voice_language.dart';
import '../../state/auth_state_notifier.dart';
import '../../state/belt_connection_notifier.dart';
import '../../state/voice_language_notifier.dart';
import '../../widgets/accessible_button.dart';
import '../../widgets/connection_status_indicator.dart';
import '../test/dev_test_menu.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(beltConnectionStateProvider);
    final beltService = ref.watch(beltConnectionServiceProvider);
    final state = connectionAsync.value ?? beltService.currentState;

    final voiceLanguage = ref.watch(voiceLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Belt Connection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ConnectionStatusIndicator(state: state),
            const SizedBox(height: 12),
            AccessibleButton(
              label: state == BeltConnectionState.connected
                  ? 'Disconnect Belt'
                  : 'Connect / Reconnect Belt',
              icon: Icons.bluetooth,
              onPressed: () {
                if (state == BeltConnectionState.connected) {
                  beltService.disconnect();
                } else {
                  beltService.scanAndConnect();
                }
              },
            ),

            const SizedBox(height: 24),

            Text(
              'Voice Language',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  RadioListTile<VoiceLanguage>(
                    value: VoiceLanguage.arabic,
                    groupValue: voiceLanguage,
                    title: const Text('العربية'),
                    secondary: const Icon(Icons.language),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(voiceLanguageProvider.notifier)
                            .setLanguage(value);
                      }
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<VoiceLanguage>(
                    value: VoiceLanguage.english,
                    groupValue: voiceLanguage,
                    title: const Text('English'),
                    secondary: const Icon(Icons.language),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(voiceLanguageProvider.notifier)
                            .setLanguage(value);
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Account',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AccessibleButton(
              label: 'Sign Out',
              icon: Icons.logout,
              onPressed: () => ref.read(authServiceProvider).signOut(),
            ),

            const SizedBox(height: 24),

            Text(
              'Developer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AccessibleButton(
              label: 'Dev Test Menu',
              icon: Icons.build,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DevTestMenu(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
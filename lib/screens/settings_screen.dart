import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/search_provider.dart';
import '../providers/settings_provider.dart';
import 'log_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Providers'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final enabledIds = settings.enabledProviders;
          final disabledIds = allSearchProviders
              .map((p) => p.id)
              .where((id) => !enabledIds.contains(id))
              .toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (enabledIds.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Text(
                    'Enabled (drag to reorder)',
                    style: textTheme.labelLarge,
                  ),
                ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: enabledIds.length,
                  onReorderItem: settings.reorder,
                  itemBuilder: (context, index) {
                    final provider = getProviderById(enabledIds[index]);
                    final isLastEnabled = enabledIds.length == 1;
                    return _ProviderTile(
                      key: ValueKey(provider.id),
                      provider: provider,
                      enabled: true,
                      isLastEnabled: isLastEnabled,
                      onToggle: () => settings.toggle(provider.id),
                      index: index,
                    );
                  },
                ),
              ],
              if (disabledIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Text(
                    'Disabled',
                    style: textTheme.labelLarge,
                  ),
                ),
                ...disabledIds.map((id) {
                  final provider = getProviderById(id);
                  return _ProviderTile(
                    key: ValueKey(provider.id),
                    provider: provider,
                    enabled: false,
                    isLastEnabled: false,
                    onToggle: () => settings.toggle(provider.id),
                    index: 0,
                  );
                }),
              ],
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.terminal),
                title: const Text('View App Logs'),
                subtitle: const Text('See output from print() calls and errors'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogScreen()),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final SearchProvider provider;
  final bool enabled;
  final bool isLastEnabled;
  final VoidCallback onToggle;
  final int index;

  const _ProviderTile({
    super.key,
    required this.provider,
    required this.enabled,
    required this.isLastEnabled,
    required this.onToggle,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final supported = provider.lookupTypes
        .map((t) => t.name.toUpperCase())
        .join(' / ');

    return ListTile(
      leading: enabled
          ? ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle, color: Colors.grey),
            )
          : const Icon(Icons.block, color: Colors.grey),
      title: Text(
        provider.label,
        style: textTheme.titleMedium?.copyWith(
          color: enabled ? null : colorScheme.outline,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider.description,
            style: TextStyle(color: enabled ? null : colorScheme.outline),
          ),
          const SizedBox(height: 2),
          Text(
            supported,
            style: textTheme.labelSmall?.copyWith(
              color: enabled
                  ? colorScheme.primary
                  : colorScheme.outline,
            ),
          ),
        ],
      ),
      trailing: Switch(
        value: enabled,
        onChanged: isLastEnabled && enabled ? null : (_) => onToggle(),
      ),
    );
  }
}

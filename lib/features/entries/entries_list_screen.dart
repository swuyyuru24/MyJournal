import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';

class EntriesListScreen extends ConsumerWidget {
  const EntriesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(entriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('All entries')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No entries yet.'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              final d = e.entryDate;
              return ListTile(
                leading: Icon(e.completedAt != null
                    ? Icons.check_circle
                    : Icons.edit_note),
                title: Text(e.template?.name ?? 'Entry'),
                subtitle: Text(
                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/entries/${e.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

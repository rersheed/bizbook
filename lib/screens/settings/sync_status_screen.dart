import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/supabase_config.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final queue = store.syncQueue;

    Color statusColor(SyncStatus s) {
      switch (s) {
        case SyncStatus.synced:
          return BizColors.secondary;
        case SyncStatus.failed:
          return BizColors.danger;
        case SyncStatus.pending:
          return BizColors.highlight;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync status'),
        actions: [
          TextButton(
            onPressed: () async {
              await store.runSync();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(store.supabaseReady
                      ? 'Sync finished'
                      : 'Demo mode — local only'),
                ),
              );
            },
            child: const Text('Sync now'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SupabaseConfig.isConfigured
                          ? 'Supabase connected'
                          : 'Offline demo mode',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      SupabaseConfig.isConfigured
                          ? SupabaseConfig.url
                          : 'Data stays on this device until keys are configured.',
                      style: const TextStyle(
                          color: BizColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _pill('${store.pendingSyncCount} pending',
                            BizColors.highlight),
                        const SizedBox(width: 8),
                        _pill(
                            '${queue.where((e) => e.status == SyncStatus.synced).length} synced',
                            BizColors.secondary),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Outbox'),
              const SizedBox(height: 8),
              if (queue.isEmpty)
                const EmptyState(
                  icon: Icons.cloud_done_outlined,
                  title: 'Queue empty',
                  subtitle: 'New sales & expenses appear here',
                )
              else
                ...queue.take(40).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_upload_outlined,
                                color: statusColor(item.status)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.entity} · ${item.entityId.substring(0, item.entityId.length.clamp(0, 12))}…',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  Text(friendlyDate(item.createdAt),
                                      style: const TextStyle(
                                          color: BizColors.muted,
                                          fontSize: 12)),
                                  if (item.error != null)
                                    Text(item.error!,
                                        style: const TextStyle(
                                            color: BizColors.muted,
                                            fontSize: 11)),
                                ],
                              ),
                            ),
                            Text(item.status.name,
                                style: TextStyle(
                                    color: statusColor(item.status),
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

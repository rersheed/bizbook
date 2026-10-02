import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/supabase_config.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../widgets/widgets.dart';
import '../auth/login_screen.dart';
import '../reports/reports_screen.dart';
import '../staff/staff_screen.dart';
import 'business_profile_screen.dart';
import 'sync_status_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SoftCard(
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/images/logo_64.png',
                          width: 52, height: 52),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.currentUser?.fullName ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(store.currentUser?.email ?? '',
                              style: const TextStyle(
                                  color: BizColors.muted, fontSize: 13)),
                          Text(
                            '${store.business?.name ?? ''} · ${store.isOwner ? 'Owner' : 'Staff'}',
                            style: const TextStyle(
                                color: BizColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _tile(
                context,
                Icons.storefront_outlined,
                'Business profile',
                'Name, phone, currency',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BusinessProfileScreen()),
                ),
              ),
              if (store.isOwner)
                _tile(
                  context,
                  Icons.group_outlined,
                  'Staff management',
                  'Invite or disable staff',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StaffScreen()),
                  ),
                ),
              if (store.isOwner)
                _tile(
                  context,
                  Icons.bar_chart_rounded,
                  'Reports',
                  'Sales, expenses, net, staff activity',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  ),
                ),
              _tile(
                context,
                Icons.sync,
                'Sync status',
                store.supabaseReady
                    ? '${store.pendingSyncCount} pending'
                    : 'Demo / offline outbox',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
                ),
              ),
              _tile(
                context,
                Icons.info_outline,
                'About BizBook',
                'V1 · ${SupabaseConfig.isConfigured ? 'Supabase wired' : 'Demo mode'}',
                () => showAboutDialog(
                  context: context,
                  applicationName: 'BizBook',
                  applicationVersion: '1.0.0',
                  applicationLegalese:
                      'Simple small-business sales & expense tracking.',
                  children: [
                    const SizedBox(height: 12),
                    Text('Backend: ${SupabaseConfig.url}'),
                    const Text('Offline-first with sync queue.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await store.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset demo data?'),
                      content: const Text(
                          'Reloads Haruna Stores sample products, sales, and expenses.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Reset')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await store.resetDemoData();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
                child: const Text('Reset demo data',
                    style: TextStyle(color: BizColors.danger)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String sub,
      VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: BizColors.accent,
            child: Icon(icon, color: BizColors.primary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

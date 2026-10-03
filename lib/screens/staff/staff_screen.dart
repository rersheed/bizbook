import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  Future<void> _invite(BuildContext context) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Invite staff',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Creates a staff login for this business. They sign in with the email and password you set.',
              style: TextStyle(color: BizColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Display name *')),
            const SizedBox(height: 10),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password (6+) *'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty ||
                    email.text.trim().isEmpty ||
                    password.text.length < 6) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Create staff login'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final store = context.read<AppStore>();
    final err = await store.inviteStaff(
          email: email.text,
          displayName: name.text,
          password: password.text,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? store.staffNotice ?? 'Staff added'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!store.isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Owners only',
          subtitle: 'Ask your business owner to manage staff',
        ),
      );
    }
    final list = store.members.toList()
      ..sort((a, b) => a.role == MemberRole.owner ? -1 : a.displayName.compareTo(b.displayName));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: BizColors.primary),
            onPressed: () => _invite(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final m = list[i];
              final isOwner = m.role == MemberRole.owner;
              return SoftCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isOwner
                          ? BizColors.primary
                          : BizColors.accent,
                      foregroundColor:
                          isOwner ? Colors.white : BizColors.primary,
                      child: Text(
                        m.displayName.isNotEmpty
                            ? m.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text(m.email,
                              style: const TextStyle(
                                  color: BizColors.muted, fontSize: 12)),
                          Text(
                            '${isOwner ? 'Owner' : 'Staff'}${m.isActive ? '' : ' · Disabled'}',
                            style: TextStyle(
                              color: m.isActive
                                  ? BizColors.secondary
                                  : BizColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isOwner)
                      Switch(
                        value: m.isActive,
                        activeThumbColor: BizColors.primary,
                        onChanged: (v) =>
                            store.setMemberActive(m.id, v),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

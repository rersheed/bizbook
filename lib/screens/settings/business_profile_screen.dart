import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_store.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  late TextEditingController name;
  late TextEditingController phone;
  late TextEditingController email;
  late TextEditingController address;
  late String currency;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final b = context.read<AppStore>().business!;
    name = TextEditingController(text: b.name);
    phone = TextEditingController(text: b.phone ?? '');
    email = TextEditingController(text: b.email ?? '');
    address = TextEditingController(text: b.address ?? '');
    currency = b.currency;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<AppStore>();
    if (!store.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only owners can edit business profile')),
      );
      return;
    }
    setState(() => saving = true);
    final ok = await store.updateBusiness(store.business!.copyWith(
      name: name.text.trim(),
      phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
      email: email.text.trim().isEmpty ? null : email.text.trim(),
      address: address.text.trim().isEmpty ? null : address.text.trim(),
      currency: currency,
      currencySymbol:
          currency == 'NGN' ? '₦' : (currency == 'USD' ? '\$' : currency),
    ));
    setState(() => saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Business updated' : (store.lastError ?? 'Update failed')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final readOnly = !store.isOwner;
    return Scaffold(
      appBar: AppBar(title: const Text('Business profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: name,
                readOnly: readOnly,
                decoration: const InputDecoration(labelText: 'Business name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                readOnly: readOnly,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                readOnly: readOnly,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                readOnly: readOnly,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: const [
                  DropdownMenuItem(value: 'NGN', child: Text('NGN — ₦')),
                  DropdownMenuItem(value: 'USD', child: Text('USD — \$')),
                  DropdownMenuItem(value: 'GHS', child: Text('GHS')),
                  DropdownMenuItem(value: 'KES', child: Text('KES')),
                ],
                onChanged: readOnly
                    ? null
                    : (v) => setState(() => currency = v ?? 'NGN'),
              ),
              const SizedBox(height: 24),
              if (!readOnly)
                FilledButton(
                  onPressed: saving ? null : _save,
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save changes'),
                ),
              if (readOnly)
                const Text('Staff can view but not edit business settings.',
                    style: TextStyle(color: BizColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

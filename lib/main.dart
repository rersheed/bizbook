import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'data/app_store.dart';
import 'screens/auth/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      debugPrint('Supabase initialized: ${SupabaseConfig.url}');
    } catch (e) {
      debugPrint('Supabase init failed (continuing in local demo): $e');
    }
  } else {
    debugPrint('Supabase not configured — demo offline mode');
  }

  final store = AppStore();
  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const BizBookApp(),
    ),
  );
}

class BizBookApp extends StatelessWidget {
  const BizBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BizBook',
      debugShowCheckedModeBanner: false,
      theme: buildBizTheme(),
      home: const SplashScreen(),
    );
  }
}

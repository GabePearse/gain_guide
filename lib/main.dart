import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_navigation.dart';
import 'pages/auth_page.dart';
import 'providers/workout_provider.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://pfrqedznfuuzzueptwed.supabase.co',
    anonKey: 'sb_publishable_L6mWwu0Gy2mIyZTu2U_xFw_L0Nvkv7U',
  );

  if (!kIsWeb) {
    await NotificationService.instance.initialize();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => WorkoutProvider()..initialize(),
      child: const GainGuideApp(),
    ),
  );
}

class GainGuideApp extends StatelessWidget {
  const GainGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GainGuide',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}

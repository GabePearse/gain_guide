import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_navigation.dart';
import 'pages/auth_page.dart';
import 'providers/workout_provider.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();

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

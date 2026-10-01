import 'package:flutter/material.dart';

import 'features/unscramble/presentation/home_screen.dart';
import 'shared/theme/app_theme.dart';

class UnscrambleApp extends StatelessWidget {
  const UnscrambleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unscramble',

      debugShowCheckedModeBanner: false,

      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}

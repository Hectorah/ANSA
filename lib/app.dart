import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/scanner/presentation/scanner_screen.dart';
import 'features/shop/presentation/shop_screen.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ScannerScreen(),
        ),
        GoRoute(
          path: '/shop',
          builder: (context, state) => const ShopScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'KLK POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/auth.dart';
import 'screens/home_tabs.dart';
import 'screens/onboarding.dart';
import 'services/fire.dart';
import 'state/driver_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Fire.init();
  await initializeDateFormatting('pt_BR');
  runApp(const NexmarketEntregadorApp());
}

class NexmarketEntregadorApp extends StatelessWidget {
  const NexmarketEntregadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DriverState(),
      child: Consumer<DriverState>(
        builder: (context, state, _) {
          final dark = state.driver?.preferences.darkMode ?? false;
          Widget home;
          if (!state.isLoggedIn) {
            home = const LoginScreen();
          } else if (state.profileLoaded && state.driver == null) {
            // Conta criada mas sem perfil de entregador -> onboarding.
            home = const OnboardingScreen();
          } else {
            home = const HomeTabs();
          }
          return MaterialApp(
            title: 'Nexmarket Entregador',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(dark: dark),
            home: home,
          );
        },
      ),
    );
  }
}

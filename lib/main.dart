import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/auth.dart';
import 'screens/documents_screen.dart';
import 'screens/home_tabs.dart';
import 'screens/onboarding.dart';
import 'services/fire.dart';
import 'services/splash.dart';
import 'state/driver_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Timeout: em rede ruim o carregamento do SDK web pode pendurar sem
    // rejeitar — cai na tela de retry em vez de tela branca.
    await Fire.init().timeout(const Duration(seconds: 15));
    await initializeDateFormatting('pt_BR');
    _run(const NexmarketEntregadorApp());
  } catch (e) {
    // Sem rede/Firebase indisponível: tela de erro com retry em vez de
    // tela branca (importante no web).
    _run(StartupErrorApp(error: '$e', retry: main));
  }
}

/// `runApp` + aviso à splash do `index.html` de que já há pixels na tela.
///
/// O callback roda depois do primeiro frame, então vale tanto para o app
/// quanto para a tela de erro: as duas trocam a splash por algo visível.
void _run(Widget app) {
  runApp(app);
  WidgetsBinding.instance.addPostFrameCallback((_) => removeWebSplash());
}

class StartupErrorApp extends StatelessWidget {
  final String error;
  final Future<void> Function() retry;
  const StartupErrorApp({super.key, required this.error, required this.retry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Color(0xFF58CC02)),
                const SizedBox(height: 16),
                const Text('Sem conexão com o servidor',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Verifique sua internet e tente novamente.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF58CC02)),
                  onPressed: retry,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
          } else if (state.driver != null && !state.driver!.isApproved) {
            // Cadastro só libera o app depois da aprovação na Empresa.
            home = const PendingApprovalScreen();
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

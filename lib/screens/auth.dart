import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/fire.dart';
import '../services/identity_api.dart';
import '../theme.dart';

/// Login/cadastro por e-mail + recuperação de senha. Após criar a conta o
/// entregador cai no onboarding (documentos + veículo).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      if (_registerMode) {
        await Fire.auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _password.text);
      } else {
        await Fire.auth.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _password.text);
      }
      // Registra o papel na identidade única da plataforma: o mesmo e-mail
      // é a mesma pessoa nos quatro apps (e dispara as boas-vindas).
      await IdentityApi.claim(role: 'entregador');
      // O gate do main.dart decide entre onboarding e painel.
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: kGreen, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.sports_motorsports,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text(_registerMode ? 'Criar conta' : 'Nexmarket Entregador',
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
                _registerMode
                    ? 'Cadastre-se para começar a entregar'
                    : 'Entre para ficar online e receber corridas',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 28),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_registerMode ? 'Cadastrar' : 'Entrar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _registerMode = !_registerMode),
              child: Text(_registerMode
                  ? 'Já tenho conta — entrar'
                  : 'Quero me cadastrar'),
            ),
            if (!_registerMode)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RecoveryScreen())),
                child: const Text('Esqueci minha senha'),
              ),
          ],
        ),
      ),
    );
  }
}

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _email = TextEditingController();
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
              'Enviaremos um link de redefinição para o seu e-mail. A nova '
              'senha vale para todos os apps da Nexmarket.'),
          const SizedBox(height: 16),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sent
                ? null
                : () async {
                    // Servidor primeiro (senha única para todos os apps);
                    // sem ele, cai no envio nativo do Firebase.
                    if (await IdentityApi.forgotPassword(_email.text.trim())) {
                      if (context.mounted) setState(() => _sent = true);
                      return;
                    }
                    try {
                      await Fire.auth
                          .sendPasswordResetEmail(email: _email.text.trim());
                      setState(() => _sent = true);
                    } on FirebaseAuthException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(authError(e))));
                      }
                    }
                  },
            child: Text(_sent ? 'E-mail enviado ✓' : 'Enviar link'),
          ),
        ],
      ),
    );
  }
}

String authError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'E-mail ou senha incorretos.';
    case 'email-already-in-use':
      return 'Este e-mail já está cadastrado.';
    case 'weak-password':
      return 'A senha precisa ter pelo menos 6 caracteres.';
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'network-request-failed':
      return 'Sem conexão. Tente novamente.';
    default:
      return 'Não foi possível concluir (${e.code}).';
  }
}

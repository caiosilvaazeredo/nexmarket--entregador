import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/drivers_repo.dart';
import '../state/driver_state.dart';

/// Onboarding: dados pessoais + veículo. Os documentos (CNH, doc. do veículo,
/// foto) ficam com status `pending` até a aprovação no painel da loja; o
/// upload dos arquivos pode ser feito depois pelo Perfil.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _cpf = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  String _vehicleType = 'moto';
  bool _busy = false;

  /// CPF válido pelos dígitos verificadores — o painel da Empresa usa o CPF
  /// para checagem de antecedentes e lista de bloqueio.
  static bool _isValidCpf(String input) {
    final d = input.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
    int digit(int len) {
      var sum = 0;
      for (var i = 0; i < len; i++) {
        sum += (d.codeUnitAt(i) - 48) * (len + 1 - i);
      }
      final rest = (sum * 10) % 11;
      return rest == 10 ? 0 : rest;
    }

    return digit(9) == d.codeUnitAt(9) - 48 && digit(10) == d.codeUnitAt(10) - 48;
  }

  static const _vehicles = [
    ('moto', 'Moto', Icons.two_wheeler),
    ('carro', 'Carro', Icons.directions_car),
    ('bike', 'Bike', Icons.pedal_bike),
    ('van', 'Van', Icons.airport_shuttle),
  ];

  Future<void> _finish() async {
    final state = context.read<DriverState>();
    final user = state.user;
    if (user == null) return;
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha nome e celular.')));
      return;
    }
    if (!_isValidCpf(_cpf.text)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('CPF inválido.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await DriversRepo.createProfile(
        user.uid,
        name: _name.text.trim(),
        email: user.email ?? '',
        phone: _phone.text.trim(),
        cpf: _cpf.text.replaceAll(RegExp(r'\D'), ''),
        vehicle: Vehicle(
          type: _vehicleType,
          model: _model.text.trim(),
          plate: _plate.text.trim().toUpperCase(),
        ),
      );
      // O gate do main.dart leva para o envio de documentos: a conta nasce
      // pendente e só abre o app depois da aprovação no painel da Empresa.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completar cadastro'),
        actions: [
          TextButton(
            onPressed: () => context.read<DriverState>().signOut(),
            child: const Text('Sair'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Seus dados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome completo')),
          const SizedBox(height: 12),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Celular (com DDD)')),
          const SizedBox(height: 12),
          TextField(
              controller: _cpf,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'CPF',
                  helperText: 'Usado na análise do seu cadastro')),
          const SizedBox(height: 24),
          const Text('Seu veículo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final (value, label, icon) in _vehicles)
                ChoiceChip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  selected: _vehicleType == value,
                  onSelected: (_) => setState(() => _vehicleType = value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _model,
              decoration: const InputDecoration(
                  labelText: 'Modelo (ex.: Honda CG 160)')),
          const SizedBox(height: 12),
          TextField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Placa')),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'No próximo passo você envia CNH, documento do '
                        'veículo, foto e comprovante de residência. A equipe '
                        'da Nexmarket analisa e libera sua conta para receber '
                        'corridas.',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _finish,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continuar para os documentos'),
          ),
        ],
      ),
    );
  }
}

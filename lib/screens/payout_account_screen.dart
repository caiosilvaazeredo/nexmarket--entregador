import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/drivers_repo.dart';
import '../services/payout_account.dart';
import '../state/driver_state.dart';
import '../theme.dart';

/// Onde o entregador quer receber os ganhos: chave PIX (com tipo validado) ou
/// conta bancária. Mostra também **quando** o pagamento cai — calendário
/// definido pela Nexmarket no app da Empresa.
class PayoutAccountScreen extends StatefulWidget {
  const PayoutAccountScreen({super.key});

  @override
  State<PayoutAccountScreen> createState() => _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends State<PayoutAccountScreen> {
  late BankInfo _bank;
  final _holder = TextEditingController();
  final _cpf = TextEditingController();
  final _pixKey = TextEditingController();
  final _bankName = TextEditingController();
  final _agency = TextEditingController();
  final _account = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _bank = context.read<DriverState>().driver?.bank ?? BankInfo();
    _holder.text = _bank.holderName;
    _cpf.text = _bank.cpf;
    _pixKey.text = _bank.pixKey;
    _bankName.text = _bank.bankName;
    _agency.text = _bank.agency;
    _account.text = _bank.account;
  }

  Future<void> _save() async {
    final uid = context.read<DriverState>().user?.uid;
    if (uid == null) return;

    if (_holder.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome do titular.');
      return;
    }
    if (_cpf.text.trim().isNotEmpty && !isValidCpf(_cpf.text)) {
      setState(() => _error = 'CPF do titular inválido.');
      return;
    }
    if (_bank.usesPix) {
      final problem =
          validatePixKey(pixKeyTypeFrom(_bank.pixKeyType), _pixKey.text);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    } else {
      if (_bankName.text.trim().isEmpty) {
        setState(() => _error = 'Informe o banco.');
        return;
      }
      if (onlyDigits(_agency.text).isEmpty || onlyDigits(_account.text).isEmpty) {
        setState(() => _error = 'Informe agência e conta.');
        return;
      }
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final updated = _bank.copyWith(
        holderName: _holder.text.trim(),
        cpf: onlyDigits(_cpf.text),
        pixKey: _pixKey.text.trim(),
        bankName: _bankName.text.trim(),
        agency: _agency.text.trim(),
        account: _account.text.trim(),
      );
      await DriversRepo.update(uid, {'bank': updated.toMap()});
      if (mounted) {
        setState(() {
          _bank = updated;
          _saved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dados de recebimento salvos!')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _set(BankInfo Function(BankInfo) update) {
    setState(() {
      _bank = update(_bank);
      _saved = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onde você recebe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quando cai o dinheiro (definido pela Empresa)
          StreamBuilder<PayoutSchedule?>(
            stream: PayoutRepo.schedule(),
            builder: (context, snap) {
              final s = snap.data;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.event_available, color: kGreenDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quando você recebe',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                                s?.description ??
                                    'Calendário definido pela Nexmarket.',
                                style: const TextStyle(fontSize: 12.5)),
                            if (s != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                    'Próximo pagamento: '
                                    '${DateFormat('dd/MM/yyyy').format(s.nextPayoutDate())}',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: kGreenDark)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pix', label: Text('PIX'), icon: Icon(Icons.pix)),
              ButtonSegment(
                  value: 'bank',
                  label: Text('Conta bancária'),
                  icon: Icon(Icons.account_balance)),
            ],
            selected: {_bank.usesPix ? 'pix' : 'bank'},
            onSelectionChanged: (s) => _set((b) => b.copyWith(method: s.first)),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _holder,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome do titular'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cpf,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'CPF do titular'),
          ),
          const SizedBox(height: 12),

          if (_bank.usesPix) ...[
            DropdownButtonFormField<PixKeyType>(
              value: pixKeyTypeFrom(_bank.pixKeyType),
              decoration: const InputDecoration(labelText: 'Tipo de chave PIX'),
              items: [
                for (final t in PixKeyType.values)
                  DropdownMenuItem(value: t, child: Text(pixKeyLabels[t]!)),
              ],
              onChanged: (t) => _set(
                  (b) => b.copyWith(pixKeyType: pixKeyTypeToString(t ?? PixKeyType.cpf))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pixKey,
              decoration: const InputDecoration(
                  labelText: 'Chave PIX',
                  helperText: 'Precisa estar no seu nome para receber'),
              onChanged: (_) => setState(() => _saved = false),
            ),
          ] else ...[
            TextField(
              controller: _bankName,
              decoration: const InputDecoration(labelText: 'Banco'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _agency,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Agência'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _account,
                    decoration:
                        const InputDecoration(labelText: 'Conta (com dígito)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'checking', label: Text('Corrente')),
                ButtonSegment(value: 'savings', label: Text('Poupança')),
              ],
              selected: {_bank.accountType},
              onSelectionChanged: (s) =>
                  _set((b) => b.copyWith(accountType: s.first)),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ],
          if (_saved && _error == null) ...[
            const SizedBox(height: 12),
            const Text('Dados salvos ✓',
                style: TextStyle(color: kGreenDark, fontWeight: FontWeight.w700)),
          ],

          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar dados de recebimento'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Seus dados bancários são vistos apenas por você e pela '
                    'equipe financeira da Nexmarket.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/drivers_repo.dart';
import '../state/driver_state.dart';
import '../theme.dart';

/// Carteira: saldo, ganhos por período e solicitação de saque via PIX.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DriverState>();
    final driver = state.driver;
    final balance = driver?.balance ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Carteira')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: kGreen,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saldo disponível',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .9))),
                  Text(money(balance),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(
                      '${driver?.totalDeliveries ?? 0} entregas · '
                      '★ ${(driver?.rating ?? 5).toStringAsFixed(1)}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .9))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _tile('Hoje', state.earningsToday),
              const SizedBox(width: 10),
              _tile('Semana', state.earningsWeek),
              const SizedBox(width: 10),
              _tile('Mês', state.earningsMonth),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.pix),
            label: const Text('Solicitar saque'),
            onPressed:
                balance <= 0 ? null : () => _requestPayout(context, balance),
          ),
          const SizedBox(height: 20),
          const Text('Saques',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (state.user != null)
            StreamBuilder<List<Payout>>(
              stream: DriversRepo.payouts(state.user!.uid),
              builder: (context, snap) {
                final payouts = snap.data ?? [];
                if (payouts.isEmpty) {
                  return Text('Nenhum saque solicitado ainda.',
                      style: TextStyle(color: Colors.grey.shade600));
                }
                return Column(
                  children: [
                    for (final p in payouts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              p.status == 'paid'
                                  ? Icons.check_circle
                                  : p.status == 'rejected'
                                      ? Icons.cancel
                                      : Icons.schedule,
                              color: p.status == 'paid'
                                  ? kGreenDark
                                  : p.status == 'rejected'
                                      ? Colors.redAccent
                                      : Colors.orange,
                            ),
                            title: Text(money(p.amount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            subtitle: Text(_payoutLabel(p)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  static String _payoutLabel(Payout p) {
    const labels = {
      'requested': 'Solicitado',
      'processing': 'Em processamento',
      'paid': 'Pago',
      'rejected': 'Recusado',
    };
    final when = tsMillis(p.createdAt);
    final date = when > 0
        ? DateFormat('dd/MM/yyyy HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(when))
        : '';
    return '${labels[p.status] ?? p.status} · $date';
  }

  Widget _tile(String label, double value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(money(value),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestPayout(BuildContext context, double balance) async {
    final state = context.read<DriverState>();
    final uid = state.user?.uid;
    if (uid == null) return;
    final amountCtrl =
        TextEditingController(text: balance.toStringAsFixed(2));
    final pixCtrl =
        TextEditingController(text: state.driver?.bank.pixKey ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Solicitar saque',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Valor (máx. ${money(balance)})'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pixCtrl,
              decoration: const InputDecoration(labelText: 'Chave PIX'),
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar')),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final amount =
        double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    final pix = pixCtrl.text.trim();
    if (amount <= 0 || amount > balance || pix.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Informe um valor válido e a chave PIX.')));
      }
      return;
    }
    await DriversRepo.requestPayout(uid, amount: amount, pixKey: pix);
    // Guarda a chave para o próximo saque.
    await DriversRepo.update(uid, {
      'bank': {...?state.driver?.bank.toMap(), 'pixKey': pix},
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saque solicitado! A loja fará o pagamento via PIX.')));
    }
  }
}

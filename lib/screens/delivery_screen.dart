import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/orders_repo.dart';
import '../state/driver_state.dart';
import '../theme.dart';
import 'chat_screen.dart';

/// Fluxo da entrega: navegar à loja → cheguei → coletei → navegar ao cliente
/// → finalizar com comprovante (PIN + recebedor). Inclui reporte de problemas
/// e devolução da corrida ao pool.
class DeliveryScreen extends StatelessWidget {
  final String supermarketId;
  final String orderId;
  const DeliveryScreen(
      {super.key, required this.supermarketId, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Order?>(
      stream: OrdersRepo.order(supermarketId, orderId),
      builder: (context, snap) {
        final order = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text('Corrida #${orderId.substring(0, 6)}'),
            actions: [
              if (order != null && !order.isFinished)
                IconButton(
                  tooltip: 'Chat',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatScreen(
                          supermarketId: supermarketId, orderId: orderId))),
                ),
            ],
          ),
          body: order == null
              ? const Center(child: CircularProgressIndicator())
              : _DeliveryBody(order: order),
        );
      },
    );
  }
}

class _DeliveryBody extends StatefulWidget {
  final Order order;
  const _DeliveryBody({required this.order});

  @override
  State<_DeliveryBody> createState() => _DeliveryBodyState();
}

class _DeliveryBodyState extends State<_DeliveryBody> {
  bool _busy = false;

  Order get order => widget.order;

  Future<void> _do(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _navigate(GeoPointLite? dest, String fallbackQuery) {
    final navApp =
        context.read<DriverState>().driver?.preferences.navApp ?? 'google';
    Uri uri;
    if (dest != null) {
      uri = navApp == 'waze'
          ? Uri.parse('https://waze.com/ul?ll=${dest.lat},${dest.lng}&navigate=yes')
          : Uri.parse(
              'https://www.google.com/maps/dir/?api=1&destination=${dest.lat},${dest.lng}');
    } else {
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(fallbackQuery)}');
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final status = order.deliveryStatus ?? 'assigned';
    final earnings = order.driverEarnings > 0
        ? order.driverEarnings
        : OrdersRepo.estimateEarnings(order);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusStepper(status: status),
        const SizedBox(height: 16),

        // Coleta
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Coleta',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(order.storeName,
                    style: const TextStyle(fontSize: 16)),
                if ((order.storeAddress ?? '').isNotEmpty)
                  Text(order.storeAddress!,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Entrega
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Entrega',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(order.customerName.isEmpty ? 'Cliente' : order.customerName,
                    style: const TextStyle(fontSize: 16)),
                Text(order.addressLine,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                if (order.reference.isNotEmpty)
                  Text('Ref.: ${order.reference}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                if (order.customerPhone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                      icon: const Icon(Icons.phone, size: 18),
                      label: Text('Ligar para ${order.customerName.split(' ').first}'),
                      onPressed: () => launchUrl(
                          Uri.parse('tel:${order.customerPhone}')),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Itens + ganho
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${order.items.fold(0, (a, i) => a + i.quantity)} itens · '
                    'ganho ${money(earnings + order.tip)}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                for (final item in order.items)
                  Text('• ${item.quantity}x ${item.name}',
                      style: const TextStyle(fontSize: 13.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (order.deliveryStatus == 'problem')
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Text(
                'Problema reportado: '
                '${_problemLabel(order.problemReport?['type'] as String?)}. '
                'A loja foi notificada.',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),

        ..._actions(status),

        if (!order.isFinished) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Reportar problema'),
            onPressed: _busy ? null : _reportProblem,
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    await _do(() => OrdersRepo.releaseOrder(order));
                    if (mounted) nav.pop();
                  },
            child: const Text('Devolver corrida ao pool'),
          ),
        ],
        if (order.isFinished)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: kGreen.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: kGreenDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      order.status == 'cancelled'
                          ? 'Pedido cancelado.'
                          : 'Entrega concluída! ${money(earnings + order.tip)} '
                              'creditados na sua carteira.',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _actions(String status) {
    switch (status) {
      case 'assigned':
      case 'going_to_store':
        return [
          OutlinedButton.icon(
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Navegar até a loja'),
            onPressed: () =>
                _navigate(order.storeLocation, order.storeAddress ?? order.storeName),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : () => _do(() => OrdersRepo.arrivedAtStore(order)),
            child: const Text('Cheguei na loja'),
          ),
        ];
      case 'arrived_store':
        return [
          FilledButton(
            onPressed: _busy ? null : () => _do(() => OrdersRepo.confirmPickup(order)),
            child: const Text('Coletei o pedido'),
          ),
        ];
      case 'picked_up':
      case 'going_to_customer':
      case 'problem':
        return [
          OutlinedButton.icon(
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Navegar até o cliente'),
            onPressed: () => _navigate(order.customerLocation, order.addressLine),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : _finishFlow,
            child: const Text('Finalizar entrega'),
          ),
        ];
      default:
        return [];
    }
  }

  /// Comprovante de entrega: PIN do cliente + nome de quem recebeu.
  Future<void> _finishFlow() async {
    final pinCtrl = TextEditingController();
    final receivedByCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
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
            const Text('Comprovante de entrega',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (order.deliveryPin != null) ...[
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                    labelText: 'PIN do cliente (4 dígitos)', counterText: ''),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: receivedByCtrl,
              decoration:
                  const InputDecoration(labelText: 'Quem recebeu? (nome)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                  labelText: 'Observação (opcional, ex.: deixado na portaria)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (order.deliveryPin != null &&
                    pinCtrl.text.trim() != order.deliveryPin) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content:
                          Text('PIN incorreto. Peça o PIN ao cliente.')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Confirmar entrega'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _do(() => OrdersRepo.completeDelivery(order,
          receivedBy: receivedByCtrl.text.trim(), note: noteCtrl.text.trim()));
    }
  }

  Future<void> _reportProblem() async {
    final noteCtrl = TextEditingController();
    String? selected;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Qual é o problema?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              for (final (value, label) in problemTypes)
                RadioListTile<String>(
                  value: value,
                  groupValue: selected,
                  onChanged: (v) => setSheet(() => selected = v),
                  title: Text(label),
                  contentPadding: EdgeInsets.zero,
                ),
              TextField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Detalhes (opcional)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: selected == null ? null : () => Navigator.pop(ctx, true),
                child: const Text('Enviar'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (ok == true && selected != null) {
      await _do(() =>
          OrdersRepo.reportProblem(order, selected!, note: noteCtrl.text.trim()));
    }
  }

  String _problemLabel(String? type) {
    for (final (value, label) in problemTypes) {
      if (value == type) return label;
    }
    return 'Outro';
  }
}

class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  static const _steps = [
    ('going_to_store', 'Indo à loja'),
    ('arrived_store', 'Na loja'),
    ('going_to_customer', 'Indo ao cliente'),
    ('delivered', 'Entregue'),
  ];

  @override
  Widget build(BuildContext context) {
    var current = _steps.indexWhere((s) => s.$1 == status);
    if (status == 'assigned') current = 0;
    if (status == 'picked_up' || status == 'problem') current = 2;
    if (current < 0) current = 0;
    final done = status == 'delivered';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      i < current || (i == current && done)
                          ? Icons.check_circle
                          : i == current
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                      color: i <= current ? kGreen : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 4),
                    Text(_steps[i].$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == current
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: i <= current
                                ? null
                                : Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

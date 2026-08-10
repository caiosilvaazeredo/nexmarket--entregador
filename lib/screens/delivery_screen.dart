import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/nav_apps.dart';
import '../services/orders_repo.dart';
import '../state/driver_state.dart';
import '../theme.dart';
import '../widgets/delivery_map.dart';
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

  @override
  void initState() {
    super.initState();
    // Fora de expediente o rastreamento fica desligado, então a posição pode
    // estar vazia ao abrir a corrida. Uma leitura avulsa já centraliza o mapa;
    // daí em diante quem atualiza é o stream que já está rodando.
    final location = context.read<DriverState>().location;
    if (location.position.value == null) location.current();
  }

  /// Perna atual da corrida: para onde o entregador tem de ir agora.
  ///
  /// Devolve `null` quando não há trajeto pendente — parado na loja ou já
  /// entregue —, e aí nem o mapa nem os botões de navegação aparecem, porque
  /// só ocupariam a tela sem responder nenhuma pergunta.
  _Leg? get _leg {
    if (order.isFinished) return null;
    switch (order.deliveryStatus ?? 'assigned') {
      case 'assigned':
      case 'going_to_store':
        return _Leg(
          point: order.storeLocation,
          address: (order.storeAddress ?? '').isNotEmpty
              ? order.storeAddress!
              : order.storeName,
          label: order.storeName,
          icon: Icons.storefront,
          action: 'Navegar até a loja',
        );
      case 'picked_up':
      case 'going_to_customer':
      case 'problem':
        return _Leg(
          point: order.customerLocation,
          address: order.addressLine,
          label: order.customerName.isEmpty ? 'Cliente' : order.customerName,
          icon: Icons.home_outlined,
          action: 'Navegar até o cliente',
        );
      default:
        return null;
    }
  }

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

  Future<void> _openNav(NavApp app, _Leg leg) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await openNavApp(
        app, NavDestination(point: leg.point, address: leg.address));
    if (!ok && mounted) {
      messenger.showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o ${app.label}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order.deliveryStatus ?? 'assigned';
    final earnings = order.driverEarnings > 0
        ? order.driverEarnings
        : OrdersRepo.estimateEarnings(order);

    final leg = _leg;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusStepper(status: status),
        const SizedBox(height: 16),

        // Mapa da perna atual + navegação externa.
        if (leg != null) ...[
          ValueListenableBuilder<GeoPointLite?>(
            valueListenable: context.read<DriverState>().location.position,
            builder: (_, origin, __) => DeliveryMap(
              origin: origin,
              destination: leg.point,
              destinationLabel: leg.label,
              destinationIcon: leg.icon,
            ),
          ),
          const SizedBox(height: 10),
          _NavButtons(leg: leg, onTap: _openNav),
          const SizedBox(height: 16),
        ],

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

/// Um trecho do trajeto: para onde ir agora e como chamá-lo na tela.
class _Leg {
  final GeoPointLite? point;
  final String address;
  final String label;
  final IconData icon;
  final String action;

  const _Leg({
    required this.point,
    required this.address,
    required this.label,
    required this.icon,
    required this.action,
  });
}

/// Waze e Google Maps lado a lado, como no app da Uber.
///
/// Os dois aparecem sempre. A escolha em Perfil deixou de ser uma trava e
/// virou só a ordem: o preferido fica à esquerda e destacado, mas trocar de
/// aplicativo é um toque — útil quando um deles está sem rota para o
/// endereço, o que acontece em condomínio e área rural.
class _NavButtons extends StatelessWidget {
  final _Leg leg;
  final Future<void> Function(NavApp app, _Leg leg) onTap;

  const _NavButtons({required this.leg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preferred = NavApp.fromPref(
        context.watch<DriverState>().driver?.preferences.navApp);
    final apps = [
      preferred,
      ...NavApp.values.where((a) => a != preferred),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(leg.action,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < apps.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: i == 0
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46)),
                        icon: const Icon(Icons.navigation, size: 18),
                        label: Text(apps[i].label),
                        onPressed: () => onTap(apps[i], leg),
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46)),
                        icon: const Icon(Icons.navigation_outlined, size: 18),
                        label: Text(apps[i].label),
                        onPressed: () => onTap(apps[i], leg),
                      ),
              ),
            ],
          ],
        ),
      ],
    );
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

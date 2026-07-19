import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/location_service.dart';
import '../services/orders_repo.dart';
import '../state/driver_state.dart';
import '../theme.dart';
import 'delivery_screen.dart';

/// Painel: botão Online/Offline, resumo de ganhos, corrida ativa e ofertas.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DriverState>();
    final driver = state.driver;
    final active = state.activeDelivery;

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${driver?.name.split(' ').first ?? 'entregador'} 👋'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OnlineToggle(
            online: state.isOnline,
            onChanged: (v) => state.setOnline(v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _EarningsTile(label: 'Hoje', value: state.earningsToday),
              const SizedBox(width: 10),
              _EarningsTile(label: 'Semana', value: state.earningsWeek),
              const SizedBox(width: 10),
              _EarningsTile(label: 'Mês', value: state.earningsMonth),
            ],
          ),
          const SizedBox(height: 16),
          if (active != null) _ActiveDeliveryCard(order: active),
          if (active == null && state.isOnline) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Ofertas disponíveis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            if (state.availableOrders.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.radar, size: 40, color: kGreen),
                      const SizedBox(height: 8),
                      const Text('Procurando corridas…',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('Você será avisado quando surgir uma oferta.',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            for (final order in state.availableOrders)
              _OfferCard(order: order),
          ],
          if (!state.isOnline && active == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.power_settings_new,
                        size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text('Você está offline',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('Fique online para receber ofertas de entrega.',
                        style:
                            TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  final bool online;
  final ValueChanged<bool> onChanged;
  const _OnlineToggle({required this.online, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: online ? kGreen : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onChanged(!online),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(online ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                  color: online ? Colors.white : Colors.grey.shade700, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(online ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                            color: online ? Colors.white : Colors.grey.shade700,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    Text(
                        online
                            ? 'Recebendo ofertas de corrida'
                            : 'Toque para ficar online',
                        style: TextStyle(
                            color: online
                                ? Colors.white.withValues(alpha: .9)
                                : Colors.grey.shade600,
                            fontSize: 13)),
                  ],
                ),
              ),
              Switch(
                value: online,
                activeTrackColor: Colors.white38,
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningsTile extends StatelessWidget {
  final String label;
  final double value;
  const _EarningsTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(money(value),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  final Order order;
  const _ActiveDeliveryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kGreen.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DeliveryScreen(
                supermarketId: order.supermarketId, orderId: order.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.delivery_dining, color: kGreenDark, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Corrida em andamento',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                        '${order.storeName} → ${order.customerName.isEmpty ? 'cliente' : order.customerName}'
                        ' · ${deliveryStatusLabels[order.deliveryStatus] ?? ''}',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kGreenDark),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oferta com timer de 30 s, distâncias, ganho estimado e itens.
class _OfferCard extends StatefulWidget {
  final Order order;
  const _OfferCard({required this.order});

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  static const _offerSeconds = 30;
  int _remaining = _offerSeconds;
  Timer? _timer;
  bool _accepting = false;
  double? _distToStore;
  double? _distStoreToCustomer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        context.read<DriverState>().declineOffer(widget.order.id);
      } else {
        setState(() => _remaining--);
      }
    });
    _computeDistances();
  }

  Future<void> _computeDistances() async {
    final store = widget.order.storeLocation;
    final cust = widget.order.customerLocation;
    if (store != null && cust != null) {
      _distStoreToCustomer =
          distanceMeters(store.lat, store.lng, cust.lat, cust.lng);
    }
    final pos = await context.read<DriverState>().location.current();
    if (pos != null && store != null) {
      _distToStore =
          distanceMeters(pos.latitude, pos.longitude, store.lat, store.lng);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    final state = context.read<DriverState>();
    final driver = state.driver;
    if (driver == null) return;
    setState(() => _accepting = true);
    try {
      await OrdersRepo.acceptOrder(widget.order, driver);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DeliveryScreen(
              supermarketId: widget.order.supermarketId,
              orderId: widget.order.id)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
        context.read<DriverState>().declineOffer(widget.order.id);
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final earnings = OrdersRepo.estimateEarnings(order,
        storeToCustomerMeters: _distStoreToCustomer);
    final itemCount = order.items.fold(0, (acc, i) => acc + i.quantity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Nova corrida — ${order.storeName}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _remaining <= 10 ? Colors.redAccent : kGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_remaining}s',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _remaining / _offerSeconds,
                backgroundColor: Colors.grey.shade200,
                color: _remaining <= 10 ? Colors.redAccent : kGreen,
              ),
              const SizedBox(height: 12),
              _line(Icons.store, 'Coleta',
                  '${order.storeName} · ${formatDistance(_distToStore)} de você'),
              _line(Icons.place_outlined, 'Entrega',
                  '${order.addressLine} · ${formatDistance(_distStoreToCustomer)}'),
              _line(Icons.inventory_2_outlined, 'Itens', '$itemCount itens'),
              _line(Icons.payments_outlined, 'Ganho',
                  money(earnings + order.tip) +
                      (order.tip > 0 ? ' (inclui ${money(order.tip)} de gorjeta)' : '')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(
                              color: Colors.redAccent, width: 2)),
                      onPressed: () =>
                          context.read<DriverState>().declineOffer(order.id),
                      child: const Text('Recusar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: _accepting ? null : _accept,
                      child: _accepting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Aceitar corrida'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kGreenDark),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w800)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/driver_state.dart';
import '../theme.dart';
import 'delivery_screen.dart';

/// Histórico de entregas (ativas + concluídas).
class DeliveriesScreen extends StatelessWidget {
  const DeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DriverState>();
    final active =
        state.myDeliveries.where((o) => o.isActiveDelivery).toList();
    final finished =
        state.myDeliveries.where((o) => !o.isActiveDelivery).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Entregas')),
      body: state.myDeliveries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delivery_dining_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('Nenhuma entrega ainda',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  Text('Fique online para receber corridas.',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  const Text('Em andamento',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  for (final o in active) _DeliveryTile(order: o),
                  const SizedBox(height: 16),
                ],
                if (finished.isNotEmpty) ...[
                  const Text('Concluídas',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  for (final o in finished) _DeliveryTile(order: o),
                ],
              ],
            ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  final Order order;
  const _DeliveryTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final when = tsMillis(order.deliveredAt) > 0
        ? tsMillis(order.deliveredAt)
        : tsMillis(order.acceptedAt);
    final date = when > 0
        ? DateFormat("d 'de' MMM, HH:mm", 'pt_BR')
            .format(DateTime.fromMillisecondsSinceEpoch(when))
        : '';
    final cancelled = order.status == 'cancelled';
    final label = cancelled
        ? 'Cancelada'
        : deliveryStatusLabels[order.deliveryStatus] ?? order.deliveryStatus ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: cancelled
                ? Colors.red.shade50
                : kGreen.withValues(alpha: .12),
            child: Icon(
                cancelled ? Icons.close : Icons.delivery_dining,
                color: cancelled ? Colors.redAccent : kGreenDark),
          ),
          title: Text(order.storeName,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('$date\n$label',
              style: const TextStyle(fontSize: 12.5)),
          isThreeLine: true,
          trailing: Text(
              money(order.driverEarnings + order.tip),
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DeliveryScreen(
                  supermarketId: order.supermarketId, orderId: order.id))),
        ),
      ),
    );
  }
}

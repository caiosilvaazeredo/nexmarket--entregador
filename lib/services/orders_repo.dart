import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart' as models;
import 'drivers_repo.dart';
import 'fire.dart';

/// Pedidos no banco compartilhado com a loja e o cliente. O ciclo da loja é
/// `pending → picking → ready → delivered`; este app comanda o sub-status
/// `deliveryStatus` a partir de `ready`.
class OrdersRepo {
  static final _storeCache =
      <String, ({String name, models.GeoPointLite? location, String? address})>{};

  static Future<({String name, models.GeoPointLite? location, String? address})>
      storeInfo(String smId) async {
    final cached = _storeCache[smId];
    if (cached != null) return cached;
    var info = (name: 'Loja', location: null as models.GeoPointLite?, address: null as String?);
    try {
      final sm = await Fire.db.doc('supermarkets/$smId').get();
      String name = 'Loja';
      if (sm.exists) name = (sm.data()!['name'] as String?) ?? 'Loja';
      final settings = await Fire.db.doc('supermarkets/$smId/settings/storeInfo').get();
      models.GeoPointLite? location;
      String? address;
      if (settings.exists) {
        final s = settings.data()!;
        final loc = (s['storeLocation'] as Map?) ?? s;
        address = (loc['address'] as String?) ?? (s['address'] as String?);
        location = models.GeoPointLite.from(loc);
      }
      info = (name: name, location: location, address: address);
    } catch (_) {}
    _storeCache[smId] = info;
    return info;
  }

  static Future<models.Order> _enrich(String id, Map<String, dynamic> data) async {
    final smId = (data['supermarketId'] as String?) ?? '';
    final info = await storeInfo(smId);
    return models.Order.fromMap(id, data,
        storeName: info.name, storeLocation: info.location, storeAddress: info.address);
  }

  /// Pedidos prontos aguardando qualquer entregador Nexmarket.
  static Stream<List<models.Order>> availableOrders() {
    return Fire.db
        .collectionGroup('orders')
        .where('status', isEqualTo: 'ready')
        .where('deliveryStatus', isEqualTo: 'awaiting_driver')
        .snapshots()
        .asyncMap((snap) async {
      final orders = <models.Order>[];
      for (final d in snap.docs) {
        final data = d.data();
        if ((data['driverId'] as String?)?.isNotEmpty == true) continue;
        orders.add(await _enrich(d.id, data));
      }
      return orders;
    });
  }

  /// Todas as entregas deste entregador (ativas + histórico).
  static Stream<List<models.Order>> myDeliveries(String uid) {
    return Fire.db
        .collectionGroup('orders')
        .where('driverId', isEqualTo: uid)
        .snapshots()
        .asyncMap((snap) async {
      final orders = <models.Order>[];
      for (final d in snap.docs) {
        orders.add(await _enrich(d.id, d.data()));
      }
      orders.sort((a, b) =>
          models.tsMillis(b.acceptedAt).compareTo(models.tsMillis(a.acceptedAt)));
      return orders;
    });
  }

  static Stream<models.Order?> order(String smId, String orderId) {
    return Fire.db
        .doc('supermarkets/$smId/orders/$orderId')
        .snapshots()
        .asyncMap((d) async => d.exists ? await _enrich(d.id, d.data()!) : null);
  }

  /* ----------------------------- Ganhos ----------------------------- */

  static const _baseFee = 5.0;
  static const _perKm = 1.5;

  static double estimateEarnings(models.Order order, {double? storeToCustomerMeters}) {
    if (order.deliveryFee > 0) return order.deliveryFee;
    final km = storeToCustomerMeters != null ? storeToCustomerMeters / 1000 : 2.0;
    final v = _baseFee + km * _perKm;
    final rounded = double.parse(v.toStringAsFixed(2));
    return rounded < _baseFee ? _baseFee : rounded;
  }

  /* ----------------------------- Mutações ----------------------------- */

  static DocumentReference<Map<String, dynamic>> _ref(models.Order o) =>
      Fire.db.doc('supermarkets/${o.supermarketId}/orders/${o.id}');

  /// Aceita um pedido atomicamente — a transação garante que dois entregadores
  /// nunca peguem a mesma corrida (anti-corrida).
  static Future<void> acceptOrder(models.Order order, models.DriverProfile driver) async {
    final ref = _ref(order);
    await Fire.db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Pedido não existe mais.');
      final data = snap.data()!;
      if ((data['driverId'] as String?)?.isNotEmpty == true) {
        throw Exception('Outro entregador já aceitou este pedido.');
      }
      if (data['deliveryStatus'] != 'awaiting_driver') {
        throw Exception('Este pedido não está mais disponível.');
      }
      tx.update(ref, {
        'driverId': driver.uid,
        'driverName': driver.name,
        'deliveryStatus': 'going_to_store',
        'driverEarnings': estimateEarnings(order),
        'acceptedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> _update(models.Order order, Map<String, dynamic> data) async {
    await _ref(order).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> arrivedAtStore(models.Order order) =>
      _update(order, {'deliveryStatus': 'arrived_store'});

  static Future<void> confirmPickup(models.Order order) => _update(order, {
        'deliveryStatus': 'going_to_customer',
        'pickedUpAt': DateTime.now().millisecondsSinceEpoch,
      });

  /// Problemas: address_not_found | customer_absent | damaged_package | other
  static Future<void> reportProblem(models.Order order, String type,
          {String note = ''}) =>
      _update(order, {
        'deliveryStatus': 'problem',
        'problemReport': {
          'type': type,
          'note': note,
          'reportedAt': DateTime.now().millisecondsSinceEpoch,
        },
      });

  /// Devolve a corrida para o pool (antes de entregar).
  static Future<void> releaseOrder(models.Order order) => _update(order, {
        'driverId': '',
        'driverName': '',
        'deliveryStatus': 'awaiting_driver',
        'problemReport': null,
      });

  /// Finaliza a entrega com comprovante (POD) e credita a carteira.
  static Future<void> completeDelivery(
    models.Order order, {
    String receivedBy = '',
    String note = '',
  }) async {
    final earnings =
        order.driverEarnings > 0 ? order.driverEarnings : estimateEarnings(order);
    await _update(order, {
      'status': 'delivered',
      'deliveryStatus': 'delivered',
      'deliveredAt': DateTime.now().millisecondsSinceEpoch,
      'proofOfDelivery': {
        'signatureUrl': '',
        'photoUrl': '',
        'note': note,
        'receivedBy': receivedBy,
      },
      'driverEarnings': earnings,
    });
    final driverId = order.driverId;
    if (driverId != null) {
      try {
        await DriversRepo.addEarnings(driverId, earnings + order.tip);
      } catch (_) {
        // Melhor esforço: o crédito pode ser repetido com segurança depois.
      }
    }
  }
}

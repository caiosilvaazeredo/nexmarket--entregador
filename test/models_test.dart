import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket_entregador/models.dart';
import 'package:nexmarket_entregador/services/orders_repo.dart';

Order mkOrder({
  String status = 'ready',
  String? deliveryStatus = 'awaiting_driver',
  double deliveryFee = 0,
  String? driverId,
}) =>
    Order.fromMap('o1', {
      'supermarketId': 'sm1',
      'customerId': 'c1',
      'status': status,
      if (deliveryStatus != null) 'deliveryStatus': deliveryStatus,
      'deliveryFee': deliveryFee,
      if (driverId != null) 'driverId': driverId,
      'total': 50,
      'items': const [],
    });

void main() {
  group('Order (ciclo do entregador)', () {
    test('sub-status ativos e finalizados', () {
      expect(mkOrder(deliveryStatus: 'going_to_store').isActiveDelivery, isTrue);
      expect(mkOrder(deliveryStatus: 'problem').isActiveDelivery, isTrue);
      expect(mkOrder(deliveryStatus: 'awaiting_driver').isActiveDelivery, isFalse);
      expect(mkOrder(deliveryStatus: 'delivered').isFinished, isTrue);
      expect(mkOrder(status: 'cancelled').isFinished, isTrue);
    });

    test('driverId vazio (corrida devolvida) vira null', () {
      final o = Order.fromMap('o', {
        'supermarketId': 'sm1',
        'customerId': 'c1',
        'status': 'ready',
        'driverId': '',
        'total': 1,
        'items': const [],
      });
      expect(o.driverId, isNull);
    });

    test('endereço formatado e referência', () {
      final o = Order.fromMap('o', {
        'supermarketId': 'sm1',
        'customerId': 'c1',
        'status': 'ready',
        'total': 1,
        'items': const [],
        'deliveryAddress': {
          'street': 'Rua A',
          'number': '10',
          'neighborhood': 'Centro',
          'city': 'Rio',
          'reference': 'Portão azul',
          'lat': -22.9,
          'lng': -43.2,
        },
      });
      expect(o.addressLine, 'Rua A, 10 — Centro — Rio');
      expect(o.reference, 'Portão azul');
      expect(o.customerLocation!.lat, -22.9);
    });
  });

  group('Ganhos (estimateEarnings)', () {
    test('usa o deliveryFee do pedido quando existe', () {
      expect(OrdersRepo.estimateEarnings(mkOrder(deliveryFee: 9.9)), 9.9);
    });

    test('sem fee: base + por km, nunca abaixo da base', () {
      // 4 km => 5 + 4*1.5 = 11
      expect(
          OrdersRepo.estimateEarnings(mkOrder(), storeToCustomerMeters: 4000), 11);
      // 0 km => trava na base (5)
      expect(OrdersRepo.estimateEarnings(mkOrder(), storeToCustomerMeters: 0), 5);
    });
  });

  group('DriverProfile', () {
    test('parse completo + defaults', () {
      final d = DriverProfile.fromMap('u1', {
        'name': 'João',
        'status': 'online',
        'vehicle': {'type': 'moto', 'model': 'CG 160', 'plate': 'ABC1D23'},
        'documents': {'status': 'approved'},
        'preferences': {'navApp': 'waze', 'darkMode': true},
        'balance': 12.5,
        'totalDeliveries': 7,
      });
      expect(d.isOnline, isTrue);
      expect(d.vehicle.label, 'CG 160 · ABC1D23');
      expect(d.documentsStatus, 'approved');
      expect(d.preferences.navApp, 'waze');
      expect(d.balance, 12.5);

      final empty = DriverProfile.fromMap('u2', {});
      expect(empty.isOnline, isFalse);
      expect(empty.rating, 5);
      expect(empty.preferences.soundAlerts, isTrue);
    });
  });
}

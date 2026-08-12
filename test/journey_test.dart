import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket_entregador/models.dart';
import 'package:nexmarket_entregador/services/drivers_repo.dart';
import 'package:nexmarket_entregador/services/fire.dart';
import 'package:nexmarket_entregador/services/orders_repo.dart';

/// Jornada do entregador no banco COMPARTILHADO: o pedido é semeado com o
/// payload exato que o app do cliente escreve no checkout, e as transições
/// são verificadas contra o contrato que a loja e o cliente consomem.
void main() {
  late FakeFirebaseFirestore db;

  /// Payload idêntico ao checkout do app do cliente (nexmarket--cliente).
  Map<String, dynamic> customerOrderPayload() => {
        'supermarketId': 'sm1',
        'customerId': 'cliente1',
        'status': 'ready', // loja já separou
        'items': [
          {'productId': 'p1', 'name': 'Arroz 5kg', 'quantity': 2, 'price': 20},
        ],
        'subtotal': 40,
        'deliveryFee': 8,
        'discount': 0,
        'total': 48,
        'fulfillment': 'delivery',
        'paymentMethod': 'pix',
        'paymentStatus': 'paid',
        'customerName': 'Cliente Teste',
        'customerPhone': '21999999999',
        'deliveryStatus': 'awaiting_driver',
        'deliveryAddress': {
          'street': 'Rua do Cliente',
          'number': '42',
          'lat': -22.91,
          'lng': -43.21,
        },
        'tip': 3,
        'deliveryPin': '1234',
      };

  DriverProfile driver([String uid = 'driver1', String name = 'João Motoboy']) =>
      DriverProfile(uid: uid, name: name);

  setUp(() async {
    db = FakeFirebaseFirestore();
    Fire.overrideForTests(db, uid: 'driver1');
    await db.doc('supermarkets/sm1').set({'name': 'Mercado Teste'});
    await db.doc('supermarkets/sm1/settings/storeInfo').set({
      'storeLocation': {'address': 'Rua da Loja, 1', 'lat': -22.9, 'lng': -43.2},
    });
    await db.doc('supermarkets/sm1/orders/ord1').set(customerOrderPayload());
  });

  test('pedido pronto aparece no pool de ofertas com dados da loja', () async {
    final offers = await OrdersRepo.availableOrders().first;
    expect(offers.length, 1);
    final o = offers.first;
    expect(o.storeName, 'Mercado Teste');
    expect(o.storeLocation!.lat, -22.9);
    expect(o.deliveryPin, '1234');
    expect(o.tip, 3);
  });

  test('aceite é transacional: o segundo entregador é bloqueado (anti-corrida)',
      () async {
    final offer = (await OrdersRepo.availableOrders().first).first;

    await OrdersRepo.acceptOrder(offer, driver());
    final d = (await db.doc('supermarkets/sm1/orders/ord1').get()).data()!;
    expect(d['driverId'], 'driver1');
    expect(d['driverName'], 'João Motoboy');
    expect(d['deliveryStatus'], 'going_to_store');
    expect(d['driverEarnings'], 8); // usa o deliveryFee do pedido

    // Outro entregador tenta aceitar a mesma corrida.
    await expectLater(
      OrdersRepo.acceptOrder(offer, driver('driver2', 'Maria')),
      throwsA(isA<Exception>()),
    );
    final after = (await db.doc('supermarkets/sm1/orders/ord1').get()).data()!;
    expect(after['driverId'], 'driver1'); // segue com o primeiro

    // E a corrida some do pool.
    final offers = await OrdersRepo.availableOrders().first;
    expect(offers, isEmpty);
  });

  test('ciclo completo: loja → cliente → POD, crédito na carteira (com gorjeta)',
      () async {
    await DriversRepo.createProfile('driver1',
        name: 'João Motoboy', email: 'joao@x.com');
    final offer = (await OrdersRepo.availableOrders().first).first;
    await OrdersRepo.acceptOrder(offer, driver());

    var order = (await OrdersRepo.order('sm1', 'ord1').first)!;
    await OrdersRepo.arrivedAtStore(order);
    order = (await OrdersRepo.order('sm1', 'ord1').first)!;
    expect(order.deliveryStatus, 'arrived_store');

    await OrdersRepo.confirmPickup(order);
    order = (await OrdersRepo.order('sm1', 'ord1').first)!;
    expect(order.deliveryStatus, 'going_to_customer');

    await OrdersRepo.completeDelivery(order,
        receivedBy: 'Cliente Teste', note: 'Entregue em mãos');

    // Contrato com a loja e o app do cliente: status final duplo.
    final d = (await db.doc('supermarkets/sm1/orders/ord1').get()).data()!;
    expect(d['status'], 'delivered');
    expect(d['deliveryStatus'], 'delivered');
    final pod = d['proofOfDelivery'] as Map;
    expect(pod['receivedBy'], 'Cliente Teste');
    expect(pod['note'], 'Entregue em mãos');

    // Carteira creditada: fee (8) + gorjeta (3), 1 entrega no contador.
    final profile = await DriversRepo.get('driver1');
    expect(profile!.balance, closeTo(11, 0.001));
    expect(profile.totalDeliveries, 1);

    // Histórico do entregador contém a corrida.
    final mine = await OrdersRepo.myDeliveries('driver1').first;
    expect(mine.length, 1);
    expect(mine.first.isFinished, isTrue);
  });

  test('problema reportado e devolução ao pool', () async {
    final offer = (await OrdersRepo.availableOrders().first).first;
    await OrdersRepo.acceptOrder(offer, driver());
    var order = (await OrdersRepo.order('sm1', 'ord1').first)!;

    await OrdersRepo.reportProblem(order, 'customer_absent', note: 'Não atende');
    order = (await OrdersRepo.order('sm1', 'ord1').first)!;
    expect(order.deliveryStatus, 'problem');
    expect(order.problemReport!['type'], 'customer_absent');
    expect(order.isActiveDelivery, isTrue); // problema ainda é corrida ativa

    await OrdersRepo.releaseOrder(order);
    final d = (await db.doc('supermarkets/sm1/orders/ord1').get()).data()!;
    expect(d['deliveryStatus'], 'awaiting_driver');
    expect(d['driverId'], '');
    expect(d['problemReport'], isNull);

    // Volta ao pool para outro entregador.
    final offers = await OrdersRepo.availableOrders().first;
    expect(offers.length, 1);
  });

  test('carteira: saque via PIX debita o saldo e registra o payout', () async {
    await DriversRepo.createProfile('driver1',
        name: 'João Motoboy', email: 'joao@x.com');
    await DriversRepo.addEarnings('driver1', 50);

    await DriversRepo.requestPayout('driver1', amount: 30, pixKey: 'joao@pix');

    final profile = await DriversRepo.get('driver1');
    expect(profile!.balance, closeTo(20, 0.001));

    final payouts = await DriversRepo.payouts('driver1').first;
    expect(payouts.length, 1);
    expect(payouts.first.amount, 30);
    expect(payouts.first.status, 'requested');
    expect(payouts.first.destination, 'joao@pix');
  });

  test('online/offline e localização publicadas para o rastreio do cliente',
      () async {
    await DriversRepo.createProfile('driver1',
        name: 'João Motoboy', email: 'joao@x.com');
    await DriversRepo.setOnline('driver1', true);
    await DriversRepo.updateLocation('driver1', -22.95, -43.25);

    // Exatamente o doc que o app do cliente assina em /drivers/{uid} (RF21).
    final d = (await db.doc('drivers/driver1').get()).data()!;
    expect(d['status'], 'online');
    expect((d['location'] as Map)['lat'], -22.95);

    await DriversRepo.setOnline('driver1', false);
    expect((await db.doc('drivers/driver1').get()).data()!['status'], 'offline');
  });
}

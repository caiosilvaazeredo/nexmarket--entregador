/// Modelo de dados compartilhado. Espelha o schema Firestore usado pela loja
/// e pelo app do cliente — os três apps leem/escrevem o MESMO banco.
///
/// Coleções:
///   /drivers/{uid}                              -> DriverProfile (este app)
///   /drivers/{uid}/payouts/{id}                 -> Payout
///   /supermarkets/{smId}                        -> loja (leitura)
///   /supermarkets/{smId}/settings/storeInfo     -> endereço/geo da loja (leitura)
///   /supermarkets/{smId}/orders/{orderId}       -> pedidos (+ campos de entrega)
///   /supermarkets/{smId}/orders/{id}/messages   -> chat do pedido
library;

double _d(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

int _int(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String _s(dynamic v, [String fallback = '']) => v is String ? v : fallback;

/// Converte Timestamp/num/ISO em millis (0 quando ausente).
int tsMillis(dynamic ts) {
  if (ts == null) return 0;
  if (ts is num) return ts.toInt();
  try {
    final ms = (ts as dynamic).millisecondsSinceEpoch;
    if (ms is int) return ms;
  } catch (_) {}
  if (ts is String) return DateTime.tryParse(ts)?.millisecondsSinceEpoch ?? 0;
  return 0;
}

class GeoPointLite {
  final double lat;
  final double lng;
  GeoPointLite(this.lat, this.lng);

  static GeoPointLite? from(dynamic m) {
    if (m is! Map) return null;
    final lat = m['lat'], lng = m['lng'];
    if (lat is num && lng is num) return GeoPointLite(lat.toDouble(), lng.toDouble());
    return null;
  }
}

/* --------------------------- Entregador --------------------------- */

class Vehicle {
  final String type; // moto | carro | bike | van
  final String plate;
  final String model;
  final String color;

  Vehicle({this.type = 'moto', this.plate = '', this.model = '', this.color = ''});

  factory Vehicle.fromMap(Map<String, dynamic> m) => Vehicle(
        type: _s(m['type'], 'moto'),
        plate: _s(m['plate']),
        model: _s(m['model']),
        color: _s(m['color']),
      );

  Map<String, dynamic> toMap() =>
      {'type': type, 'plate': plate, 'model': model, 'color': color};

  String get label => [model, plate].where((s) => s.isNotEmpty).join(' · ');
}

class BankInfo {
  final String holderName;
  final String cpf;
  final String bankName;
  final String agency;
  final String account;
  final String pixKey;

  BankInfo({
    this.holderName = '',
    this.cpf = '',
    this.bankName = '',
    this.agency = '',
    this.account = '',
    this.pixKey = '',
  });

  factory BankInfo.fromMap(Map<String, dynamic> m) => BankInfo(
        holderName: _s(m['holderName']),
        cpf: _s(m['cpf']),
        bankName: _s(m['bankName']),
        agency: _s(m['agency']),
        account: _s(m['account']),
        pixKey: _s(m['pixKey']),
      );

  Map<String, dynamic> toMap() => {
        'holderName': holderName,
        'cpf': cpf,
        'bankName': bankName,
        'agency': agency,
        'account': account,
        'pixKey': pixKey,
      };
}

class DriverPreferences {
  final bool soundAlerts;
  final bool darkMode;
  final String navApp; // google | waze

  DriverPreferences({this.soundAlerts = true, this.darkMode = false, this.navApp = 'google'});

  factory DriverPreferences.fromMap(Map<String, dynamic> m) => DriverPreferences(
        soundAlerts: m['soundAlerts'] != false,
        darkMode: m['darkMode'] == true,
        navApp: _s(m['navApp'], 'google'),
      );

  Map<String, dynamic> toMap() =>
      {'soundAlerts': soundAlerts, 'darkMode': darkMode, 'navApp': navApp};

  DriverPreferences copyWith({bool? soundAlerts, bool? darkMode, String? navApp}) =>
      DriverPreferences(
        soundAlerts: soundAlerts ?? this.soundAlerts,
        darkMode: darkMode ?? this.darkMode,
        navApp: navApp ?? this.navApp,
      );
}

class DriverProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String status; // online | offline | on_delivery
  final Vehicle vehicle;
  final String documentsStatus; // pending | approved | rejected
  final BankInfo bank;
  final DriverPreferences preferences;
  final GeoPointLite? location;
  final double rating;
  final int totalDeliveries;
  final double balance;

  DriverProfile({
    required this.uid,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.status = 'offline',
    Vehicle? vehicle,
    this.documentsStatus = 'pending',
    BankInfo? bank,
    DriverPreferences? preferences,
    this.location,
    this.rating = 5,
    this.totalDeliveries = 0,
    this.balance = 0,
  })  : vehicle = vehicle ?? Vehicle(),
        bank = bank ?? BankInfo(),
        preferences = preferences ?? DriverPreferences();

  factory DriverProfile.fromMap(String uid, Map<String, dynamic> m) => DriverProfile(
        uid: uid,
        name: _s(m['name']),
        email: _s(m['email']),
        phone: _s(m['phone']),
        status: _s(m['status'], 'offline'),
        vehicle: m['vehicle'] is Map
            ? Vehicle.fromMap(Map<String, dynamic>.from(m['vehicle'] as Map))
            : Vehicle(),
        documentsStatus: m['documents'] is Map
            ? _s((m['documents'] as Map)['status'], 'pending')
            : 'pending',
        bank: m['bank'] is Map
            ? BankInfo.fromMap(Map<String, dynamic>.from(m['bank'] as Map))
            : BankInfo(),
        preferences: m['preferences'] is Map
            ? DriverPreferences.fromMap(
                Map<String, dynamic>.from(m['preferences'] as Map))
            : DriverPreferences(),
        location: GeoPointLite.from(m['location']),
        rating: _d(m['rating'], 5),
        totalDeliveries: _int(m['totalDeliveries']),
        balance: _d(m['balance']),
      );

  bool get isOnline => status == 'online' || status == 'on_delivery';
}

/* --------------------------- Pedidos --------------------------- */

class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productId: _s(m['productId']),
        name: _s(m['name']),
        quantity: _int(m['quantity'], 1),
        price: _d(m['price']),
      );
}

/// Sub-status granular da entrega (deste app):
/// awaiting_driver → going_to_store → arrived_store → going_to_customer → delivered
class Order {
  final String id;
  final String supermarketId;
  final String customerId;
  final String status; // ciclo da loja: pending → picking → ready → delivered
  final List<OrderItem> items;
  final double total;
  final String? deliveryStatus;
  final Map<String, dynamic> deliveryAddress;
  final String customerName;
  final String customerPhone;
  final double deliveryFee;
  final double tip;
  final String? deliveryPin;
  final String? driverId;
  final String? driverName;
  final double driverEarnings;
  final dynamic acceptedAt;
  final dynamic deliveredAt;
  final Map<String, dynamic>? problemReport;
  final dynamic createdAt;
  // Enriquecidos no app:
  final String storeName;
  final GeoPointLite? storeLocation;
  final String? storeAddress;

  Order({
    required this.id,
    required this.supermarketId,
    required this.customerId,
    required this.status,
    required this.items,
    required this.total,
    this.deliveryStatus,
    this.deliveryAddress = const {},
    this.customerName = '',
    this.customerPhone = '',
    this.deliveryFee = 0,
    this.tip = 0,
    this.deliveryPin,
    this.driverId,
    this.driverName,
    this.driverEarnings = 0,
    this.acceptedAt,
    this.deliveredAt,
    this.problemReport,
    this.createdAt,
    this.storeName = 'Loja',
    this.storeLocation,
    this.storeAddress,
  });

  factory Order.fromMap(String id, Map<String, dynamic> m,
      {String storeName = 'Loja', GeoPointLite? storeLocation, String? storeAddress}) {
    return Order(
      id: id,
      supermarketId: _s(m['supermarketId']),
      customerId: _s(m['customerId']),
      status: _s(m['status'], 'pending'),
      items: (m['items'] as List?)
              ?.whereType<Map>()
              .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      total: _d(m['total']),
      deliveryStatus: m['deliveryStatus'] as String?,
      deliveryAddress: (m['deliveryAddress'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v)) ??
          const {},
      customerName: _s(m['customerName']),
      customerPhone: _s(m['customerPhone']),
      deliveryFee: _d(m['deliveryFee']),
      tip: _d(m['tip']),
      deliveryPin: m['deliveryPin'] as String?,
      driverId: (m['driverId'] as String?)?.isEmpty == true ? null : m['driverId'] as String?,
      driverName: m['driverName'] as String?,
      driverEarnings: _d(m['driverEarnings']),
      acceptedAt: m['acceptedAt'],
      deliveredAt: m['deliveredAt'],
      problemReport: (m['problemReport'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v)),
      createdAt: m['createdAt'],
      storeName: storeName,
      storeLocation: storeLocation,
      storeAddress: storeAddress,
    );
  }

  static const activeDeliveryStatuses = [
    'assigned',
    'going_to_store',
    'arrived_store',
    'picked_up',
    'going_to_customer',
    'problem',
  ];

  bool get isActiveDelivery =>
      deliveryStatus != null && activeDeliveryStatuses.contains(deliveryStatus);

  bool get isFinished =>
      deliveryStatus == 'delivered' || status == 'delivered' || status == 'cancelled';

  GeoPointLite? get customerLocation => GeoPointLite.from(deliveryAddress);

  String get addressLine {
    final a = deliveryAddress;
    final parts = <String>[
      if ((a['street'] ?? '') != '') '${a['street']}, ${a['number'] ?? ''}',
      if ((a['complement'] ?? '') != '') '${a['complement']}',
      if ((a['neighborhood'] ?? '') != '') '${a['neighborhood']}',
      if ((a['city'] ?? '') != '') '${a['city']}',
    ];
    return parts.isEmpty ? 'Endereço não informado' : parts.join(' — ');
  }

  String get reference => _s(deliveryAddress['reference']);
}

/* --------------------------- Carteira --------------------------- */

class Payout {
  final String id;
  final double amount;
  final String status; // requested | processing | paid | rejected
  final String method;
  final String destination;
  final dynamic createdAt;

  Payout({
    required this.id,
    required this.amount,
    required this.status,
    this.method = 'pix',
    this.destination = '',
    this.createdAt,
  });

  factory Payout.fromMap(String id, Map<String, dynamic> m) => Payout(
        id: id,
        amount: _d(m['amount']),
        status: _s(m['status'], 'requested'),
        method: _s(m['method'], 'pix'),
        destination: _s(m['destination']),
        createdAt: m['createdAt'],
      );
}

/* --------------------------- Chat --------------------------- */

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderRole; // driver | customer | store | support
  final dynamic createdAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderRole,
    this.createdAt,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) => ChatMessage(
        id: id,
        text: _s(m['text']),
        senderId: _s(m['senderId']),
        senderRole: _s(m['senderRole']),
        createdAt: m['createdAt'],
      );
}

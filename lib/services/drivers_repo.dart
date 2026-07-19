import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';
import 'fire.dart';

/// Perfil do entregador em /drivers/{uid}.
class DriversRepo {
  static DocumentReference<Map<String, dynamic>> ref(String uid) =>
      Fire.db.doc('drivers/$uid');

  static Stream<DriverProfile?> profile(String uid) {
    return ref(uid).snapshots().map(
        (d) => d.exists ? DriverProfile.fromMap(uid, d.data()!) : null);
  }

  static Future<DriverProfile?> get(String uid) async {
    final d = await ref(uid).get();
    return d.exists ? DriverProfile.fromMap(uid, d.data()!) : null;
  }

  /// Cria o perfil no cadastro/onboarding (documentos ficam `pending` até a
  /// aprovação no painel da loja).
  static Future<void> createProfile(
    String uid, {
    required String name,
    required String email,
    String phone = '',
    Vehicle? vehicle,
  }) async {
    await ref(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': '',
      'status': 'offline',
      'vehicle': (vehicle ?? Vehicle()).toMap(),
      'documents': {'status': 'pending'},
      'bank': BankInfo().toMap(),
      'preferences': DriverPreferences().toMap(),
      'location': null,
      'rating': 5,
      'totalDeliveries': 0,
      'balance': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> update(String uid, Map<String, dynamic> partial) async {
    await ref(uid).update({
      ...partial,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setOnline(String uid, bool online) =>
      update(uid, {'status': online ? 'online' : 'offline'});

  /// Rastreamento: só é chamado enquanto Online/em corrida (bateria +
  /// privacidade — RNF).
  static Future<void> updateLocation(String uid, double lat, double lng) =>
      update(uid, {
        'location': {'lat': lat, 'lng': lng, 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      });

  static Future<void> addEarnings(String uid, double amount) async {
    await ref(uid).update({
      'balance': FieldValue.increment(amount),
      'totalDeliveries': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /* ----------------------------- Carteira ----------------------------- */

  static Stream<List<Payout>> payouts(String uid) {
    return Fire.db.collection('drivers/$uid/payouts').snapshots().map((snap) {
      final list = snap.docs.map((d) => Payout.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => tsMillis(b.createdAt).compareTo(tsMillis(a.createdAt)));
      return list;
    });
  }

  /// Solicita saque: cria o payout e debita o saldo.
  static Future<void> requestPayout(String uid,
      {required double amount, required String pixKey}) async {
    final batch = Fire.db.batch();
    final payoutRef = Fire.db.collection('drivers/$uid/payouts').doc();
    batch.set(payoutRef, {
      'amount': amount,
      'status': 'requested',
      'method': 'pix',
      'destination': pixKey,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(ref(uid), {
      'balance': FieldValue.increment(-amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

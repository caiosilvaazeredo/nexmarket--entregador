import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/drivers_repo.dart';
import '../services/fire.dart';
import '../services/location_service.dart';
import '../services/orders_repo.dart';

/// Estado global do entregador: auth, perfil, ofertas e entregas em tempo real.
class DriverState extends ChangeNotifier {
  User? user;
  DriverProfile? driver;
  bool profileLoaded = false;
  List<Order> availableOrders = [];
  List<Order> myDeliveries = [];

  final location = LocationService();

  StreamSubscription? _driverSub;
  StreamSubscription? _availableSub;
  StreamSubscription? _deliveriesSub;

  /// Ofertas já recusadas nesta sessão (não voltam a aparecer).
  final Set<String> declinedOffers = {};

  DriverState() {
    // Em teste (Firestore fake) não há FirebaseAuth real para assinar.
    if (Fire.isTestMode) return;
    Fire.auth.authStateChanges().listen((u) {
      user = u;
      _driverSub?.cancel();
      _availableSub?.cancel();
      _deliveriesSub?.cancel();
      driver = null;
      profileLoaded = false;
      availableOrders = [];
      myDeliveries = [];
      location.stop();

      if (u != null) {
        _driverSub = DriversRepo.profile(u.uid).listen((d) {
          final wasOnline = driver?.isOnline ?? false;
          driver = d;
          profileLoaded = true;
          final nowOnline = d?.isOnline ?? false;
          if (nowOnline && !wasOnline) {
            location.start(u.uid);
            _listenOffers();
          } else if (!nowOnline && wasOnline) {
            location.stop();
            _stopOffers();
          }
          notifyListeners();
        });
        _deliveriesSub = OrdersRepo.myDeliveries(u.uid).listen((orders) {
          myDeliveries = orders;
          notifyListeners();
        });
      }
      notifyListeners();
    });
  }

  bool get isLoggedIn => user != null;
  bool get isOnline => driver?.isOnline ?? false;

  Order? get activeDelivery {
    for (final o in myDeliveries) {
      if (o.isActiveDelivery) return o;
    }
    return null;
  }

  void _listenOffers() {
    _availableSub ??= OrdersRepo.availableOrders().listen((orders) {
      availableOrders =
          orders.where((o) => !declinedOffers.contains(o.id)).toList();
      notifyListeners();
    });
  }

  void _stopOffers() {
    _availableSub?.cancel();
    _availableSub = null;
    availableOrders = [];
    notifyListeners();
  }

  /// Cadastro aprovado no painel da Empresa — condição para receber corridas.
  bool get isApproved => driver?.isApproved ?? false;

  /// Fica online. Lança [StateError] com a mensagem certa quando o cadastro
  /// ainda não foi aprovado, foi recusado ou a conta está bloqueada.
  Future<void> setOnline(bool online) async {
    final uid = user?.uid;
    if (uid == null) return;
    if (online && !await location.ensurePermission()) {
      // Sem permissão de localização o entregador ainda pode ficar online;
      // apenas não será rastreado no mapa do cliente.
    }
    await DriversRepo.setOnline(uid, online, profile: driver);
  }

  void declineOffer(String orderId) {
    declinedOffers.add(orderId);
    availableOrders = availableOrders.where((o) => o.id != orderId).toList();
    notifyListeners();
  }

  /* --------------------- Resumo de ganhos --------------------- */

  double earningsSince(DateTime since) {
    double sum = 0;
    for (final o in myDeliveries) {
      if (o.deliveryStatus != 'delivered' && o.status != 'delivered') continue;
      final at = tsMillis(o.deliveredAt);
      if (at >= since.millisecondsSinceEpoch) sum += o.driverEarnings + o.tip;
    }
    return sum;
  }

  double get earningsToday {
    final now = DateTime.now();
    return earningsSince(DateTime(now.year, now.month, now.day));
  }

  double get earningsWeek {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return earningsSince(start);
  }

  double get earningsMonth {
    final now = DateTime.now();
    return earningsSince(DateTime(now.year, now.month));
  }

  Future<void> signOut() async {
    await setOnline(false).catchError((_) {});
    location.stop();
    await Fire.auth.signOut();
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _availableSub?.cancel();
    _deliveriesSub?.cancel();
    location.stop();
    super.dispose();
  }
}

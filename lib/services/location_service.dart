import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'drivers_repo.dart';

/// Rastreamento com filtro de distância (50 m) — só roda enquanto o
/// entregador está Online ou em corrida (bateria + privacidade).
class LocationService {
  StreamSubscription<Position>? _sub;

  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> current() async {
    if (!await ensurePermission()) return null;
    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<void> start(String uid) async {
    if (_sub != null) return;
    if (!await ensurePermission()) return;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((pos) {
      DriversRepo.updateLocation(uid, pos.latitude, pos.longitude);
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}

double distanceMeters(double lat1, double lng1, double lat2, double lng2) =>
    Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

String formatDistance(double? meters) {
  if (meters == null) return '—';
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

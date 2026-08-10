import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket_entregador/models.dart';
import 'package:nexmarket_entregador/services/nav_apps.dart';

void main() {
  final loja = NavDestination(
    point: GeoPointLite(-22.906847, -43.172896),
    address: 'Av. Rio Branco, 1 - Centro, Rio de Janeiro',
  );
  const semPonto = NavDestination(
    address: 'Rua da Assembleia, 10 - Centro, Rio de Janeiro',
  );

  group('Waze', () {
    test('usa coordenadas e já inicia a rota', () {
      final uri = navUri(NavApp.waze, loja);
      expect(uri.host, 'waze.com');
      expect(uri.queryParameters['ll'], '-22.906847,-43.172896');
      expect(uri.queryParameters['navigate'], 'yes');
    });

    test('cai para busca por endereço quando não há ponto salvo', () {
      final uri = navUri(NavApp.waze, semPonto);
      expect(uri.queryParameters['q'], contains('Assembleia'));
      expect(uri.queryParameters['ll'], isNull);
      expect(uri.queryParameters['navigate'], 'yes');
    });
  });

  group('Google Maps', () {
    test('usa coordenadas e modo carro', () {
      final uri = navUri(NavApp.googleMaps, loja);
      expect(uri.queryParameters['destination'], '-22.906847,-43.172896');
      expect(uri.queryParameters['travelmode'], 'driving');
      expect(uri.queryParameters['api'], '1');
    });

    test('cai para endereço quando não há ponto salvo', () {
      final uri = navUri(NavApp.googleMaps, semPonto);
      expect(uri.queryParameters['destination'], contains('Assembleia'));
    });
  });

  test('os links são https, para abrir na web quando o app não está instalado',
      () {
    for (final app in NavApp.values) {
      expect(navUri(app, loja).scheme, 'https',
          reason: 'esquema próprio falharia em quem não tem o ${app.label}');
    }
  });

  test('coordenada negativa não vira vírgula em pt_BR', () {
    // Uma vírgula decimal quebraria a URL: é ela que separa lat de lng.
    final uri = navUri(NavApp.waze, loja);
    expect(uri.queryParameters['ll']!.split(',').length, 2);
    expect(uri.queryParameters['ll'], isNot(contains(',-22,9')));
  });

  test('o endereço é codificado, então espaço e vírgula não quebram a URL', () {
    final uri = navUri(NavApp.googleMaps, semPonto);
    expect(uri.toString(), isNot(contains(' ')));
    // Vem de volta inteiro ao decodificar.
    expect(uri.queryParameters['destination'], semPonto.address);
  });

  group('preferência salva', () {
    test('"waze" e "google" continuam mapeando como antes', () {
      expect(NavApp.fromPref('waze'), NavApp.waze);
      expect(NavApp.fromPref('google'), NavApp.googleMaps);
    });

    test('valor ausente ou desconhecido cai no Google Maps', () {
      expect(NavApp.fromPref(null), NavApp.googleMaps);
      expect(NavApp.fromPref('apple'), NavApp.googleMaps);
    });

    test('prefKey volta o mesmo valor que o Firestore já guarda', () {
      expect(NavApp.waze.prefKey, 'waze');
      expect(NavApp.googleMaps.prefKey, 'google');
    });
  });
}

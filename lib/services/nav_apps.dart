import 'package:url_launcher/url_launcher.dart';

import '../models.dart';

/// Aplicativos de navegação de terceiros.
///
/// O mapa dentro do app serve para o entregador **se situar** — ver onde fica
/// a loja, para que lado é o cliente, quanto falta. Quem guia de fato é o Waze
/// ou o Google Maps: eles têm trânsito em tempo real, radar, voz e
/// recalculam rota, coisas que não faz sentido reimplementar.
enum NavApp {
  waze,
  googleMaps;

  String get label => switch (this) {
        NavApp.waze => 'Waze',
        NavApp.googleMaps => 'Google Maps',
      };

  /// Chave usada em `DriverPreferences.navApp` (mantida como estava para não
  /// invalidar o que já está gravado no Firestore).
  String get prefKey => switch (this) {
        NavApp.waze => 'waze',
        NavApp.googleMaps => 'google',
      };

  static NavApp fromPref(String? value) =>
      value == 'waze' ? NavApp.waze : NavApp.googleMaps;
}

/// Para onde navegar: coordenadas quando a loja/cliente têm ponto salvo,
/// senão o endereço em texto — que os dois aplicativos sabem pesquisar.
class NavDestination {
  final GeoPointLite? point;
  final String address;

  const NavDestination({this.point, required this.address});

  bool get hasPoint => point != null;
}

/// Monta o link universal de cada aplicativo.
///
/// São links `https://`, não esquemas próprios (`waze://`): no Android e no
/// iOS o sistema entrega ao aplicativo instalado, e quando ele não está
/// instalado abre a versão web em vez de dar erro. Um esquema próprio falharia
/// silenciosamente para quem não tem o app — e no navegador (PWA) nunca
/// funcionaria.
Uri navUri(NavApp app, NavDestination dest) {
  final p = dest.point;

  switch (app) {
    case NavApp.waze:
      // `navigate=yes` já inicia a rota em vez de só centralizar o mapa.
      if (p != null) {
        return Uri.parse(
            'https://waze.com/ul?ll=${_coord(p.lat)},${_coord(p.lng)}&navigate=yes');
      }
      return Uri.parse(
          'https://waze.com/ul?q=${Uri.encodeComponent(dest.address)}&navigate=yes');

    case NavApp.googleMaps:
      final destination = p != null
          ? '${_coord(p.lat)},${_coord(p.lng)}'
          : Uri.encodeComponent(dest.address);
      return Uri.parse('https://www.google.com/maps/dir/?api=1'
          '&destination=$destination&travelmode=driving');
  }
}

/// Coordenada sempre com ponto decimal.
///
/// O app roda em pt_BR, onde o separador é vírgula — e uma vírgula aqui
/// quebraria a URL, porque é ela que separa latitude de longitude. O
/// `toString()` de `double` no Dart é independente de locale, então esta
/// função existe sobretudo para deixar a intenção explícita e travada por
/// teste.
String _coord(double v) => v.toString();

/// Abre o aplicativo escolhido. Retorna `false` quando o sistema não
/// conseguiu abrir nada, para a tela poder avisar em vez de não fazer nada.
Future<bool> openNavApp(NavApp app, NavDestination dest) =>
    launchUrl(navUri(app, dest), mode: LaunchMode.externalApplication);

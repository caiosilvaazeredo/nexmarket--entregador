import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/location_service.dart';
import '../theme.dart';

/// Mapa da perna atual da corrida, sobre OpenStreetMap.
///
/// O papel dele é situar, não guiar: mostra onde está o entregador, onde é o
/// destino e quanto falta, para a pessoa decidir se aceita ou por onde sai. A
/// navegação passo a passo fica com o Waze/Google Maps, nos botões abaixo do
/// mapa (ver services/nav_apps.dart).
///
/// A linha entre os dois pontos é **reta**, e de propósito: desenhar a rota
/// real exigiria um serviço de roteamento, e o único gratuito e aberto
/// (OSRM público) é declaradamente para demonstração, não para produção. Como
/// a rota de verdade aparece no app de navegação, a linha aqui só indica a
/// direção — por isso é tracejada, para não se passar por trajeto.
class DeliveryMap extends StatelessWidget {
  /// Onde o entregador está. `null` enquanto o GPS não respondeu.
  final GeoPointLite? origin;

  /// Loja (na coleta) ou cliente (na entrega).
  final GeoPointLite? destination;

  /// Texto do balão do destino: nome da loja ou do cliente.
  final String destinationLabel;

  /// Ícone do destino — muda entre coleta e entrega.
  final IconData destinationIcon;

  final double height;

  const DeliveryMap({
    super.key,
    required this.origin,
    required this.destination,
    required this.destinationLabel,
    this.destinationIcon = Icons.store,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final dest = destination;

    // Sem destino salvo não há mapa que ajude — a loja/cliente só tem
    // endereço em texto. Os botões de navegação continuam funcionando por
    // busca de endereço, então avisamos em vez de mostrar um mapa vazio.
    if (dest == null) {
      return _Placeholder(
        height: height,
        icon: Icons.location_off_outlined,
        message: 'Sem ponto no mapa para este endereço.\n'
            'Os botões de navegação buscam pelo endereço.',
      );
    }

    final destLatLng = LatLng(dest.lat, dest.lng);
    final originLatLng =
        origin == null ? null : LatLng(origin!.lat, origin!.lng);

    final meters = origin == null
        ? null
        : distanceMeters(origin!.lat, origin!.lng, dest.lat, dest.lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: destLatLng,
                initialZoom: 15,
                // Com os dois pontos conhecidos, enquadra ambos: o entregador
                // vê a relação entre onde está e para onde vai sem dar zoom.
                initialCameraFit: originLatLng == null
                    ? null
                    : CameraFit.bounds(
                        bounds:
                            LatLngBounds.fromPoints([originLatLng, destLatLng]),
                        padding: const EdgeInsets.all(48),
                        maxZoom: 16,
                      ),
                interactionOptions: const InteractionOptions(
                  // Rotacionar atrapalha mais do que ajuda num mapa pequeno,
                  // e é fácil disparar sem querer com dois dedos.
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // A política de uso dos tiles da OSM exige identificar o
                  // aplicativo; sem isso o tráfego pode ser bloqueado.
                  userAgentPackageName: 'br.com.nexmarket.nexmarket_entregador',
                  maxNativeZoom: 19,
                ),
                if (originLatLng != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [originLatLng, destLatLng],
                        color: kGreenDark.withValues(alpha: .8),
                        strokeWidth: 3,
                        pattern: StrokePattern.dashed(segments: const [8, 6]),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (originLatLng != null)
                      Marker(
                        point: originLatLng,
                        width: 26,
                        height: 26,
                        child: const _DriverDot(),
                      ),
                    Marker(
                      point: destLatLng,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: _DestinationPin(icon: destinationIcon),
                    ),
                  ],
                ),
                // Atribuição obrigatória: os dados da OSM são ODbL e exigem
                // crédito visível. Não é enfeite — é condição de uso.
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  animationConfig: const ScaleRAWA(),
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (meters != null)
              Positioned(
                top: 8,
                right: 8,
                child: _Chip(
                    text: '${formatDistance(meters)} em linha reta',
                    label: destinationLabel),
              ),
          ],
        ),
      ),
    );
  }
}

class _DriverDot extends StatelessWidget {
  const _DriverDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .3),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
    );
  }
}

class _DestinationPin extends StatelessWidget {
  final IconData icon;
  const _DestinationPin({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kGreenDark,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .35),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final String label;
  const _Chip({required this.text, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .15), blurRadius: 6),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(text,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double height;
  final IconData icon;
  final String message;
  const _Placeholder(
      {required this.height, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }
}

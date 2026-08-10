import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket_entregador/models.dart';
import 'package:nexmarket_entregador/widgets/delivery_map.dart';

/// Só o caminho sem rede: com destino salvo o mapa baixa tiles da
/// OpenStreetMap, o que não cabe num teste unitário. O que importa cobrir
/// aqui é o caso degradado — endereço sem coordenada —, porque é ele que
/// decide entre avisar o entregador e mostrar um mapa vazio no meio da rua.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('sem coordenada, explica e aponta para os botões', (t) async {
    await t.pumpWidget(wrap(const DeliveryMap(
      origin: null,
      destination: null,
      destinationLabel: 'Mercado Central',
    )));

    expect(find.textContaining('Sem ponto no mapa'), findsOneWidget);
    expect(find.textContaining('buscam pelo endereço'), findsOneWidget);
  });

  testWidgets('sem coordenada não tenta desenhar mapa nenhum', (t) async {
    await t.pumpWidget(wrap(const DeliveryMap(
      origin: null,
      destination: null,
      destinationLabel: 'Mercado Central',
    )));

    // Um mapa vazio na tela sugeriria "o destino é aqui, no meio do oceano".
    expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
  });

  testWidgets('respeita a altura pedida', (t) async {
    await t.pumpWidget(wrap(const DeliveryMap(
      origin: null,
      destination: null,
      destinationLabel: 'Mercado Central',
      height: 140,
    )));

    final box = t.widget<Container>(
      find
          .ancestor(
              of: find.byIcon(Icons.location_off_outlined),
              matching: find.byType(Container))
          .first,
    );
    expect(box.constraints?.maxHeight ?? 0, 140);
  });

  testWidgets('a origem sozinha não basta — sem destino continua o aviso',
      (t) async {
    await t.pumpWidget(wrap(DeliveryMap(
      origin: GeoPointLite(-22.9, -43.17),
      destination: null,
      destinationLabel: 'Mercado Central',
    )));

    expect(find.textContaining('Sem ponto no mapa'), findsOneWidget);
  });
}

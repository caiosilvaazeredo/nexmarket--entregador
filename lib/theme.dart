import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Identidade "Duolingo" da plataforma: verde `#58CC02`, botões grandes e alto
/// contraste para uso sob sol.
const kGreen = Color(0xFF58CC02);
const kGreenDark = Color(0xFF46A302);

ThemeData buildTheme({bool dark = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kGreen,
    primary: kGreen,
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF16181C) : const Color(0xFFF7F7F7),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF1D2025) : Colors.white,
      foregroundColor: dark ? Colors.white : Colors.black87,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: dark ? Colors.white : Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      surfaceTintColor: dark ? const Color(0xFF1D2025) : Colors.white,
      iconTheme: const IconThemeData(color: kGreen),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kGreen,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: kGreen, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1D2025) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
            color: dark ? const Color(0xFF33363C) : const Color(0xFFE5E5E5), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kGreen, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF1D2025) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: dark ? const Color(0xFF33363C) : const Color(0xFFE5E5E5), width: 1.5),
      ),
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

String money(num value) => _currency.format(value);

/// Rótulos do sub-status de entrega, na voz do entregador.
const deliveryStatusLabels = <String, String>{
  'awaiting_driver': 'Aguardando entregador',
  'assigned': 'Atribuída',
  'going_to_store': 'Indo à loja',
  'arrived_store': 'Na loja',
  'picked_up': 'Pedido coletado',
  'going_to_customer': 'Indo ao cliente',
  'delivered': 'Entregue',
  'problem': 'Problema reportado',
};

const problemTypes = <(String, String)>[
  ('address_not_found', 'Endereço não encontrado'),
  ('customer_absent', 'Cliente ausente'),
  ('damaged_package', 'Pacote danificado'),
  ('other', 'Outro problema'),
];

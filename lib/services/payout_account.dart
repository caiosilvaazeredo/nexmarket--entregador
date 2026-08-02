/// Conta de recebimento do entregador e calendário de repasse.
///
/// Os dados ficam em `drivers/{uid}.bank` (mesmo campo que o painel da
/// Empresa já lê para pagar os saques). O calendário — de quanto em quanto
/// tempo o entregador recebe — é definido pela Nexmarket no app da Empresa e
/// publicado em `platformConfig/public.driverPayout`.
library;

import 'fire.dart';

enum PixKeyType { cpf, cnpj, email, phone, random }

const pixKeyLabels = {
  PixKeyType.cpf: 'CPF',
  PixKeyType.cnpj: 'CNPJ',
  PixKeyType.email: 'E-mail',
  PixKeyType.phone: 'Celular',
  PixKeyType.random: 'Chave aleatória',
};

String pixKeyTypeToString(PixKeyType t) => t.name;

PixKeyType pixKeyTypeFrom(String? value) => PixKeyType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => PixKeyType.cpf,
    );

String onlyDigits(String v) => v.replaceAll(RegExp(r'\D'), '');

bool isValidCpf(String input) {
  final d = onlyDigits(input);
  if (d.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
  int digit(int len) {
    var sum = 0;
    for (var i = 0; i < len; i++) {
      sum += (d.codeUnitAt(i) - 48) * (len + 1 - i);
    }
    final rest = (sum * 10) % 11;
    return rest == 10 ? 0 : rest;
  }

  return digit(9) == d.codeUnitAt(9) - 48 && digit(10) == d.codeUnitAt(10) - 48;
}

bool isValidCnpj(String input) {
  final d = onlyDigits(input);
  if (d.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(d)) return false;
  int calc(int len) {
    final weights = len == 12
        ? [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        : [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var i = 0; i < len; i++) {
      sum += (d.codeUnitAt(i) - 48) * weights[i];
    }
    final rest = sum % 11;
    return rest < 2 ? 0 : 11 - rest;
  }

  return calc(12) == d.codeUnitAt(12) - 48 && calc(13) == d.codeUnitAt(13) - 48;
}

/// Valida a chave conforme o tipo. Chave errada = repasse preso, então o
/// app barra antes de salvar.
String? validatePixKey(PixKeyType type, String key) {
  final raw = key.trim();
  if (raw.isEmpty) return 'Informe a chave PIX.';
  switch (type) {
    case PixKeyType.cpf:
      return isValidCpf(raw) ? null : 'CPF inválido.';
    case PixKeyType.cnpj:
      return isValidCnpj(raw) ? null : 'CNPJ inválido.';
    case PixKeyType.email:
      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(raw)
          ? null
          : 'E-mail inválido.';
    case PixKeyType.phone:
      return RegExp(r'^(55)?\d{11}$').hasMatch(onlyDigits(raw))
          ? null
          : 'Celular inválido (DDD + 9 dígitos).';
    case PixKeyType.random:
      return RegExp(
                  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                  caseSensitive: false)
              .hasMatch(raw)
          ? null
          : 'Chave aleatória deve ter o formato UUID.';
  }
}

/// Calendário de repasse publicado pela Empresa.
class PayoutSchedule {
  final String cadence; // daily | weekly | biweekly | monthly
  final int weekday; // 1=segunda … 7=domingo
  final int monthDay;
  final int holdDays;
  final double minimumAmount;

  PayoutSchedule({
    this.cadence = 'weekly',
    this.weekday = 2,
    this.monthDay = 5,
    this.holdDays = 1,
    this.minimumAmount = 0,
  });

  factory PayoutSchedule.fromMap(Map<String, dynamic> m) => PayoutSchedule(
        cadence: (m['cadence'] as String?) ?? 'weekly',
        weekday: (m['weekday'] as num?)?.toInt() ?? 2,
        monthDay: (m['monthDay'] as num?)?.toInt() ?? 5,
        holdDays: (m['holdDays'] as num?)?.toInt() ?? 1,
        minimumAmount: (m['minimumAmount'] as num?)?.toDouble() ?? 0,
      );

  static const _weekdays = [
    '', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo',
  ];

  /// "Toda terça · liberado em D+1 · mínimo R$ 20,00"
  String get description {
    final when = switch (cadence) {
      'daily' => 'Todo dia útil',
      'monthly' => 'Todo dia $monthDay',
      'biweekly' => 'A cada 15 dias (${_weekdays[weekday.clamp(1, 7)]})',
      _ => 'Toda ${_weekdays[weekday.clamp(1, 7)]}',
    };
    final hold = holdDays > 0 ? ' · liberado em D+$holdDays' : '';
    final min = minimumAmount > 0
        ? ' · mínimo R\$ ${minimumAmount.toStringAsFixed(2).replaceAll('.', ',')}'
        : '';
    return '$when$hold$min';
  }

  /// Próxima data de pagamento a partir de [from].
  DateTime nextPayoutDate([DateTime? from]) {
    final base0 = from ?? DateTime.now();
    final base = DateTime(base0.year, base0.month, base0.day);

    if (cadence == 'daily') {
      var d = base.add(const Duration(days: 1));
      while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        d = d.add(const Duration(days: 1));
      }
      return d;
    }
    if (cadence == 'monthly') {
      var d = DateTime(base.year, base.month, monthDay.clamp(1, 28));
      if (!d.isAfter(base)) d = DateTime(base.year, base.month + 1, monthDay.clamp(1, 28));
      return d;
    }
    final target = weekday.clamp(1, 7);
    var delta = (target - base.weekday + 7) % 7;
    if (delta == 0) delta = 7;
    var d = base.add(Duration(days: delta));
    if (cadence == 'biweekly' && delta < 7) d = d.add(const Duration(days: 7));
    return d;
  }
}

class PayoutRepo {
  /// Calendário de repasse dos entregadores (definido no app da Empresa).
  static Stream<PayoutSchedule?> schedule() {
    return Fire.db.doc('platformConfig/public').snapshots().map((d) {
      if (!d.exists) return null;
      final s = d.data()?['driverPayout'];
      return s is Map ? PayoutSchedule.fromMap(Map<String, dynamic>.from(s)) : null;
    });
  }
}

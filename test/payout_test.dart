import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket_entregador/models.dart';
import 'package:nexmarket_entregador/services/drivers_repo.dart';
import 'package:nexmarket_entregador/services/fire.dart';
import 'package:nexmarket_entregador/services/payout_account.dart';

void main() {
  group('Validação de chave PIX', () {
    test('CPF', () {
      expect(validatePixKey(PixKeyType.cpf, '529.982.247-25'), isNull);
      expect(validatePixKey(PixKeyType.cpf, '52998224726'), isNotNull);
      expect(validatePixKey(PixKeyType.cpf, '111.111.111-11'), isNotNull);
    });

    test('CNPJ', () {
      expect(validatePixKey(PixKeyType.cnpj, '11.222.333/0001-81'), isNull);
      expect(validatePixKey(PixKeyType.cnpj, '11222333000182'), isNotNull);
    });

    test('e-mail e celular', () {
      expect(validatePixKey(PixKeyType.email, 'joao@exemplo.com'), isNull);
      expect(validatePixKey(PixKeyType.email, 'joao@'), isNotNull);
      expect(validatePixKey(PixKeyType.phone, '(21) 99999-8888'), isNull);
      expect(validatePixKey(PixKeyType.phone, '5521999998888'), isNull);
      expect(validatePixKey(PixKeyType.phone, '2199999'), isNotNull);
    });

    test('chave aleatória precisa ser UUID', () {
      expect(
          validatePixKey(
              PixKeyType.random, '123e4567-e89b-12d3-a456-426614174000'),
          isNull);
      expect(validatePixKey(PixKeyType.random, 'chave-qualquer'), isNotNull);
    });

    test('chave vazia é recusada em qualquer tipo', () {
      for (final t in PixKeyType.values) {
        expect(validatePixKey(t, '  '), isNotNull);
      }
    });
  });

  group('BankInfo', () {
    test('PIX completo e resumo', () {
      final b = BankInfo(
          method: 'pix',
          holderName: 'João Motoboy',
          pixKeyType: 'email',
          pixKey: 'joao@exemplo.com');
      expect(b.usesPix, isTrue);
      expect(b.isComplete, isTrue);
      expect(b.summary, 'PIX · E-mail: joao@exemplo.com');
    });

    test('conta bancária exige banco, agência e conta', () {
      var b = BankInfo(method: 'bank', holderName: 'João');
      expect(b.isComplete, isFalse);
      b = b.copyWith(bankName: 'Banco X', agency: '0001', account: '12345-6');
      expect(b.isComplete, isTrue);
      expect(b.summary, 'Banco X · Ag. 0001 · Conta 12345-6');
    });

    test('sem titular nunca está completa', () {
      final b = BankInfo(method: 'pix', pixKey: 'x@y.com');
      expect(b.isComplete, isFalse);
      expect(b.summary, 'Cadastre onde quer receber');
    });

    test('serializa e volta sem perder campos', () {
      final b = BankInfo(
        method: 'bank',
        holderName: 'João',
        cpf: '52998224725',
        bankName: 'Banco X',
        agency: '0001',
        account: '12345-6',
        accountType: 'savings',
      );
      final back = BankInfo.fromMap(b.toMap());
      expect(back.method, 'bank');
      expect(back.accountType, 'savings');
      expect(back.account, '12345-6');
    });
  });

  group('Calendário de repasse (definido na Empresa)', () {
    test('descrição semanal com carência e mínimo', () {
      final s = PayoutSchedule(
          cadence: 'weekly', weekday: 2, holdDays: 1, minimumAmount: 20);
      expect(s.description, 'Toda terça · liberado em D+1 · mínimo R\$ 20,00');
    });

    test('descrição mensal e diária', () {
      expect(PayoutSchedule(cadence: 'monthly', monthDay: 10, holdDays: 0).description,
          'Todo dia 10');
      expect(PayoutSchedule(cadence: 'daily', holdDays: 0).description,
          'Todo dia útil');
    });

    test('próxima data semanal cai no dia escolhido', () {
      // 2026-07-27 é uma segunda-feira.
      final from = DateTime(2026, 7, 27);
      final s = PayoutSchedule(cadence: 'weekly', weekday: 5); // sexta
      final next = s.nextPayoutDate(from);
      expect(next.weekday, DateTime.friday);
      expect(next, DateTime(2026, 7, 31));
    });

    test('no próprio dia do repasse pula para a semana seguinte', () {
      final monday = DateTime(2026, 7, 27);
      final s = PayoutSchedule(cadence: 'weekly', weekday: 1); // segunda
      expect(s.nextPayoutDate(monday), DateTime(2026, 8, 3));
    });

    test('quinzenal salta 14 dias quando a ocorrência está próxima', () {
      final monday = DateTime(2026, 7, 27);
      final s = PayoutSchedule(cadence: 'biweekly', weekday: 3); // quarta
      // Quarta mais próxima é 29/07 (2 dias) → vai para a seguinte.
      expect(s.nextPayoutDate(monday), DateTime(2026, 8, 5));
    });

    test('diário pula fim de semana', () {
      final friday = DateTime(2026, 7, 31);
      final s = PayoutSchedule(cadence: 'daily');
      expect(s.nextPayoutDate(friday), DateTime(2026, 8, 3)); // segunda
    });

    test('mensal vai para o mês seguinte quando o dia já passou', () {
      final s = PayoutSchedule(cadence: 'monthly', monthDay: 5);
      expect(s.nextPayoutDate(DateTime(2026, 7, 20)), DateTime(2026, 8, 5));
      expect(s.nextPayoutDate(DateTime(2026, 7, 1)), DateTime(2026, 7, 5));
    });
  });

  group('Persistência', () {
    late FakeFirebaseFirestore db;

    setUp(() async {
      db = FakeFirebaseFirestore();
      Fire.overrideForTests(db, uid: 'driver1');
      await DriversRepo.createProfile('driver1',
          name: 'João', email: 'joao@x.com');
    });

    test('salva onde o entregador recebe', () async {
      final bank = BankInfo(
          method: 'pix',
          holderName: 'João Motoboy',
          cpf: '52998224725',
          pixKeyType: 'phone',
          pixKey: '21999998888');
      await DriversRepo.update('driver1', {'bank': bank.toMap()});

      final d = await DriversRepo.get('driver1');
      expect(d!.bank.isComplete, isTrue);
      expect(d.bank.pixKeyType, 'phone');
      expect(d.bank.pixKey, '21999998888');
    });

    test('lê o calendário publicado pela Empresa', () async {
      await db.doc('platformConfig/public').set({
        'driverPayout': {
          'cadence': 'weekly',
          'weekday': 2,
          'holdDays': 1,
          'minimumAmount': 20,
        },
      });
      final s = await PayoutRepo.schedule().first;
      expect(s, isNotNull);
      expect(s!.cadence, 'weekly');
      expect(s.holdDays, 1);
      expect(s.description, contains('terça'));
    });

    test('sem calendário publicado devolve null (app mostra o padrão)', () async {
      expect(await PayoutRepo.schedule().first, isNull);
    });
  });
}

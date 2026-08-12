import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket_entregador/models.dart';
import 'package:nexmarket_entregador/services/documents_repo.dart';
import 'package:nexmarket_entregador/services/drivers_repo.dart';
import 'package:nexmarket_entregador/services/fire.dart';

/// Cadastro do entregador: envio de documentos e aprovação feita no app da
/// Empresa. Os testes simulam as escritas do painel exatamente como
/// `nexmarket--Empresa/src/lib/drivers.ts` as faz.
void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    Fire.overrideForTests(db, uid: 'driver1');
    await DriversRepo.createProfile('driver1',
        name: 'João Motoboy',
        email: 'joao@x.com',
        phone: '21999999999',
        cpf: '52998224725');
  });

  Future<DriverProfile> profile() async => (await DriversRepo.get('driver1'))!;

  /// Espelha `setDriverApproval` do painel da Empresa.
  Future<void> adminSetApproval(String status, {String? reason}) async {
    await db.doc('drivers/driver1').update({
      'approvalStatus': status,
      'blockedReason': reason,
      'documents.status': status == 'approved'
          ? 'approved'
          : status == 'pending'
              ? 'pending'
              : 'rejected',
      if (status == 'blocked') 'status': 'offline',
      'reviewedBy': 'admin1',
    });
  }

  /// Espelha `reviewDriverDoc` do painel da Empresa.
  Future<void> adminReviewDoc(String key, String status, {String? reason}) async {
    await db.doc('drivers/driver1').update({
      'documents.review.$key': {
        'status': status,
        'rejectionReason': reason,
        'reviewedBy': 'admin1',
      },
    });
  }

  test('conta nasce pendente de aprovação e sem documentos', () async {
    final d = await profile();
    expect(d.approvalStatus, 'pending');
    expect(d.isApproved, isFalse);
    expect(d.isUnderReview, isTrue);
    expect(d.allDocumentsSent, isFalse);
    expect(d.pendingDocuments.length, 4); // CNH, CRLV, foto, comprovante
    expect(d.cpf, '52998224725');
    expect(d.approvalLabel, 'Envie seus documentos');
  });

  test('entregador não aprovado não consegue ficar online', () async {
    final d = await profile();
    await expectLater(
      DriversRepo.setOnline('driver1', true, profile: d),
      throwsA(isA<StateError>()),
    );
    // O status no banco continua offline.
    expect((await profile()).status, 'offline');
  });

  test('documentos enviados vão para análise nos campos que a Empresa lê',
      () async {
    for (final key in DriverDoc.urlFields.keys) {
      await DocumentsRepo.attachDocument(
          uid: 'driver1', key: key, value: 'drivers/driver1/documents/$key.jpg');
    }

    final raw = (await db.doc('drivers/driver1').get()).data()!;
    final docs = raw['documents'] as Map;
    // Campos planos consumidos pelo painel (cnhUrl, vehicleDocUrl…).
    expect(docs['cnhUrl'], 'drivers/driver1/documents/cnh.jpg');
    expect(docs['vehicleDocUrl'], isNotEmpty);
    expect(docs['profilePhotoUrl'], isNotEmpty);
    expect(docs['proofOfResidenceUrl'], isNotEmpty);
    expect(docs['status'], 'pending');
    expect(raw['approvalStatus'], 'pending');

    final d = await profile();
    expect(d.allDocumentsSent, isTrue);
    expect(d.pendingDocuments, isEmpty);
    expect(d.approvalLabel, 'Documentos em análise');
    expect(d.isApproved, isFalse); // enviar não é ser aprovado
  });

  test('aprovação no painel da Empresa libera o entregador', () async {
    for (final key in DriverDoc.urlFields.keys) {
      await DocumentsRepo.attachDocument(
          uid: 'driver1', key: key, value: 'path/$key.jpg');
    }
    await adminSetApproval('approved');

    final d = await profile();
    expect(d.isApproved, isTrue);
    expect(d.approvalLabel, 'Cadastro aprovado');

    // Agora consegue ficar online.
    await DriversRepo.setOnline('driver1', true, profile: d);
    expect((await profile()).status, 'online');
  });

  test('recusa de um documento traz o motivo e pede reenvio só dele', () async {
    for (final key in DriverDoc.urlFields.keys) {
      await DocumentsRepo.attachDocument(
          uid: 'driver1', key: key, value: 'path/$key.jpg');
    }
    await adminReviewDoc('cnh', 'rejected', reason: 'Foto ilegível');
    await adminReviewDoc('profilePhoto', 'approved');
    await adminSetApproval('rejected', reason: 'Reenvie a CNH');

    final d = await profile();
    expect(d.isRejected, isTrue);
    expect(d.isApproved, isFalse);

    final cnh = d.docFor('cnh')!;
    expect(cnh.isRejected, isTrue);
    expect(cnh.rejectionReason, 'Foto ilegível');
    expect(cnh.needsUpload, isTrue);

    final photo = d.docFor('profilePhoto')!;
    expect(photo.isApproved, isTrue);
    expect(photo.needsUpload, isFalse); // aprovado não precisa reenviar

    // Só a CNH volta para a fila de reenvio.
    expect(d.pendingDocuments.map((e) => e.key), ['cnh']);
  });

  test('reenviar documento recusado devolve a conta para análise', () async {
    await DocumentsRepo.attachDocument(
        uid: 'driver1', key: 'cnh', value: 'path/cnh.jpg');
    await adminReviewDoc('cnh', 'rejected', reason: 'Foto ilegível');
    await adminSetApproval('rejected', reason: 'Reenvie a CNH');
    expect((await profile()).isRejected, isTrue);

    // Entregador manda a CNH de novo.
    await DocumentsRepo.attachDocument(
        uid: 'driver1', key: 'cnh', value: 'path/cnh-v2.jpg');

    final d = await profile();
    expect(d.approvalStatus, 'pending'); // saiu de "recusado"
    expect(d.docFor('cnh')!.isRejected, isFalse);
    expect(d.docFor('cnh')!.rejectionReason, isEmpty);
    expect(d.docFor('cnh')!.url, 'path/cnh-v2.jpg');
  });

  test('bloqueio pela Empresa derruba o entregador e impede voltar', () async {
    await adminSetApproval('approved');
    await DriversRepo.setOnline('driver1', true, profile: await profile());
    expect((await profile()).status, 'online');

    await adminSetApproval('blocked', reason: 'Denúncia de conduta');

    final d = await profile();
    expect(d.isBlocked, isTrue);
    expect(d.status, 'offline'); // o painel força offline
    expect(d.blockedReason, 'Denúncia de conduta');
    await expectLater(
      DriversRepo.setOnline('driver1', true, profile: d),
      throwsA(isA<StateError>()),
    );
  });

  test('perfil antigo sem approvalStatus deriva do status dos documentos',
      () async {
    await db.doc('drivers/legacy').set({
      'name': 'Antigo',
      'documents': {'status': 'approved'},
    });
    final legacy = DriverProfile.fromMap(
        'legacy', (await db.doc('drivers/legacy').get()).data()!);
    expect(legacy.isApproved, isTrue);

    await db.doc('drivers/legacy2').set({
      'name': 'Antigo 2',
      'documents': {'status': 'pending'},
    });
    final legacy2 = DriverProfile.fromMap(
        'legacy2', (await db.doc('drivers/legacy2').get()).data()!);
    expect(legacy2.isApproved, isFalse);
  });

  test('caminho no Storage é escopado por entregador', () {
    expect(DocumentsRepo.storagePath('driver1', 'cnh'),
        'drivers/driver1/documents/cnh.jpg');
  });
}

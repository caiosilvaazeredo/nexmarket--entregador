import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import 'drivers_repo.dart';
import 'fire.dart';

/// Envio dos documentos do cadastro (CNH, CRLV, foto e comprovante de
/// residência).
///
/// Os arquivos vão para o Firebase Storage em
/// `drivers/{uid}/documents/{chave}` e **o que gravamos no Firestore é o
/// caminho**, não uma URL pública — o painel da Empresa gera um link
/// assinado na hora de revisar (RNF03). Reenviar um documento recusado
/// devolve a conta para análise.
class DocumentsRepo {
  static final _picker = ImagePicker();

  /// Abre a câmera ou a galeria e devolve os bytes já comprimidos.
  static Future<({Uint8List bytes, String name})?> pickImage(
      {required bool fromCamera}) async {
    final file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // Documento legível sem estourar o upload no 4G do entregador.
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (file == null) return null;
    return (bytes: await file.readAsBytes(), name: file.name);
  }

  static String storagePath(String uid, String key) =>
      'drivers/$uid/documents/$key.jpg';

  /// Sobe o arquivo e registra o caminho no perfil, devolvendo o documento
  /// para análise. Retorna o caminho gravado.
  static Future<String> uploadDocument({
    required String uid,
    required String key,
    required Uint8List bytes,
  }) async {
    final path = storagePath(uid, key);
    await FirebaseStorage.instance.ref(path).putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
    await attachDocument(uid: uid, key: key, value: path);
    return path;
  }

  /// Grava a referência do documento e reabre a análise.
  ///
  /// Escreve no campo plano que o painel da Empresa lê (`cnhUrl`,
  /// `vehicleDocUrl`…) e limpa o parecer anterior daquele documento, para
  /// que um reenvio não continue marcado como recusado.
  static Future<void> attachDocument({
    required String uid,
    required String key,
    required String value,
  }) async {
    final field = DriverDoc.urlFields[key];
    if (field == null) throw ArgumentError('Documento desconhecido: $key');
    await DriversRepo.ref(uid).set({
      'documents': {
        field: value,
        'status': 'pending',
        'review': {
          key: {'status': 'pending', 'rejectionReason': null},
        },
      },
      // Reenvio tira a conta de "recusada" e devolve para a fila de análise.
      'approvalStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Marca o cadastro como enviado para análise (após todos os documentos).
  static Future<void> submitForReview(String uid) =>
      DriversRepo.update(uid, {
        'documents': {'status': 'pending'},
        'approvalStatus': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

  /// Link temporário para o entregador conferir o que enviou.
  static Future<String?> previewUrl(String value) async {
    if (value.isEmpty) return null;
    if (value.startsWith('http') || value.startsWith('data:')) return value;
    try {
      return await FirebaseStorage.instance.ref(value).getDownloadURL();
    } catch (e) {
      debugPrint('previewUrl falhou: $e');
      return null;
    }
  }

  /// Usado nos testes para injetar um upload falso (sem Storage real).
  @visibleForTesting
  static bool get isTestMode => Fire.isTestMode;
}

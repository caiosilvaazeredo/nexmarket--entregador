import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/documents_repo.dart';
import '../state/driver_state.dart';
import '../theme.dart';

/// Envio e acompanhamento dos documentos do cadastro.
///
/// O entregador manda CNH, documento do veículo, foto e comprovante de
/// residência; a análise e a aprovação são feitas no **app da Empresa**. Cada
/// documento tem seu próprio parecer — se um for recusado, dá para reenviar
/// só ele, e a conta volta para a fila de análise.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String? _uploading;

  Future<void> _send(DriverDoc docItem, {required bool fromCamera}) async {
    final state = context.read<DriverState>();
    final uid = state.user?.uid;
    if (uid == null) return;

    setState(() => _uploading = docItem.key);
    try {
      final picked = await DocumentsRepo.pickImage(fromCamera: fromCamera);
      if (picked == null) return;
      await DocumentsRepo.uploadDocument(
          uid: uid, key: docItem.key, bytes: picked.bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${docItem.label} enviado para análise.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha ao enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  void _chooseSource(DriverDoc docItem) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(docItem.label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _send(docItem, fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.pop(ctx);
                _send(docItem, fromCamera: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DriverState>();
    final driver = state.driver;
    if (driver == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meus documentos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ApprovalBanner(driver: driver),
          const SizedBox(height: 16),
          for (final d in driver.documents)
            _DocumentTile(
              doc: d,
              busy: _uploading == d.key,
              onSend: () => _chooseSource(d),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Seus documentos são enviados com segurança e vistos '
                    'apenas pela equipe de análise da Nexmarket.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Situação do cadastro, com o motivo quando recusado/bloqueado.
class _ApprovalBanner extends StatelessWidget {
  final DriverProfile driver;
  const _ApprovalBanner({required this.driver});

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, message) = switch (driver.approvalStatus) {
      'approved' => (
          kGreen,
          Icons.verified,
          'Cadastro aprovado',
          'Tudo certo! Você já pode ficar online e receber corridas.'
        ),
      'rejected' => (
          Colors.redAccent,
          Icons.gpp_bad,
          'Cadastro recusado',
          driver.blockedReason.isNotEmpty
              ? driver.blockedReason
              : 'Reenvie os documentos marcados abaixo para uma nova análise.'
        ),
      'blocked' => (
          Colors.redAccent,
          Icons.block,
          'Conta bloqueada',
          driver.blockedReason.isNotEmpty
              ? driver.blockedReason
              : 'Entre em contato com o suporte da Nexmarket.'
        ),
      _ => (
          Colors.orange,
          Icons.pending_actions,
          driver.allDocumentsSent ? 'Em análise' : 'Documentos pendentes',
          driver.allDocumentsSent
              ? 'A equipe da Nexmarket está conferindo seus documentos. '
                  'Você será avisado assim que for aprovado.'
              : 'Envie os documentos abaixo para começar a análise.'
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final DriverDoc doc;
  final bool busy;
  final VoidCallback onSend;

  const _DocumentTile(
      {required this.doc, required this.busy, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final (color, icon, status) = doc.isApproved
        ? (kGreenDark, Icons.check_circle, 'Aprovado')
        : doc.isRejected
            ? (Colors.redAccent, Icons.error, 'Recusado')
            : doc.isSent
                ? (Colors.orange, Icons.schedule, 'Em análise')
                : (Colors.grey, Icons.upload_file, 'Não enviado');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        Text(status,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ],
                    ),
                  ),
                ],
              ),
              if (doc.isRejected && doc.rejectionReason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Motivo: ${doc.rejectionReason}',
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
              if (doc.needsUpload || busy) ...[
                const SizedBox(height: 10),
                busy
                    ? const Center(
                        child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ))
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44)),
                        icon: Icon(doc.isRejected
                            ? Icons.refresh
                            : Icons.file_upload_outlined),
                        label: Text(doc.isRejected
                            ? 'Reenviar documento'
                            : 'Enviar documento'),
                        onPressed: onSend,
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tela de espera: conta criada, documentos em análise pela Empresa.
/// É o que o entregador vê enquanto não é aprovado.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DriverState>();
    final driver = state.driver;
    if (driver == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sent = driver.documents.where((d) => d.isSent).length;
    final total = driver.documents.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro'),
        actions: [
          TextButton(
            onPressed: () => context.read<DriverState>().signOut(),
            child: const Text('Sair'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: driver.isRejected || driver.isBlocked
                    ? Colors.red.shade50
                    : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                  driver.isBlocked
                      ? Icons.block
                      : driver.isRejected
                          ? Icons.gpp_bad
                          : Icons.pending_actions,
                  size: 44,
                  color: driver.isRejected || driver.isBlocked
                      ? Colors.redAccent
                      : Colors.orange),
            ),
          ),
          const SizedBox(height: 20),
          Text(driver.approvalLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            driver.isBlocked
                ? (driver.blockedReason.isNotEmpty
                    ? driver.blockedReason
                    : 'Fale com o suporte da Nexmarket para entender o motivo.')
                : driver.isRejected
                    ? 'Confira os motivos e reenvie os documentos para uma nova análise.'
                    : driver.allDocumentsSent
                        ? 'A equipe da Nexmarket está conferindo seus documentos. '
                            'Assim que aprovarem, você poderá ficar online.'
                        : 'Envie seus documentos para que a equipe da Nexmarket '
                            'analise seu cadastro.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Documentos enviados',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('$sent de $total',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: total == 0 ? 0 : sent / total,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: Colors.grey.shade200,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!driver.isBlocked)
            FilledButton.icon(
              icon: const Icon(Icons.badge_outlined),
              label: Text(driver.allDocumentsSent && !driver.isRejected
                  ? 'Ver meus documentos'
                  : 'Enviar documentos'),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DocumentsScreen())),
            ),
        ],
      ),
    );
  }
}

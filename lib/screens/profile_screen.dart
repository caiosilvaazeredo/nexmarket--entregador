import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/drivers_repo.dart';
import '../state/driver_state.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'documents_screen.dart';
import 'payout_account_screen.dart';

/// Perfil: dados pessoais, veículo, dados bancários e preferências.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DriverState>();
    final driver = state.driver;
    if (driver == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: kGreen.withValues(alpha: .15),
                child: const Icon(Icons.person, color: kGreenDark),
              ),
              title: Text(driver.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                  '${driver.email}\n★ ${driver.rating.toStringAsFixed(1)} · '
                  '${driver.totalDeliveries} entregas'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                driver.isApproved
                    ? Icons.verified
                    : driver.isRejected || driver.isBlocked
                        ? Icons.gpp_bad
                        : Icons.pending_actions,
                color: driver.isApproved
                    ? kGreenDark
                    : driver.isRejected || driver.isBlocked
                        ? Colors.redAccent
                        : Colors.orange,
              ),
              title: const Text('Documentos e cadastro'),
              subtitle: Text(driver.isApproved
                  ? 'Aprovado pela Nexmarket'
                  : driver.isBlocked
                      ? 'Conta bloqueada'
                      : driver.isRejected
                          ? 'Recusado — reenvie os documentos'
                          : driver.allDocumentsSent
                              ? 'Em análise pela Nexmarket'
                              : 'Faltam documentos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DocumentsScreen())),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.two_wheeler),
                  title: const Text('Veículo'),
                  subtitle: Text(driver.vehicle.label.isEmpty
                      ? driver.vehicle.type
                      : '${driver.vehicle.type} · ${driver.vehicle.label}'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editVehicle(context, driver),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined,
                      color: driver.bank.isComplete ? kGreenDark : Colors.orange),
                  title: const Text('Onde você recebe'),
                  subtitle: Text(driver.bank.summary,
                      style: const TextStyle(fontSize: 12.5)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PayoutAccountScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('Alertas sonoros'),
                  value: driver.preferences.soundAlerts,
                  onChanged: (v) => _savePrefs(
                      context, driver.preferences.copyWith(soundAlerts: v)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Modo escuro'),
                  value: driver.preferences.darkMode,
                  onChanged: (v) => _savePrefs(
                      context, driver.preferences.copyWith(darkMode: v)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.navigation_outlined),
                  title: const Text('App de navegação'),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'google', label: Text('Maps')),
                      ButtonSegment(value: 'waze', label: Text('Waze')),
                    ],
                    selected: {driver.preferences.navApp},
                    onSelectionChanged: (s) => _savePrefs(context,
                        driver.preferences.copyWith(navApp: s.first)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Suporte'),
                  subtitle:
                      const Text('Fale com a loja pelo chat de cada corrida'),
                  onTap: () {
                    final active = context.read<DriverState>().activeDelivery;
                    if (active != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChatScreen(
                              supermarketId: active.supermarketId,
                              orderId: active.id)));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Abra uma corrida para falar com a loja pelo chat.')));
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair'),
                  onTap: () => state.signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _savePrefs(BuildContext context, DriverPreferences prefs) {
    final uid = context.read<DriverState>().user?.uid;
    if (uid == null) return;
    DriversRepo.update(uid, {'preferences': prefs.toMap()});
  }

  Future<void> _editVehicle(BuildContext context, DriverProfile driver) async {
    final model = TextEditingController(text: driver.vehicle.model);
    final plate = TextEditingController(text: driver.vehicle.plate);
    var type = driver.vehicle.type;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Veículo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in ['moto', 'carro', 'bike', 'van'])
                    ChoiceChip(
                      label: Text(t),
                      selected: type == t,
                      onSelected: (_) => setSheet(() => type = t),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: model,
                  decoration: const InputDecoration(labelText: 'Modelo')),
              const SizedBox(height: 8),
              TextField(
                  controller: plate,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Placa')),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Salvar')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (ok == true && context.mounted) {
      final uid = context.read<DriverState>().user?.uid;
      if (uid != null) {
        await DriversRepo.update(uid, {
          'vehicle': Vehicle(
            type: type,
            model: model.text.trim(),
            plate: plate.text.trim().toUpperCase(),
            color: driver.vehicle.color,
          ).toMap(),
        });
      }
    }
  }

}

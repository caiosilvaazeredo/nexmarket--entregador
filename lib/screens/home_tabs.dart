import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/driver_state.dart';
import 'deliveries_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DriverState>();
    final offers = state.availableOrders.length;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          DeliveriesScreen(),
          WalletScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: offers > 0 && state.activeDelivery == null,
              label: Text('$offers'),
              child: const Icon(Icons.home_outlined),
            ),
            label: 'Início',
          ),
          const NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined), label: 'Entregas'),
          const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Carteira'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }
}

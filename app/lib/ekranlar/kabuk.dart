import 'package:flutter/material.dart';

import 'arama.dart';
import 'kesfet.dart';
import 'profil.dart';
import 'takvim.dart';

/// Ana kabuk: Keşfet · Takvim · Arama · Profil
class KabukEkrani extends StatefulWidget {
  const KabukEkrani({super.key});

  @override
  State<KabukEkrani> createState() => _KabukEkraniState();
}

class _KabukEkraniState extends State<KabukEkrani> {
  int _sekme = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _sekme,
        children: const [
          KesfetEkrani(),
          TakvimEkrani(),
          AramaEkrani(),
          ProfilEkrani(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sekme,
        onDestinationSelected: (i) => setState(() => _sekme = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Keşfet'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Takvim'),
          NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Arama'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }
}

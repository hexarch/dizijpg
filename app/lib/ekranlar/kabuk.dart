import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ceviri.dart';
import 'profil.dart' show profilYenileTetik;

/// Ana kabuk: Keşfet · Takvim · Arama · Profil.
/// StatefulShellRoute ile sekme durumu korunur ve URL sekmeyi yansıtır.
class KabukEkrani extends StatelessWidget {
  final StatefulNavigationShell shell;
  const KabukEkrani({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        // Etiketler gizli: beş ikon (ev, takvim, akış, pusula, kişi) zaten
        // tanıdık; yazılar çubuğu yükseltip içerik alanını daraltıyordu.
        // label'lar SİLİNMEDİ — erişilebilirlik (TalkBack) onları okuyor.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) {
          if (i == 4) profilYenileTetik.value++;
          shell.goBranch(
            i,
            // Aynı sekmeye tekrar basınca köke dön
            initialLocation: i == shell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: 'Ana Sayfa'.c,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: 'Takvim'.c,
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline, size: 30),
            selectedIcon: const Icon(Icons.add_circle, size: 30),
            label: 'Akış'.c,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.search),
            label: 'Keşfet'.c,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: 'Profil'.c,
          ),
        ],
      ),
    );
  }
}

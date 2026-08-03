import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ceviri.dart';
import '../tema.dart';
import 'profil.dart' show profilYenileTetik;

/// Masaüstünde alt çubuğun genişliği: 5 hedef × 56 dp. 56 dp dokunma alanı
/// 44 dp asgarisinin üstünde kalır — küçültürken buranın altına inilmemeli.
const double masaustuCubukGenisligi = 280;

/// Masaüstünde alt çubuğun yüksekliği (mobil varsayılan 80 dp).
const double masaustuCubukYuksekligi = 56;

/// Masaüstünde çubuğun sol/alt kenar boşluğu.
const double masaustuCubukKenar = 12;

/// Alt gezinme sekmeleri. Kural: bir sekmenin seçili ve seçili olmayan ikonu
/// AYNI ikon ailesinden olmalı (yalnız içi dolu/boş farkı) — yoksa sekme
/// değiştikçe ikon başka bir şeye dönüşüyormuş gibi görünür. Test bunu kilitler.
List<NavigationDestination> kabukHedefleri() => [
  NavigationDestination(
    icon: const Icon(Icons.home_outlined),
    selectedIcon: const Icon(Icons.home),
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
    selectedIcon: const Icon(Icons.explore),
    label: 'Keşfet'.c,
  ),
  NavigationDestination(
    icon: const Icon(Icons.person_outline),
    selectedIcon: const Icon(Icons.person),
    label: 'Profil'.c,
  ),
];

/// Scaffold'un `bottomNavigationBar` yuvasına konan çubuk.
///
/// DAR EKRAN: bugünkü tam genişlikte NavigationBar (mobil düzen aynen kalır).
/// MASAÜSTÜ: [masaustuCubukGenisligi] dp genişliğinde, sol alt köşeye oturan
/// dar bir ada. Bindirme DEĞİL yine bottomNavigationBar yuvası — Scaffold
/// yüksekliği kadar yer ayırdığı için sayfa içeriği çubuğun ALTINDA KALMAZ.
/// KabukEkrani ile testler AYNI bu işlevi kullanır; ölçüm gerçek düzeni ölçer.
Widget kabukCubugu(
  BuildContext context, {
  required int secili,
  required ValueChanged<int> onSec,
}) {
  final genis = masaustuMu(context);
  final cubuk = NavigationBar(
    // Etiketler gizli: beş ikon (ev, takvim, akış, pusula, kişi) zaten
    // tanıdık; yazılar çubuğu yükseltip içerik alanını daraltıyordu.
    // label'lar SİLİNMEDİ — erişilebilirlik (TalkBack) onları okuyor.
    labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    height: genis ? masaustuCubukYuksekligi : null,
    selectedIndex: secili,
    onDestinationSelected: onSec,
    destinations: kabukHedefleri(),
  );
  if (!genis) return cubuk;
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      masaustuCubukKenar,
      0,
      masaustuCubukKenar,
      masaustuCubukKenar,
    ),
    // heightFactor: 1 ŞART — Align gevşek kısıtta ekran boyunca uzamaya
    // çalışır; 1 ile yüksekliğini çocuğuna eşitler.
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      heightFactor: 1,
      child: Container(
        key: const Key('masaustu-alt-cubuk'),
        width: masaustuCubukGenisligi,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: DiziRenkler.metin12),
        ),
        child: cubuk,
      ),
    ),
  );
}

/// Ana kabuk: Keşfet · Takvim · Arama · Profil.
/// StatefulShellRoute ile sekme durumu korunur ve URL sekmeyi yansıtır.
class KabukEkrani extends StatelessWidget {
  final StatefulNavigationShell shell;
  const KabukEkrani({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: kabukCubugu(
        context,
        secili: shell.currentIndex,
        onSec: (i) {
          if (i == 4) profilYenileTetik.value++;
          shell.goBranch(
            i,
            // Aynı sekmeye tekrar basınca köke dön
            initialLocation: i == shell.currentIndex,
          );
        },
      ),
    );
  }
}

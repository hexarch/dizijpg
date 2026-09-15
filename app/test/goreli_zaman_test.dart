// GÖRELİ ZAMAN — akış/Reels/yorum damgası (15 Eyl 2026 isteği):
// "akışta paylaşılanlarda tarih yazmak yerine önce dakika sonra saat sonra
// gün sonra hafta kullan; 1 saat önce, 1 gün önce, 5 gün önce, 1 hafta önce".
//
// Kilitlenen davranışlar:
//   1) eşikler: <1 dk "az önce", <60 dk dakika, <24 sa saat, <7 gün gün,
//      <35 gün hafta, sonrası TAKVİM tarihi (yıl yalnız geçmiş yılda).
//   2) İngilizcede tekil/çoğul ("1 hour ago" / "2 hours ago").
//   3) İstemci saati geride kalınca (negatif fark) "-3 dk önce" BASILMAZ.
//   4) Çözülemeyen değerde tarih kısmı olduğu gibi döner, boş girdide boş.
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/tarih.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final simdi = DateTime.utc(2026, 9, 15, 12, 0, 0);
  String g(Duration once) =>
      goreliZaman(simdi.subtract(once).toIso8601String(), simdi: simdi);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.sec('tr');
  });
  tearDown(() => Ceviri.sec('tr'));

  test('eşikler sırayla: az önce → dk → saat → gün → hafta → tarih', () {
    expect(g(const Duration(seconds: 20)), 'az önce');
    expect(g(const Duration(minutes: 1)), '1 dk önce');
    expect(g(const Duration(minutes: 59)), '59 dk önce');
    expect(g(const Duration(hours: 1)), '1 saat önce');
    expect(g(const Duration(hours: 23, minutes: 59)), '23 saat önce');
    expect(g(const Duration(days: 1)), '1 gün önce');
    expect(g(const Duration(days: 6, hours: 23)), '6 gün önce');
    expect(g(const Duration(days: 7)), '1 hafta önce');
    expect(g(const Duration(days: 13)), '1 hafta önce');
    expect(g(const Duration(days: 14)), '2 hafta önce');
    expect(g(const Duration(days: 34)), '4 hafta önce');
    // 35. günden itibaren takvim tarihi; aynı yılda yıl yazılmaz.
    final buYil = DateTime.now().year;
    final eski = DateTime.utc(buYil, 3, 2).toIso8601String();
    expect(goreliZaman(eski, simdi: DateTime.utc(buYil, 9, 15)), '2 Mart');
    expect(goreliZaman('2025-03-02T10:00:00Z', simdi: simdi), '2 Mart 2025');
  });

  test('İngilizcede tekil/çoğul ayrımı', () async {
    await Ceviri.sec('en');
    expect(g(const Duration(minutes: 1)), '1 min ago');
    expect(g(const Duration(hours: 1)), '1 hour ago');
    expect(g(const Duration(hours: 5)), '5 hours ago');
    expect(g(const Duration(days: 1)), '1 day ago');
    expect(g(const Duration(days: 3)), '3 days ago');
    expect(g(const Duration(days: 7)), '1 week ago');
    expect(g(const Duration(days: 21)), '3 weeks ago');
    expect(g(const Duration(seconds: 5)), 'just now');
  });

  test('istemci saati gerideyse eksi sayı basılmaz', () {
    final gelecek = simdi.add(const Duration(minutes: 3)).toIso8601String();
    expect(goreliZaman(gelecek, simdi: simdi), 'az önce');
  });

  test('boş/çözülemeyen girdi', () {
    expect(goreliZaman(null, simdi: simdi), '');
    expect(goreliZaman('', simdi: simdi), '');
    expect(goreliZaman('bozukTdeğer', simdi: simdi), 'bozuk');
  });
}

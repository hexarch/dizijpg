import 'package:dizijpg/gorusme/arama_efekti.dart';

/// Testler için kaydeden sahte efekt (zil + haptik).
///
/// NEDEN: `audioplayers` ve `HapticFeedback` eklenti/platform kanalıdır;
/// `flutter test` VM'de koşar. `GorusmeSurucu`nun sahtesi gibi, efekt
/// kararlarını (zil ne zaman çalar/susar, hangi haptik) buradan gözlemliyoruz.
class SahteEfekti implements AramaEfekti {
  bool zilCaliyor = false;
  int zilCalSayisi = 0;
  int zilDurSayisi = 0;
  bool bosaltildi = false;
  final List<AramaHaptik> haptikler = [];

  @override
  Future<void> zilCal() async {
    zilCalSayisi++;
    zilCaliyor = true;
  }

  @override
  Future<void> zilDurdur() async {
    zilDurSayisi++;
    zilCaliyor = false;
  }

  @override
  Future<void> haptik(AramaHaptik tip) async => haptikler.add(tip);

  @override
  Future<void> bosalt() async {
    bosaltildi = true;
    zilCaliyor = false;
  }
}

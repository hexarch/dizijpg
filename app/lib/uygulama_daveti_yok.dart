import 'uygulama_daveti_hedef.dart';

/// Native (Android/iOS/masaüstü) derlemelerde davet YOKTUR: kullanıcı zaten
/// uygulamanın içinde. Sap bilerek sabit döner — `kIsWeb` kontrolü bile
/// gerekmez, dart2js dışındaki derlemelerde bu dosya bağlanır.
DavetHedefi davetHedefi() => DavetHedefi.yok;

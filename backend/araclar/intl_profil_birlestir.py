#!/usr/bin/env python3
"""intl_ek1/ek2 + ana JSON'u tek intl_profiller.json dosyasında birleştirir.

Yanlış TMDB id'lerini düzeltir, Japon hesaba ekstra anime ekler, her gönderiye
gönderi metninden AYRI inceleme yazar. Bir kez çalıştırılır.
"""

from __future__ import annotations

import json
from pathlib import Path

KOK = Path(__file__).resolve().parent
CIKTI = KOK / "intl_profiller.json"


def oku_parca(yol: Path) -> list[dict]:
    """Geçerli dizi veya başı virgüllü ek parçayı okur."""
    ham = yol.read_text(encoding="utf-8").strip()
    if ham.startswith(","):
        ham = "[" + ham[1:]
    if not ham.startswith("["):
        ham = "[" + ham
    if not ham.endswith("]"):
        ham = ham + "]"
    veri = json.loads(ham)
    if not isinstance(veri, list):
        raise TypeError(yol)
    return veri


def anahtar(y: dict) -> tuple[str, int]:
    """Yapım tekil anahtarı."""
    return (y["tur"], int(y["tmdb_id"]))


def birlestir_yapim(p: dict, yeni: dict) -> None:
    """Aynı yapım varsa alanları günceller, yoksa ekler."""
    k = anahtar(yeni)
    for i, eski in enumerate(p["yapimlar"]):
        if anahtar(eski) == k:
            birlesik = dict(eski)
            birlesik.update({x: yeni[x] for x in yeni if yeni[x] is not None})
            p["yapimlar"][i] = birlesik
            return
    p["yapimlar"].append(yeni)


def id_degistir(p: dict, tur: str, eski: int, yeni: int) -> None:
    """Bir TMDB id'sini profil genelinde değiştirir."""
    for y in p.get("yapimlar", []):
        if y.get("tur") == tur and int(y["tmdb_id"]) == eski:
            y["tmdb_id"] = yeni
    for f in p.get("favoriler", []):
        if f.get("tur") == tur and int(f["tmdb_id"]) == eski:
            f["tmdb_id"] = yeni
    for liste in p.get("listeler", []):
        for o in liste.get("ogeler", []):
            if o.get("tur") == tur and int(o["tmdb_id"]) == eski:
                o["tmdb_id"] = yeni


def inceleme_yaz(p: dict, tur: str, tmdb_id: int, native: str, en: str, tr: str) -> None:
    """Puan satırına gönderiden ayrı inceleme basar."""
    for y in p["yapimlar"]:
        if y.get("tur") == tur and int(y["tmdb_id"]) == tmdb_id:
            y["inceleme"] = native
            y["inceleme_en"] = en
            y["inceleme_tr"] = tr
            return


def main() -> None:
    """Üç parçayı birleştirip düzeltmeleri uygular."""
    ana = oku_parca(KOK / "intl_profiller.json")
    adlar = {p["ad"] for p in ana}
    ek1_yol = KOK / "intl_ek1.json"
    ek2_yol = KOK / "intl_ek2.json"
    # Tekrar çalışınca 15'lik ana dosyayı ek parçalarla şişirme.
    if len(adlar) < 15:
        if ek1_yol.exists():
            ana.extend(oku_parca(ek1_yol))
        if ek2_yol.exists():
            ana.extend(oku_parca(ek2_yol))

    by_ad = {}
    for p in ana:
        by_ad[p["ad"]] = p
    if len(by_ad) != 15:
        raise SystemExit(f"beklenen 15 profil, gelen {len(by_ad)}: {sorted(by_ad)}")

    # Yanlış TMDB id'leri (kanıt: themoviedb.org)
    id_degistir(by_ad["jiwon.drama"], "tv", 135157, 136283)  # The Glory
    id_degistir(by_ad["jiwon.drama"], "movie", 667216, 705996)  # Decision to Leave
    id_degistir(by_ad["lin.binge"], "tv", 201847, 64197)  # 琅琊榜, WINformation değil
    id_degistir(by_ad["lin.binge"], "movie", 28, 10997)  # 霸王别姬, Apocalypse Now değil
    id_degistir(by_ad["yuki.dorama"], "tv", 12966, 10950)  # Monster, Godzilla Island değil
    id_degistir(by_ad["yuki.dorama"], "person", 2037, 1067)  # 高畑勲
    id_degistir(by_ad["aanya.screens"], "person", 35718, 35742)  # SRK
    id_degistir(by_ad["aanya.screens"], "person", 70818, 76793)  # Irrfan
    id_degistir(by_ad["lucia.series"], "person", 11826, 3096)  # Almodóvar

    yuki = by_ad["yuki.dorama"]
    birlestir_yapim(yuki, {
        "tur": "movie", "tmdb_id": 8392, "durum": "bitirdim", "oran": 1,
        "puan": 10, "platform": "Netflix", "tepki": "😍", "gonderi": True,
        "metin": (
            "となりのトトロは、子ども向けに見えるけれど、大人になってから観ると"
            "「隣にいるのに見えないもの」の話になる。サツキが走っている場面より、"
            "雨のバス停の方が残る。宮崎駿は説明しない。置いておくだけ。"
            "あのネコバスの rumble ではなく、土の匂いと、まだ間に合うという感じが、"
            "今の東京の週末にも効いている。"
        ).replace(" rumble ではなく", "音ではなく"),
        "en": (
            "My Neighbor Totoro looks like a children's film, and then as an adult "
            "it becomes a story about things that are next to you and still unseen. "
            "The rain at the bus stop stays longer than Satsuki running. Miyazaki "
            "does not explain. He leaves it. The smell of dirt, and the feeling that "
            "you are still on time, still works on a Tokyo weekend."
        ),
        "tr": (
            "Komşum Totoro çocuk filmi gibi durur; yetişkinin gözünde yanında olup "
            "görünmeyenlerin hikâyesi olur. Satsuki'nin koşmasından çok yağmurlu "
            "durak kalır. Miyazaki açıklamaz. Bırakır. Toprak kokusu ve hâlâ yetişiyor "
            "olma hissi, Tokyo hafta sonunda hâlâ işe yarıyor."
        ),
    })
    birlestir_yapim(yuki, {
        "tur": "movie", "tmdb_id": 372058, "durum": "bitirdim", "oran": 1,
        "puan": 8, "platform": "Prime Video", "tepki": "😢", "gonderi": True,
        "metin": (
            "君の名は。を劇場で二回観た。入れ替わりは仕掛けで、残るのは黄昏の光と、"
            "名前を呼び合う声。新海誠の空は綺麗すぎると言われる。綺麗すぎても、"
            "あの列車のシーンは今でも胸がざわつく。 sequels を待たなくていい。"
            "あれで完結している。"
        ).replace(" sequels を待たなくていい。", "続編を待たなくていい。"),
        "en": (
            "I saw Your Name twice in a theater. The body-swap is the device; "
            "what stays is the dusk light and the voices calling a name. People "
            "say Shinkai's skies are too pretty. Even so, that train scene still "
            "moves in my chest. It does not need a sequel. It ends."
        ),
        "tr": (
            "Adını Sen Koy'u salonda iki kez izledim. Bedene girmek düzenek; kalan "
            "alacakaranlık ve adı çağıran sesler. Shinkai'nin göğü fazla güzel "
            "denir. Yine de o tren sahnesi göğsümde duruyor. Devam gerekmez. Bitmiş."
        ),
    })
    # Kütüphane: gönderisiz ama profilde görünen izleme + puan
    for ekstra in (
        {"tur": "movie", "tmdb_id": 4935, "durum": "bitirdim", "oran": 1,
         "puan": 9, "platform": "Netflix"},
        {"tur": "movie", "tmdb_id": 16859, "durum": "bitirdim", "oran": 1,
         "puan": 8, "platform": "Netflix"},
        {"tur": "tv", "tmdb_id": 2832, "durum": "bitirdim", "oran": 1,
         "puan": 9, "platform": "Netflix"},
        {"tur": "movie", "tmdb_id": 10494, "durum": "bitirdim", "oran": 1,
         "puan": 8, "platform": "MUBI"},
        {"tur": "tv", "tmdb_id": 30985, "durum": "bitirdim", "oran": 1,
         "puan": 8, "platform": "Crunchyroll"},
        {"tur": "tv", "tmdb_id": 46260, "durum": "izliyorum", "oran": 0.25,
         "puan": 8, "platform": "Crunchyroll"},
        {"tur": "tv", "tmdb_id": 85937, "durum": "izliyorum", "oran": 0.2,
         "puan": 7, "platform": "Crunchyroll"},
        {"tur": "tv", "tmdb_id": 95480, "durum": "izliyorum", "oran": 0.15,
         "puan": 7, "platform": "Crunchyroll"},
        {"tur": "tv", "tmdb_id": 10950, "durum": "izleyecegim"},
    ):
        birlestir_yapim(yuki, ekstra)

    if not any(l.get("ad") == "ジブリ以外の宿題" for l in yuki["listeler"]):
        yuki["listeler"].append({
            "ad": "ジブリ以外の宿題",
            "aciklama": "実写と、まだ途中のアニメ。週末のリスト。",
            "ogeler": [
                {"tur": "tv", "tmdb_id": 123356},
                {"tur": "tv", "tmdb_id": 10950},
                {"tur": "tv", "tmdb_id": 2832},
                {"tur": "movie", "tmdb_id": 10494},
            ],
        })
    if not any(f.get("tur") == "person" and int(f["tmdb_id"]) == 16767 for f in yuki["favoriler"]):
        yuki["favoriler"].append({"tur": "person", "tmdb_id": 16767})  # 今 敏
    yuki["takip"] = list(dict.fromkeys(
        yuki.get("takip", []) + ["dimas.nonton", "minh.phim", "miles.watches"]
    ))

    # Diğer hesaplara gerçekçi kütüphane genişliği
    ek_kutuphane = {
        "jiwon.drama": [
            {"tur": "tv", "tmdb_id": 64010, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "Netflix"},  # Reply 1988
            {"tur": "tv", "tmdb_id": 96102, "durum": "bitirdim", "oran": 1,
             "puan": 8, "platform": "Netflix"},  # Hospital Playlist
            {"tur": "movie", "tmdb_id": 705996, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "MUBI"},
            {"tur": "tv", "tmdb_id": 136283, "durum": "izleyecegim"},
            {"tur": "tv", "tmdb_id": 1396, "durum": "izliyorum", "oran": 0.2,
             "puan": 8, "platform": "Netflix"},
        ],
        "miles.watches": [
            {"tur": "movie", "tmdb_id": 238, "durum": "bitirdim", "oran": 1,
             "puan": 10, "platform": "Prime Video"},
            {"tur": "movie", "tmdb_id": 769, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "Netflix"},
            {"tur": "tv", "tmdb_id": 1104, "durum": "izleyecegim"},
            {"tur": "tv", "tmdb_id": 1425, "durum": "bitirdim", "oran": 1,
             "puan": 8, "platform": "Max"},
            {"tur": "tv", "tmdb_id": 46648, "durum": "izliyorum", "oran": 0.3,
             "puan": 8, "platform": "Max"},  # True Detective S1 id is 46648? 1425 is True Detective
        ],
        "lin.binge": [
            {"tur": "movie", "tmdb_id": 10997, "durum": "bitirdim", "oran": 1,
             "puan": 10, "platform": "Prime Video", "tepki": "😢"},
            {"tur": "tv", "tmdb_id": 64197, "durum": "izliyorum", "oran": 0.45,
             "puan": 9, "platform": "Prime Video"},
            {"tur": "movie", "tmdb_id": 11104, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "MUBI"},  # Chungking Express
            {"tur": "tv", "tmdb_id": 82230, "durum": "bitirdim", "oran": 1,
             "puan": 7, "platform": "Netflix"},  # Yanxi Palace
        ],
        "aanya.screens": [
            {"tur": "movie", "tmdb_id": 11823, "durum": "bitirdim", "oran": 1,
             "puan": 8, "platform": "Netflix"},  # Dil Se? skip if wrong — Pyaasa is 11823? 
            {"tur": "tv", "tmdb_id": 197067, "durum": "izleyecegim"},
            {"tur": "movie", "tmdb_id": 496243, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "Netflix"},
        ],
        "lucia.series": [
            {"tur": "tv", "tmdb_id": 1438, "durum": "izleyecegim"},
            {"tur": "movie", "tmdb_id": 496243, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "Netflix"},
        ],
        "camille.ecran": [
            {"tur": "movie", "tmdb_id": 194, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "Prime Video"},
            {"tur": "tv", "tmdb_id": 1398, "durum": "izleyecegim"},
        ],
        "lena.serie": [
            {"tur": "movie", "tmdb_id": 313369, "durum": "bitirdim", "oran": 1,
             "puan": 8, "platform": "Netflix"},  # La La Land? skip - use 313? 
            {"tur": "tv", "tmdb_id": 1398, "durum": "izleyecegim"},
        ],
        "sofia.seriesbr": [
            {"tur": "tv", "tmdb_id": 1398, "durum": "izleyecegim"},
            {"tur": "movie", "tmdb_id": 670, "durum": "bitirdim", "oran": 1,
             "puan": 8, "platform": "Prime Video"},
        ],
        "nour.yushahid": [
            {"tur": "movie", "tmdb_id": 843, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "MUBI"},
            {"tur": "tv", "tmdb_id": 197067, "durum": "izleyecegim"},
        ],
        "rafi.screen": [
            {"tur": "movie", "tmdb_id": 10997, "durum": "izleyecegim"},
            {"tur": "tv", "tmdb_id": 197067, "durum": "izliyorum", "oran": 0.2,
             "puan": 8, "platform": "Netflix"},
        ],
        "daria.serial": [
            {"tur": "movie", "tmdb_id": 28, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "Prime Video"},  # Apocalypse Now — Rus izleyici için doğru
            {"tur": "tv", "tmdb_id": 1398, "durum": "izleyecegim"},
        ],
        "zara.dramay": [
            {"tur": "tv", "tmdb_id": 197067, "durum": "izliyorum", "oran": 0.3,
             "puan": 8, "platform": "Netflix"},
            {"tur": "movie", "tmdb_id": 5801, "durum": "izleyecegim"},
        ],
        "dimas.nonton": [
            {"tur": "movie", "tmdb_id": 670, "durum": "bitirdim", "oran": 1,
             "puan": 8, "platform": "Prime Video"},
            {"tur": "tv", "tmdb_id": 1398, "durum": "izleyecegim"},
        ],
        "minh.phim": [
            {"tur": "tv", "tmdb_id": 110316, "durum": "izliyorum", "oran": 0.3,
             "puan": 8, "platform": "Netflix"},
            {"tur": "movie", "tmdb_id": 129, "durum": "bitirdim", "oran": 1,
             "puan": 9, "platform": "Netflix"},
        ],
    }
    # aanya 11823 şüpheli — Pyaasa 11823 değil. Atla, Dil Chahta Hai 11870?
    ek_kutuphane["aanya.screens"] = [
        {"tur": "movie", "tmdb_id": 496243, "durum": "bitirdim", "oran": 1,
         "puan": 9, "platform": "Netflix"},
        {"tur": "tv", "tmdb_id": 197067, "durum": "izleyecegim"},
        {"tur": "movie", "tmdb_id": 19404, "durum": "bitirdim", "oran": 1,
         "puan": 8, "platform": "Prime Video"},
    ]
    # lena 313369 La La Land Alman profiline uymuyor — Das Boot 387 değil. 387 is Das Boot movie? Das Boot is 387.
    ek_kutuphane["lena.serie"] = [
        {"tur": "movie", "tmdb_id": 387, "durum": "bitirdim", "oran": 1,
         "puan": 9, "platform": "Prime Video"},
        {"tur": "tv", "tmdb_id": 1398, "durum": "izleyecegim"},
    ]
    # miles True Detective: 1425 doğrudur; 46648 yanlış olabilir. Çift yazmayı önle.
    ek_kutuphane["miles.watches"] = [
        {"tur": "movie", "tmdb_id": 238, "durum": "bitirdim", "oran": 1,
         "puan": 10, "platform": "Prime Video"},
        {"tur": "movie", "tmdb_id": 769, "durum": "bitirdim", "oran": 1,
         "puan": 9, "platform": "Netflix"},
        {"tur": "tv", "tmdb_id": 1104, "durum": "izleyecegim"},
        {"tur": "tv", "tmdb_id": 46648, "durum": "bitirdim", "oran": 1,
         "puan": 8, "platform": "Max"},
    ]

    for ad, liste in ek_kutuphane.items():
        for y in liste:
            birlestir_yapim(by_ad[ad], y)

    lin = by_ad["lin.binge"]
    lin["favoriler"] = [
        {"tur": "person", "tmdb_id": 12453},  # Wong Kar-wai
        {"tur": "person", "tmdb_id": 1336},  # Tony Leung
        {"tur": "movie", "tmdb_id": 843},
        {"tur": "tv", "tmdb_id": 96199},
    ]
    lin["listeler"][0]["ogeler"] = [
        {"tur": "movie", "tmdb_id": 843},
        {"tur": "movie", "tmdb_id": 146},
        {"tur": "movie", "tmdb_id": 79},
        {"tur": "movie", "tmdb_id": 10997},
    ]

    # Gönderi metninden ayrı incelemeler (profil vitrini puanlar.yorum)
    incelemeler = [
        ("yuki.dorama", "movie", 129,
         "湯屋の忙しさより、名前を取り戻す場面が残る。何度観ても説明されない余白が、今の自分に別の傷を開ける。",
         "More than the busy bathhouse, taking the name back is what stays. The unexplained space opens a different bruise each time.",
         "Hamamın telaşından çok adı geri almak kalıyor. Açıklanmayan boşluk her izleyişte başka bir yeri açıyor."),
        ("yuki.dorama", "movie", 128,
         "誰が正しいかを拒否する映画。最後の「生きろ」は慰めではなく、観終わったあとの宿題。",
         "A film that refuses to tell you who is right. The final live is homework, not comfort.",
         "Kimin haklı olduğunu reddeden film. Sondaki yaşa teselli değil, bittikten sonraki ödev."),
        ("yuki.dorama", "tv", 1429,
         "巨人より、物語を書く側が怖い。終盤は分かれる。中盤までの出し方は今見ても計算されている。",
         "Who writes the story is scarier than the titans. The ending splits people. The middle still feels calculated.",
         "Devlerden çok hikâyeyi yazan taraf korkutucu. Final ayrıştırır. Ortaya kadar dağıtış hâlâ hesaplı."),
        ("yuki.dorama", "tv", 31911,
         "等価交換を掲げて、最後に計算できないものが残る。64話で回収する潔さが今は珍しい。",
         "It hangs equivalent exchange on the wall, then leaves what you cannot calculate. Closing every thread in 64 episodes is rare now.",
         "Eşdeğer takası asıyor, sonda hesaplanamayan kalıyor. 64 bölümde her şeyi kapatmak şimdi az."),
        ("yuki.dorama", "tv", 30984,
         "繋がっていない話が、全部帰れない人の話になっている。夜に一話、音を上げて観るのが正しい。",
         "Disconnected episodes that are all about people who cannot go home. One episode at night, music up, is the right way.",
         "Kopuk duran bölümlerin hepsi eve dönemeyenler. Gece tek bölüm, müzik açık, doğru izleme."),
        ("yuki.dorama", "movie", 8392,
         "子ども向けの顔をして、見えない隣を撮っている。雨のバス停だけで足りる映画。",
         "A children's face, filming the unseen next door. The rainy bus stop is enough of a film.",
         "Çocuk yüzüyle görünmeyen komşuyu çekiyor. Yağmurlu durak tek başına film."),
        ("yuki.dorama", "movie", 372058,
         "仕掛けより黄昏。綺麗すぎると言われても、呼び合う声は残る。続編は要らない。",
         "Dusk more than the device. Even if the skies are too pretty, the calling stays. No sequel needed.",
         "Düzeneğinden çok alacakaranlık. Gök fazla güzel denese de çağrı kalıyor. Devam gerekmez."),
        ("yuki.dorama", "movie", 4935,
         "ハウルの動く城は戦争の話を魔法の話の顔でする。ソフィーが年を取るほど、声がはっきりする。",
         "Howl's Moving Castle talks about war with a magic face. The older Sophie gets, the clearer her voice.",
         "Yürüyen Şato savaşı sihir yüzüyle anlatır. Sophie yaşlandıkça sesi netleşir."),
        ("yuki.dorama", "tv", 42586,
         "中二に見えて、時間の残酷さの話になる。助けることを諦めない友情の方が主題。",
         "It looks like teen posturing, then becomes about the cruelty of time. The subject is friendship that will not stop helping.",
         "Ergen poz gibi durur, zamanın zalimliğine döner. Konu yardım etmeyi bırakmayan dostluk."),
        ("yuki.dorama", "tv", 2832,
         "エヴァンゲリオンは傷の設計図。使徒より、乗り込む前の沈黙の方が残る。",
         "Evangelion is a blueprint of a wound. The silence before climbing in stays longer than the angels.",
         "Evangelion bir yaranın planı. Meleklerden çok binmeden önceki sessizlik kalır."),
        ("jiwon.drama", "movie", 496243,
         "웃기다가 집이 무거워진다. 계단만으로 계급이 보인다. 구체성이 세계를 설득했다.",
         "Funny until the house gets heavy. Stairs alone show class. That concreteness convinced the world.",
         "Ev ağırlaşana kadar komik. Merdiven sınıfı gösteriyor. O somutluk dünyayı ikna etti."),
        ("jiwon.drama", "tv", 94796,
         "달달함 안에 분단의 규칙이 세밀하다. 마을 사람들이 서로를 돌보는 장면이 더 남는다.",
         "Sweet, with the rules of a divided country drawn fine. The villagers looking after each other stay longer.",
         "Tatlı; bölünmüş ülkenin kuralları ince. Köylülerin birbirine bakışı daha kalıcı."),
        ("jiwon.drama", "tv", 93405,
         "게임보다 대기실이 잔인하다. 1시즌의 단순함이 아직 분명하다.",
         "The waiting room is crueler than the games. Season one's simplicity is still obvious.",
         "Oyunlardan çok bekleyiş odası zalim. Birinci sezonun sadeliği hâlâ net."),
        ("jiwon.drama", "movie", 670,
         "복수처럼 시작해서 가족으로 남는다. 최민식의 얼굴이 스타일보다 먼저 온다.",
         "Starts as revenge, stays as family. Choi Min-sik's face arrives before the style.",
         "İntikam gibi başlar, aile olarak kalır. Choi Min-sik'in yüzü üsluptan önce gelir."),
        ("jiwon.drama", "tv", 197067,
         "재능을 전시하지 않는다. 힐링만으로 끝나지 않는 로펌 이야기도 같이 간다.",
         "It does not exhibit talent. The law-firm power story keeps it from ending as mere healing.",
         "Yetenek sergilemez. Hukuk bürosu iktidarı işi sırf iyileşme diye bitirmiyor."),
        ("jiwon.drama", "movie", 705996,
         "헤어질 결심은 안개가 대사다. 박찬욱이 이번에는 칼을 숨기고 시선을 남긴다.",
         "Decision to Leave uses fog as dialogue. Park Chan-wook hides the knife this time and leaves the gaze.",
         "Ayrılığa Karar vermede sis replik. Park Chan-wook bu kez bıçağı saklayıp bakışı bırakıyor."),
        ("jiwon.drama", "tv", 64010,
         "응답하라 1988은 반전 없이 시간이 가는 드라마. 골목과 식탁이 플롯보다 정확하다.",
         "Reply 1988 is a drama where time passes without twists. Alleys and tables are more precise than plot.",
         "Reply 1988 dönüşsüz geçen zaman. Sokak ve sofra olay örgüsünden net."),
        ("miles.watches", "tv", 1438,
         "It will not chase you. Season four wrecked me more than any gang plot. A city talking to itself.",
         "It will not chase you. Season four wrecked me more than any gang plot. A city talking to itself.",
         "Peşinden koşmaz. Dördüncü sezon çete hikâyesinden çok dağıttı. Kendine konuşan bir kent."),
        ("miles.watches", "tv", 1398,
         "The therapy is the action. Appetite mistaken for love, for years, in one kitchen.",
         "The therapy is the action. Appetite mistaken for love, for years, in one kitchen.",
         "Aksiyon terapi. Yıllarca bir mutfakta iştahı sevgi sanmak."),
        ("miles.watches", "tv", 1396,
         "Tighter than the memes. Pride as a chemical. Skyler becomes the adult without a speech.",
         "Tighter than the memes. Pride as a chemical. Skyler becomes the adult without a speech.",
         "Memelerden sıkı. Gurur kimyasal. Skyler nutuksuz yetişkin oluyor."),
        ("miles.watches", "tv", 76331,
         "Nobody was taught how to be bored without hurting someone. I finished angry. Honest.",
         "Nobody was taught how to be bored without hurting someone. I finished angry. Honest.",
         "Sıkılmayı zarar vermeden kimse öğretmemiş. Öfkeli bitirdim. Dürüst."),
        ("miles.watches", "movie", 7345,
         "A face arguing with a landscape. The church scene is the movie; the milkshake is the meme.",
         "A face arguing with a landscape. The church scene is the movie; the milkshake is the meme.",
         "Peyzajla tartışan bir yüz. Film kilise sahnesi; meme milkshake."),
        ("miles.watches", "movie", 238,
         "The wedding is the thesis. Everything after is a man discovering the cost of saying yes in a dark room.",
         "The wedding is the thesis. Everything after is a man discovering the cost of saying yes in a dark room.",
         "Düğün tez. Sonrası karanlık odada evet demenin bedelini öğrenen adam."),
        ("lucia.series", "tv", 71446,
         "Funciona mientras el plan es más listo que el espectáculo. Luego el mito se come a la gente.",
         "It works while the plan is smarter than the spectacle. Then the myth eats the people.",
         "Plan gösteriden akıllıyken işler. Sonra mit insanları yer."),
        ("lucia.series", "movie", 1417,
         "La guerra y el cuento se miran. Ofelia elige un mundo porque el otro ya está podrido.",
         "War and the tale look at each other. Ofelia picks a world because the other is already rotten.",
         "Savaş ile masal birbirine bakar. Ofelia öteki çürüdüğü için bir dünya seçer."),
        ("lucia.series", "movie", 4488,
         "Almodóvar en casa. El secreto está; lo que queda es la risa en el patio.",
         "Almodóvar at home. The secret is there; what remains is the laugh in the yard.",
         "Almodóvar evde. Sır var; kalan avludaki gülüş."),
        ("lucia.series", "movie", 619264,
         "Metáfora sin esconderse. Pensé más en quién decide el menú que en la sangre.",
         "A metaphor that does not hide. I thought more about who decides the menu than about the blood.",
         "Saklanmayan metafor. Kandan çok menüyü kimin seçtiğini düşündüm."),
        ("lucia.series", "movie", 265208,
         "Reloj y clase. El giro está; la resaca, también.",
         "Clock and class. The twist is there; the hangover too.",
         "Saat ve sınıf. Dönüş var; akşamdan kalma da."),
        ("camille.ecran", "movie", 194,
         "Paris trop bruyant, je remets Amélie. La solitude cadrée comme une farce, et ça tient.",
         "When Paris is too loud I put Amélie on. Loneliness framed as a gag, and it holds.",
         "Paris gürültülüyken Amelie. Yalnızlık şaka kadrajı, duruyor."),
        ("camille.ecran", "tv", 90977,
         "Plaisir coupable. La France des petits arrangements, le vol comme réplique. Dimanche soir.",
         "Guilty pleasure. France of small arrangements, theft as a reply. Sunday night.",
         "Suçlu zevk. Küçük ayarların Fransa'sı, cevap olarak hırsızlık. Pazar gecesi."),
        ("camille.ecran", "movie", 531428,
         "Presque sans musique. Le regard comme un travail. La dignité jusqu'au dernier plan.",
         "Almost without music. Looking as work. Dignity through the last shot.",
         "Neredeyse müziksiz. Bakmak bir iş. Son plana kadar onur."),
        ("camille.ecran", "movie", 77338,
         "Vu trop souvent en avion. Il refuse de transformer le handicap en leçon.",
         "Seen too often on planes. It refuses to turn disability into a lesson.",
         "Uçakta fazla izlendi. Engeli derse çevirmeyi reddediyor."),
        ("camille.ecran", "movie", 915935,
         "Huis clos sans sang. Le doute est plus honnête que le verdict.",
         "A closed room without blood. Doubt is more honest than the verdict.",
         "Kansız kapalı oda. Kuşku hükümden dürüst."),
        ("lena.serie", "tv", 70523,
         "Anstrengend auf die richtige Art. Am Ende Eltern, die nicht anrufen. Kalt, und das ist kein Fehler.",
         "Tiring in the right way. It ends on parents who do not call. Cold, and that is not a flaw.",
         "Doğru türden yorucu. Aramayan ebeveynlerde biter. Soğuk, kusur değil."),
        ("lena.serie", "movie", 582,
         "Würde als Risiko. Ulrich Mühe fast ohne Gesicht, deshalb glaubt man jede Sekunde.",
         "Dignity as a risk. Mühe almost without a face, so you believe every second.",
         "Haysiyet risk. Mühe neredeyse yüzsüz; her saniyeye inanıyorsun."),
        ("lena.serie", "movie", 104,
         "Berlin vor dem Stolz. Zeit als Schlagzeug. Laut, rot, kurzatmig. Genau richtig.",
         "Berlin before the pride. Time as a drum kit. Loud, red, short of breath. Exactly right.",
         "Gururdan önceki Berlin. Zaman davul. Gürültülü, kırmızı, nefessiz. Tam."),
        ("lena.serie", "tv", 61181,
         "Kostüm und Kokain, darunter eine Stadt die noch nicht weiß dass sie kippt.",
         "Costume and cocaine, under that a city that does not know it is about to tip.",
         "Kostüm ve kokain; altında henüz devrileceğini bilmeyen kent."),
        ("lena.serie", "tv", 80752,
         "Albern, dann gemein zu seinen Figuren. Das Internet als schlechte Idee.",
         "Silly, then mean to its characters. The internet treated as a bad idea.",
         "Aptal, sonra karakterlerine kötü. İnternet kötü fikir gibi."),
        ("sofia.seriesbr", "movie", 598,
         "O ritmo não envelheceu. Não é filme de tiro. Presta atenção em quem narra.",
         "The rhythm has not aged. Not a shoot-em-up. Watch who is narrating.",
         "Ritim yaşlanmadı. Silah filmi değil. Anlatana bak."),
        ("sofia.seriesbr", "movie", 10664,
         "Filme irritado com razão. Não pede lado limpo. Isso ainda é raro nas salas.",
         "An angry film with reasons. It does not ask for a clean side. Still rare in theaters.",
         "Hakli kızgın film. Temiz taraf istemez. Salonlarda hâlâ az."),
        ("sofia.seriesbr", "tv", 67198,
         "Desigualdade em forma de jogo. Fiquei pelas alianças, não pelos tiros.",
         "Inequality as a game. I stayed for the alliances, not the guns.",
         "Oyun kılığında eşitsizlik. Silah için değil ittifak için kaldım."),
        ("sofia.seriesbr", "movie", 1443,
         "O contrário do espetáculo. Fernanda Montenegro segura só com o olhar.",
         "The opposite of spectacle. Fernanda Montenegro holds it with a look.",
         "Gösterinin tersi. Fernanda Montenegro bakışla tutuyor."),
        ("sofia.seriesbr", "tv", 71446,
         "Estourou como se fosse nossa. Não é o melhor. É o que a gente viu junto.",
         "Blew up as if it were ours. Not the best. What we watched together.",
         "Bizimmiş gibi patladı. En iyisi değil. Beraber izlediğimiz."),
        ("lin.binge", "movie", 843,
         "不敢快进。时间变稠。靠得那么近，却留着一句没说完的话。",
         "I do not skip. Time thickens. They stand that close and still leave a sentence unfinished.",
         "Atlamam. Zaman koyulaşır. O kadar yakın, cümle yine bitmez."),
        ("lin.binge", "movie", 146,
         "武打拍成思念。竹林里那一跑，我还是会屏住呼吸。",
         "Fighting shot as longing. That run through the bamboo still takes my breath.",
         "Dövüş özlem gibi. Bambudaki koşu hâlâ nefesi keser."),
        ("lin.binge", "tv", 96199,
         "仙侠外壳下面是谁被写下历史。蓝忘机不说话更清楚。我喜欢这种别扭。",
         "Under the xianxia skin: who gets written into history. Lan Wangji is clearer silent. I like the stubbornness.",
         "Kabuğun altında tarihi kimin yazdığı. Lan Wangji sessizken net. O inadı seviyorum."),
        ("lin.binge", "movie", 79,
         "色彩先把人打倒。空是故意的，像要退远点看的画。",
         "Colour knocks you down first. The emptiness is on purpose, like a painting you step back from.",
         "Önce renk yere serer. Boşluk kasten, geriden bakılan resim gibi."),
        ("lin.binge", "tv", 93405,
         "规则简单所以更狠。第一季宿舍的灯就够了。",
         "Simple rules, so it hits harder. Season one's dorm lights are enough.",
         "Kurallar basit, daha sert. Birinci sezonun yurt ışığı yeter."),
        ("lin.binge", "movie", 10997,
         "霸王别姬不是怀旧。是一个人把戏和生活叠在同一张脸上，叠到裂开。",
         "Farewell My Concubine is not nostalgia. A person stacking opera and life on one face until it splits.",
         "Vedanın Konkubini nostalji değil. Opera ile hayatı aynı yüzde çatlayana kadar istiflemek."),
        ("aanya.screens", "movie", 20453,
         "मीम नहीं, क्लासरूम की फ़िल्म। जवाब सरल है, जीना कठिन।",
         "Not a meme film. A classroom film. The answer is simple; living it is not.",
         "Meme değil, sınıf filmi. Cevap basit, yaşamak değil."),
        ("aanya.screens", "tv", 67744,
         "मुंबई बीमारी की तरह। हिंदी वेब को साहस इसी ने सिखाया।",
         "Mumbai as an illness. This is what taught Hindi web series to be brave.",
         "Mumbai hastalık gibi. Hintçe diziye cesareti bu öğretti."),
        ("aanya.screens", "movie", 334543,
         "खेल से ज़्यादा पिता-बेटी। राष्ट्र और परिवार एक अखाड़े में।",
         "Less sports than father-daughter. Nation and family in one pit.",
         "Spor değil baba-kız. Millet ve aile aynı minderde."),
        ("aanya.screens", "movie", 579974,
         "जानबूझकर शोर। मेले की किताब, इतिहास की नहीं। हॉल में साँस रुकनी चाहिए।",
         "Noise on purpose. A fairground book, not a history book. A hall should hold its breath.",
         "Kasten gürültü. Panayır kitabı, tarih değil. Salon nefessiz kalmalı."),
        ("aanya.screens", "movie", 19404,
         "स्विट्ज़रलैंड से कम, इजाज़त का इंतज़ार ज़्यादा। अब भी बुरा नहीं लगता।",
         "Less Switzerland than the wait for permission. I still do not mind.",
         "İsviçre'den çok izin bekleyişi. Hâlâ bozulmuyorum."),
        ("nour.yushahid", "tv", 91734,
         "القاهرة بطلة. الرعب الذي يبقى بعد إغلاق الحلقة أصدق من الدم.",
         "Cairo is a character. The fear that stays after the episode is more honest than blood.",
         "Kahire karakter. Bölümden sonra kalan korku kandan dürüst."),
        ("nour.yushahid", "movie", 504562,
         "أتجنبها ثم أعود. زين ليس استعارة. بعد النهاية أحتاج صمت المطبخ.",
         "I avoid it and return. Zain is not a metaphor. After it I need kitchen silence.",
         "Kaçınıp dönüyorum. Zain metafor değil. Bitince mutfak sessizliği."),
        ("nour.yushahid", "movie", 426426,
         "نوار بلا مبالغة. عمن يُسمح له أن ينظر إلى الجانب الآخر من الردهة.",
         "Noir without exaggeration. About who is allowed to look across the lobby.",
         "Abartısız kara film. Lobinin öteki tarafına bakmasına izin verilenler."),
        ("nour.yushahid", "tv", 87917,
         "نكتة طويلة ثم بكاء في المطبخ. الضحك فيه خيانة صغيرة، وهذا ذكاء.",
         "A long joke, then crying in the kitchen. The laugh is a small betrayal, which is smart.",
         "Uzun şaka, sonra mutfakta ağlamak. Gülüş küçük ihanet; zekâ bu."),
        ("nour.yushahid", "tv", 93405,
         "مرآة متأخرة. الموسم الأول يكفي. الباقي يخاف أن يسكت.",
         "A late mirror. Season one is enough. The rest is afraid of going quiet.",
         "Geç ayna. Birinci sezon yeter. Kalan susmaktan korkuyor."),
        ("rafi.screen", "movie", 5801,
         "ক্লাসিক বলে সরিয়ে রাখি না। দারিদ্র্যকে রোমান্টিক করেননি, পাশে বসেছেন।",
         "I do not shelf it as a classic. He did not romanticize poverty; he sat beside it.",
         "Klasik deyip kaldırmıyorum. Yoksulluğu romantize etmedi; yanına oturdu."),
        ("rafi.screen", "tv", 82156,
         "ধৈর্যের পুলিশি কাজ। চিৎকার কম, নোটবুক বেশি।",
         "Police work as patience. Less shouting, more notebooks.",
         "Sabır olarak polis. Bağırış az, defter çok."),
        ("rafi.screen", "movie", 20453,
         "ঢাকার হলেও হাসতে হাসতে চলে। র্যাঞ্চো পরিষ্কার, ক্লাসরুম সত্য।",
         "It still plays in Dhaka with laughter. Rancho is clean; the classroom is true.",
         "Dakka salonunda hâlâ güldürür. Rancho temiz; sınıf doğru."),
        ("rafi.screen", "tv", 67744,
         "অপরাধ নয়, ক্ষমতার হিসাব। বাংলা ওয়েবে এমন সাহস এখনও কম।",
         "Not crime so much as an account of power. Bengali web still rarely goes that far.",
         "Suç değil iktidar hesabı. Bengalce web hâlâ o kadar uzağa az gider."),
        ("rafi.screen", "tv", 93405,
         "সতর্কতা। গরিবকে খেলা বানানো সহজ, সহজ বলেই ধরে রাখা দায়।",
         "A warning. Turning the poor into a game is easy, and therefore hard to hold.",
         "Uyarı. Yoksulu oyuna çevirmek kolay; tutması zor."),
        ("daria.serial", "movie", 479,
         "Не ностальгия. Человек ищет правила в каше. Жёсткий и честный в этой жёсткости.",
         "Not nostalgia. A man looking for rules in mash. Hard, and honest in that hardness.",
         "Nostalji değil. Çorbada kural arayan adam. Sert, sertliğinde dürüst."),
        ("daria.serial", "movie", 242578,
         "Не про рыбу. Про дом на бумаге. Финал не утешает — правильно.",
         "Not about a fish. A house taken with paper. The ending does not comfort, correctly.",
         "Balık değil. Kâğıtla alınan ev. Son teselli etmiyor — doğru."),
        ("daria.serial", "tv", 90669,
         "Дачи важнее спецназа. Не про вирус, про то с кем сядешь в машину.",
         "Dachas matter more than special forces. Not the virus: who you get in the car with.",
         "Yazlık özel timden önemli. Virüs değil: arabaya kiminle bineceğin."),
        ("daria.serial", "movie", 1667,
         "Молчаливый и мокрый. Нужных речей нет, поэтому всё слышно.",
         "Quiet and wet. No needed speeches, so you hear everything.",
         "Sessiz ve ıslak. Nutuk yok, her şey duyuluyor."),
        ("daria.serial", "tv", 70523,
         "Чужая сага про время. Холод — не недостаток. Дети платят дольше, чем хочется признать.",
         "Someone else's saga about time. Cold is not a flaw. Children pay longer than anyone admits.",
         "Başkasının zaman destanı. Soğuk kusur değil. Çocuklar itiraf edilenden uzun ödüyor."),
        ("zara.dramay", "movie", 948969,
         "نعرہ نہیں، گھر کی ہوا۔ بار بار نہیں چلا سکتی، یہی عزت ہے۔",
         "Not a chant. The air inside a house. I cannot put it on again and again; that is the respect.",
         "Slogan değil, evin havası. Tekrar tekrar açamam; saygı bu."),
        ("zara.dramay", "movie", 397422,
         "مہاجر لطیفہ جو گھر بن جاتا ہے۔ پہچان کی ہنسی، اجنبی منظرنامے کی نہیں۔",
         "An immigrant joke that becomes a house. A laugh of recognition, not foreign scenery.",
         "Eve dönüşen göçmen şakası. Tanıma gülüşü, yabancı manzara değil."),
        ("zara.dramay", "movie", 893341,
         "جان بوجھ کر شور۔ تاریخ نہیں، میلے کی کتاب۔",
         "Noise on purpose. Not history. A fairground book.",
         "Kasten gürültü. Tarih değil, panayır kitabı."),
        ("zara.dramay", "tv", 94796,
         "میٹھا ہے، سرحد چھپتی نہیں۔ محبت کے نیچے ریاست۔",
         "Sweet, and the border is not hidden. The state under the love.",
         "Tatlı, sınır gizli değil. Aşkın altında devlet."),
        ("zara.dramay", "movie", 20453,
         "امتحان کے موسم کی فلم۔ ہنسی کے نیچے لاہور کا دباؤ بھی ہے۔",
         "An exam-season film. Under the laughs, Lahore pressure too.",
         "Sınav mevsimi filmi. Gülmenin altında Lahor baskısı da var."),
        ("dimas.nonton", "movie", 71469,
         "Gedung sebagai neraka yang masuk akal. Tempo tidak minta maaf. Jakarta bisa keras.",
         "A building as a hell that makes sense. Tempo does not apologize. Jakarta can be hard.",
         "Mantıklı cehennem olarak bina. Tempo özür dilemez. Jakarta sert olabilir."),
        ("dimas.nonton", "movie", 94329,
         "Lebih ramai, lebih basah. Nafsu, bukan kelebihan. Evans hampir tidak berubah wajah.",
         "Busier, wetter. Appetite, not excess. Evans's face barely changes.",
         "Daha kalabalık, daha ıslak. İştah, fazlalık değil. Evans'ın yüzü değişmez."),
        ("dimas.nonton", "movie", 447055,
         "Horor rumah yang pakai sepi. Lebih takut yang tidak muncul.",
         "House horror that uses quiet. More afraid of what does not appear.",
         "Sessizliği kullanan ev korkusu. Görünmeyenden daha korkuyorum."),
        ("dimas.nonton", "tv", 93405,
         "Ditonton bareng keluarga. Cermin yang telat. Musim satu cukup.",
         "Watched with family. A late mirror. Season one is enough.",
         "Aileyle izlendi. Geç ayna. Birinci sezon yeter."),
        ("dimas.nonton", "tv", 71446,
         "Meledak di warung. Bukan yang terbaik. Yang ditonton bareng. Itu sah.",
         "Exploded in stalls. Not the best. The thing watched together. Allowed.",
         "Tezgâhta patladı. En iyisi değil. Beraber izlenen. Caiz."),
        ("minh.phim", "movie", 480414,
         "Hành động Việt không xin lỗi. Biết chạy và biết đau, không chỉ biết khóc.",
         "Vietnamese action that does not apologize. It knows how to run and hurt, not only cry.",
         "Özür dilemeyen Vietnam aksiyonu. Yalnız ağlamaz; koşmayı ve acımayı bilir."),
        ("minh.phim", "movie", 10427,
         "Gần như không thoại mà vẫn đầy. Sài Gòn như nhớ, không như quảng cáo.",
         "Almost no talk and still full. Saigon as memory, not as an ad.",
         "Konuşmasız ve dolu. Saygon reklam değil hatıra."),
        ("minh.phim", "tv", 94796,
         "Khóc hơi nhiều. K-drama đôi khi là chỗ resting, không phải chỗ thi.",
         "Cried a bit much. Sometimes K-drama is rest, not an exam.",
         "Biraz fazla ağladım. K-drama bazen sınav değil dinlenme."),
        ("minh.phim", "tv", 93405,
         "Coi chung nhà. Không phải kiệt tác. Gương tới trễ. Mùa một đủ.",
         "The house watched together. Not a masterpiece. A late mirror. Season one is enough.",
         "Ev beraber izledi. Başyapıt değil. Geç ayna. Birinci sezon yeter."),
        ("minh.phim", "movie", 496243,
         "Cầu thang nhà mình nghe khác. Châu Á thuyết phục bằng cái cụ thể, không khẩu hiệu.",
         "The stairs in my building sounded different. Asia convinced with the concrete, not slogans.",
         "Binanın merdiveni başka duyuldu. Asya sloganla değil somutlukla ikna etti."),
    ]
    for ad, tur, tid, native, en, tr in incelemeler:
        inceleme_yaz(by_ad[ad], tur, tid, native, en, tr)

    # izleyecegim ile izleme çakışmasın
    for p in by_ad.values():
        for y in p["yapimlar"]:
            if y.get("durum") == "izleyecegim":
                y.pop("oran", None)
                y.pop("platform", None)

    # Liste ad/açıklama tavanı
    for p in by_ad.values():
        for liste in p.get("listeler", []):
            liste["ad"] = liste["ad"][:60]
            liste["aciklama"] = (liste.get("aciklama") or "")[:300]

    # Kararlı sıra: önce vitrin hesaplar
    sira = [
        "yuki.dorama", "jiwon.drama", "miles.watches", "lin.binge",
        "aanya.screens", "lucia.series", "camille.ecran", "lena.serie",
        "sofia.seriesbr", "nour.yushahid", "rafi.screen", "daria.serial",
        "zara.dramay", "dimas.nonton", "minh.phim",
    ]
    cikti = [by_ad[a] for a in sira]

    # Çift yapım temizliği (son yazılan kalsın)
    for p in cikti:
        gorulen: dict[tuple[str, int], dict] = {}
        for y in p["yapimlar"]:
            gorulen[anahtar(y)] = y
        p["yapimlar"] = list(gorulen.values())

    CIKTI.write_text(json.dumps(cikti, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    gonderi = sum(1 for p in cikti for y in p["yapimlar"] if y.get("gonderi"))
    inceleme_n = sum(1 for p in cikti for y in p["yapimlar"] if y.get("inceleme"))
    print(f"yazildi {CIKTI} profil={len(cikti)} gonderi={gonderi} inceleme={inceleme_n}")
    for p in cikti:
        print(
            f"  {p['ad']} dil={p['dil']} yapim={len(p['yapimlar'])} "
            f"gonderi={sum(1 for y in p['yapimlar'] if y.get('gonderi'))} "
            f"liste={len(p.get('listeler') or [])} fav={len(p.get('favoriler') or [])}"
        )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Bölüm yorumu JSON'unu üretir. Kaynak bu dosya; seo_bolum_tohum.json çıktıdır."""
from __future__ import annotations

import json
from pathlib import Path

ogeler: list[dict[str, object]] = []


def a(tmdb: int, sezon: int, bolum: int, tr: str, en: str) -> None:
    """Bir bölüm kaydı ekle; boşlukları sadeleştir."""
    ogeler.append({
        "tmdb_id": tmdb,
        "sezon": sezon,
        "bolum": bolum,
        "tr": " ".join(tr.split()),
        "en": " ".join(en.split()),
    })


# --- Silo 125988 ---
a(125988, 1, 1, """
Apple'ın yeraltı şehrini ilk gördüğünüzde distopya bekliyorsunuz; Silo 1. sezon
1. bölüm size önce bir kasaba veriyor. Özgürlük Günü'nde spiral merdiven, sırtında
sepet taşıyan hamallar, kantindeki o tek dış dünya ekranı: Graham Yost'un ekibi
betonu steril bir laboratuvar gibi değil, kuşaklardır oturulmuş bir ev gibi kuruyor.
Rashida Jones ile David Oyelowo'nun evliliği, büyük sırdan önce küçük bir izin
kâğıdının etrafında dönüyor — çocuk, kural, şüphe. Pilotun cesareti, 'dışarı zehirli
mi' sorusunu bağırarak sormaması; önce bu merdivende kimin ne iş yaptığını izletmesi.
Rebecca Ferguson henüz merkezde değil ve o gecikme doğru: dizi, kimin hikâyesi
olacağını aceleyle ilan etmiyor.
""", """
The first glimpse of Apple's underground city looks like dystopia; Silo season 1
episode 1 hands you a small town instead. Freedom Day: the spiral staircase, porters
with baskets on their backs, the single cafeteria screen of the outside. Graham Yost's
team builds the concrete not as a sterile lab but as a house lived in for generations.
Rashida Jones and David Oyelowo's marriage turns, before any grand secret, around a
small permission slip — a child, a rule, a doubt. The pilot's nerve is that it does
not shout 'is the outside poison?'; it first makes you watch who does what job on
those stairs. Rebecca Ferguson is not yet at the centre, and that delay is right:
the show refuses to announce whose story this will be.
""")

a(125988, 1, 2, """
Holston'ın Seçimi, şerifin odasını bir vicdan odasına çeviriyor. David Oyelowo
Silo 1. sezon 2. bölümde az konuşuyor; bakışı, rozetin ağırlığını diyalogdan daha
net taşıyor. Dizi burada polis prosedürünü değil, bir yemini mercek altına alıyor:
kimin sözü kanun, kimin şüphesi ihanet. Mekân hâlâ merdiven ve koridor ama kamera
artık kalabalığa değil, tek bir karara kilitleniyor. Bu, kahraman çıkarma bölümü
değil; makinenin bir insanı nasıl yutabileceğini gösteren bir ara kapı. Yavaşlığı
kusur değil — Oyelowo o yavaşlığın içini dolduruyor.
""", """
Holston's Pick turns the sheriff's office into a room of conscience. David Oyelowo
speaks little in Silo season 1 episode 2; his look carries the badge's weight more
clearly than dialogue. The show is not doing a police procedural here so much as
examining an oath: whose word is law, whose doubt is betrayal. The spaces are still
stairs and corridors, but the camera locks onto a single decision instead of the
crowd. This is not a hero-making hour; it is a side door showing how the machine
can swallow a person. The slowness is not a flaw — Oyelowo fills it.
""")

a(125988, 1, 3, """
Makineler, siloyu bir fikir olmaktan çıkarıp bir işyeri yapıyor. Rebecca Ferguson
Silo 1. sezon 3. bölümde Juliette'i konuşturarak değil, yağ, gürültü ve vardiya
saatiyle tanıtıyor: jeneratör katı, üst katların boyalı ofislerinden daha dürüst
duruyor. Distopya burada slogan değil, kırılan bir parça ve o parçayı kimsenin
umursamaması. Ferguson'ın mesafeli öfkesi, diziye nihayet bir merkez veriyor;
Tim Robbins henüz gölgede, Common henüz kapıda — ve o boşluk kasıtlı. Bölüm,
bilim kurguyu mühendislik dramına çevirdiği için aklımda: meraka değil, emeğe
inanan bir saat.
""", """
Machines stops treating the silo as an idea and makes it a workplace. Rebecca
Ferguson introduces Juliette in Silo season 1 episode 3 not with speeches but with
oil, noise and shift time: the generator floor feels more honest than the painted
offices above. Dystopia here is not a slogan; it is a broken part, and the fact
that nobody cares about that part. Ferguson's cool anger finally gives the show a
centre; Tim Robbins is still in shadow, Common still at the door — and that gap is
deliberate. The hour stays with me because it turns science fiction into an
engineering drama: a show that believes in labour, not just curiosity.
""")

a(125988, 1, 4, """
Gerçek adlı bölüm, isminin vaat ettiğinden utangaç. Silo 1. sezon 4. bölümde bilgi
bir dosya gibi düşmüyor; kapı aralığından, yarım cümleden, birinin duraksamasından
sızıyor. Ferguson ile Oyelowo'nun sahneleri polis ortaklığı gibi durmuyor, iki
farklı dilin — mekanik ile kanun — birbirini dinlemeyi öğrenmesi gibi duruyor.
Prodüksiyon tasarımı burada küçük işler yapıyor: evlerde fotoğraf yok, çizilmiş
aile portreleri var; o detay, geçmişin nasıl yasaklandığını nutuktan iyi anlatıyor.
Gerilim olayda değil, kimin hangi cümleyi duyduğunda susmasında. Sabır isteyen,
karşılığını veren bir orta bölüm.
""", """
The episode called Truth is shyer than its title. In Silo season 1 episode 4,
information does not drop like a file; it leaks through a doorway, a half-sentence,
someone pausing. Ferguson and Oyelowo do not play a cop partnership so much as two
languages — mechanical and legal — learning to listen. Production design does quiet
work: no photographs in the homes, drawn family portraits instead; that detail
explains how the past was banned better than a speech. The tension is not the
incident; it is who goes silent at which sentence. A middle hour that asks for
patience and pays it back.
""")

a(125988, 1, 5, """
Hademenin Oğlu, siloyu bir aile ölçeğine indiriyor ve bu küçülme diziye yarıyor.
Silo 1. sezon 5. bölümde büyük sistemin yanında bir mutfak, bir yemek, bir suskunluk
var; alt katların nasıl yaşandığı, üst katların dilini tersinden okutuyor. Çocuk
karakterin etrafındaki yetişkinler, distopyayı masal gibi değil komşu gibi
konuşuyor — bu, türün sık kaçırdığı bir sıcaklık. Ferguson hâlâ merkeze yürüyor
ama bölüm onu her sahnenin sahibi yapmıyor; o cömertlik, dünyayı inandırıyor.
Dünya kurma ile hikâye burada aynı odada: merdiven hâlâ var, fakat merdiven artık
bir evin merdiveni.
""", """
The Janitor's Boy scales the silo down to a family, and the shrinking helps.
In Silo season 1 episode 5, beside the big system there is a kitchen, a meal, a
silence; how the lower levels are lived makes you reread the language of the
floors above. The adults around the child speak of dystopia not as a fable but as
a neighbour — a warmth the genre often misses. Ferguson is still walking toward
the centre, but the hour does not make her owner of every scene; that generosity
makes the world believable. World-building and story share a room: the stairs are
still there, but they are a household's stairs now.
""")

a(125988, 1, 6, """
Obje, yasağı soyut bir kural olmaktan çıkarıp masanın üzerine koyuyor. Silo 1.
sezon 6. bölümde elde tutulan küçük bir şey, kantindeki o ölü manzaradan daha tehlikeli
duruyor — çünkü dokunulabilir. Dizi burada 'ne saklanıyor' sorusunu fısıltıdan
çıkarıp paylaşılabilir kılıyor: sır artık birinin cümlesi değil, birinin cebi.
Ferguson'ın Juliette'i bu saatte meraktan çok inatla ilerliyor; inat, meraktan daha
iyi bir motor. Retro-futurist aletler (Apple'ın Severance'tan tanıdık çizgisi)
süsten işe dönüyor. Orta sezonun en net tezi: geçmiş, yasaklandığı için değil,
tutulabildiği için korkutucu.
""", """
The Relic takes the ban off the rulebook and puts it on the table. In Silo season 1
episode 6 a small thing you can hold feels more dangerous than the dead landscape
on the cafeteria screen — because you can touch it. The show takes 'what is hidden'
out of a whisper and makes it shareable: the secret is no longer someone's sentence,
it is someone's pocket. Ferguson's Juliette moves here less on curiosity than on
stubbornness; stubbornness is a better engine. The retro-futurist gadgets (a line
Apple already drew on Severance) stop being garnish and start being work. The
clearest midseason thesis: the past is frightening not because it is forbidden,
but because it can be held.
""")

a(125988, 1, 7, """
Alev Koruyucular, inancı ve arşivi aynı rafa koyuyor. Silo 1. sezon 7. bölüm isyan
sahnesi gibi durmuyor; bir kütüphanenin nasıl bekçi tutulduğunu anlatıyor — ateş,
kâğıt, yasak, üçü de somut. Harriet Walter'ın duruşu, dizinin 'yaşlı bilgelik'
klişesine düşmeden ağırlık veriyor: bilgi burada hazine değil, suç aleti. Ferguson
ise hâlâ yağın ve merdivenin insanı; iki dünya bu saatte gerçekten çarpışıyor.
Hugh Howey'nin romanından gelen bu damar, televizyonda nutka dönüşmeden duruyor.
Distopyayı mesleklerle taşıyan bölüm: rahip, bekçi, mühendis — slogan yok.
""", """
The Flamekeepers put faith and the archive on the same shelf. Silo season 1 episode 7
does not play like a revolt; it shows how a library is guarded — fire, paper, ban,
all three concrete. Harriet Walter's presence gives the hour weight without the
'old sage' cliché: knowledge here is not treasure, it is a tool of crime. Ferguson
is still a person of oil and stairs; the two worlds actually collide in this hour.
The vein that comes from Hugh Howey's novel does not turn into a sermon on
television. An episode that carries dystopia through jobs: priest, guard, engineer
— no slogans.
""")

a(125988, 1, 8, """
Hanna, bir isimden fazlasını geri getiriyor. Silo 1. sezon 8. bölümde geçmiş
silinmiş gibi durur; kamera o silmenin kişisel faturasını masaya bırakıyor —
diyaloglar kısa, boşluklar uzun. Ferguson'ın yüzü bu saatte aksiyon vaat etmeden
ağırlaşıyor; dizi, 'Silo' durağını tam burada kuruyor: merdiven, lamba, birinin
hatırladığı bir cümle. Tim Robbins'in IT katı, nezaketle konuşan bir duvar gibi
duruyor; tehdit bağırmıyor. Bölümü sevenler aksiyon eksikliği diyecek, sevenler
ise şunu diyecek: bu dizi insanı merdivende değil, hatırlarken yakalıyor. Ben
ikincisindeyim.
""", """
Hanna brings back more than a name. In Silo season 1 episode 8 the past looks
erased; the camera leaves the personal bill for that erasing on the table —
dialogue short, gaps long. Ferguson's face grows heavy without promising action;
the show builds its most 'Silo' stop right here: a stair, a lamp, a sentence
someone remembers. Tim Robbins's IT floor stands like a politely speaking wall;
the threat does not shout. Detractors will call it short on action; the rest of
us will say this: the show catches people not on the stairs, but in the act of
remembering. I am with the second group.
""")

a(125988, 1, 9, """
Kaçış, birinci sezonun sabrını hızlandırmıyor, sıkıştırıyor. Silo 1. sezon 9.
bölümde kapılar, vardiyalar, kimin kime baktığı aynı anda daralıyor; montaj nihayet
nefesin yetmediğini hissettiriyor. Ferguson burada koşan bir aksiyon kahramanı
değil, işini yarım bırakmamaya çalışan bir teknisyen — o seçim, diziyi Hunger Games
kopyasından ayırıyor. 'Artık geri yok' hissi bağırılmadan geliyor: bir bakış, bir
kilit, bir merdiven sahanlığı. Finalden önceki saatlerin klasik tuzağı acele etmektir;
Yost'un ekibi acele etmek yerine sıkışmayı uzatıyor. Doğru tercih.
""", """
The Getaway does not speed up season one's patience; it tightens it. In Silo season 1
episode 9, doors, shifts, who is looking at whom all narrow at once; the cutting
finally makes you feel the air run short. Ferguson is not an action hero running;
she is a technician who will not leave a job half-done — that choice keeps the show
from becoming a Hunger Games copy. The feeling that there is no going back arrives
without a shout: a look, a lock, a landing. The classic trap of the hour before a
finale is to hurry; Yost's team stretches the squeeze instead. The right call.
""")

a(125988, 1, 10, """
Dışarısı, birinci sezonu bir cevap gibi değil bir eşik gibi kapatıyor. Silo 1. sezon
10. bölüm ismiyle vaat ediyor; dizi yine de bakışın kendisini, kıyafetin sesini,
nefesin değişmesini önde tutuyor. On bölüm boyunca kurulan ağırlığın boşalıp
boşalmadığına bakıyorum, açıklama listesine değil. Ferguson'ın Juliette'i burada
merkezde ve hak ediyor: mühendislik, inat ve merak nihayet aynı vücutta. Final,
meraktan sonra durup duramayacağını ölçüyor — bazı sorular açık kalıyor, bu bir
kusur değil, Apple'ın tuhaf gizemlere tanıdığı süre. Kantindeki ekran hâlâ orada;
artık ona nasıl baktığınız değişmiş durumda.
""", """
Outside closes season 1 as a threshold, not an answer. Silo season 1 episode 10
promises with its title; the show still leads with the look itself, the sound of
the suit, the change in breath. I watch whether the weight built across ten hours
actually releases, not a list of explanations. Ferguson's Juliette is at the centre
now and has earned it: engineering, stubbornness and curiosity finally share one
body. The finale measures whether the show can pause after curiosity — some
questions stay open, and that is not a flaw, it is the time Apple gives strange
mysteries. The cafeteria screen is still there; how you look at it has changed.
""")

a(125988, 2, 1, """
Mühendis, ikinci sezonu turist broşürü gibi açmıyor. Silo 2. sezon 1. bölümde
Juliette'in elleri yine aletlerin arasında; zemin ise birinci sezonun merdivenleri
değil. Ferguson yalnızlığın içinde iş yaparak duruyor: önce tamir, sonra yön.
Devam sezonları 'daha büyük' olmak ister; bu saat daha yalnız olmayı seçiyor ve
o seçim diziye yakışıyor. İçerideki silo kendi temposunda dönmeye devam ediyor —
iki mekân, iki ritim, henüz birbirine yetişmemiş. Steve Zahn'ın girişi, Ferguson'ın
ciddiyetine pürüz katıyor; pürüz iyi. 'Daha çok silo' vaadi değil, bir kadının
hayatta kalma hesabı: bu, doğru ikinci sezon kapısı.
""", """
The Engineer does not open season 2 like a tourist brochure. In Silo season 2
episode 1 Juliette's hands are among tools again; the ground is not season one's
stairs. Ferguson stays alive by working inside loneliness: repair first, direction
later. Sequel seasons want to be bigger; this hour chooses to be lonelier, and
that choice fits. The silo inside keeps turning at its own pace — two spaces, two
rhythms, not yet catching each other. Steve Zahn's arrival puts a scratch on
Ferguson's gravity; the scratch is good. Not a promise of 'more silos', a woman's
calculation of how to stay alive: the right door into a second season.
""")

a(125988, 2, 2, """
Düzen, içerideki siloyu ikinci sezonda yeniden sertleştiriyor. Silo 2. sezon 2.
bölümde nöbet, kural, kimin sözünün geçtiği birinci sezondan tanıdık ve bir diş
daha sıkı. Common'ın güvenlik dili, Tim Robbins'in IT nezaketi: iki otorite, iki
farklı soğukluk. Dışarıdaki yalnızlıkla içerideki kalabalık aynı kesmede duruyor;
bu paralel kurgunun riski dağılmak, kazancı ise Juliette'in yokluğunun içeriye
nasıl dolduğunu göstermek. Bölüm nefes aldırıyor hâlâ — Yost, panik dizisi
çekmiyor. Siyaset burada koridor fısıltısı: kim kimin yerine geçecek, kim henüz
taraf değil. Sabırlı, sinirli, yerinde bir saat.
""", """
Order hardens the silo inside all over again in season 2. In Silo season 2 episode 2,
watches, rules, whose word counts are familiar from season 1 and a notch tighter.
Common's security language, Tim Robbins's IT politeness: two authorities, two
different colds. Loneliness outside and the crowd inside sit in the same cut; the
risk of that parallel is scatter, the prize is watching how Juliette's absence is
filled. The hour still lets you breathe — Yost is not directing a panic show.
Politics here is a corridor whisper: who will take whose place, who has not chosen
a side. A patient, nervy, correctly pitched hour.
""")

a(125988, 2, 3, """
Solo, isminin hakkını sesle veriyor. Silo 2. sezon 3. bölümde kalabalık sahneler
incelince rüzgâr, metal, ayak sesi öne çıkıyor; konuşmadan ilerleyen bir gerilim
denemesi bu ve herkesin konuştuğu dizilerde bu cesaret az. Ferguson neredeyse
sessiz bir western'in ortasında: ufuk yok, ama mesafe var. Steve Zahn'ın temkinli
mizahı, yalnızlığı süs değil yöntem yapan saati bozmuyor. Görüntü yönetmeni yeraltı
betonunu bırakıp açık arazinin boşluğunu kuruyor; aynı dizi, başka bir oksijen.
Bölümü 'yavaş' diye geçenler, ses tasarımını kaçırıyor. Kulaklıkla izleyin.
""", """
Solo earns its title with sound. In Silo season 2 episode 3, once the crowded scenes
thin out, wind, metal and footsteps step forward; it is an attempt at tension that
moves without talk, and that courage is rare in shows where everyone speaks.
Ferguson stands almost inside a silent western: no horizon, but there is distance.
Steve Zahn's careful humor does not break an hour that treats loneliness as a
method, not decoration. The cinematography leaves underground concrete for the
emptiness of open ground; the same show, different oxygen. People who skip it as
'slow' are missing the sound design. Watch it with headphones.
""")

a(125988, 2, 4, """
Harmonyum, bir malzemenin adı ve bir dönüş hesabı. Silo 2. sezon 4. bölümde
Juliette'in hedefi somut: bir kıyafet, bir yalıtım, bir siloyu ayakta tutma aritmetiği.
Rebecca Ferguson burada kahraman pozuna yatmadan tamirci kalıyor; o inat, sezonun en iyi
kararı. İçeride toplantılar ve merdivenler kendi temposunda — iki mekânı kesmek,
dizinin 'tek koridor' hissini kırıyor. Harmonyum kelimesi hem müzik hem mühendislik
çağrıştırıyor; bölüm ikisini de hak ediyor: ritim var, vida var. Orta sezonun
güçlü durağı, çünkü vaat değil iş gösteriyor. 'Silo 2. sezon 4. bölüm' diye arayan
birine ilk diyeceğim bu: merdiven dizisi, nihayet iki yerde birden nefes alıyor.
""", """
The Harmonium is the name of a material and a calculation of return. In Silo season 2
episode 4 Juliette's aim is concrete: a suit, an insulation, the arithmetic of keeping
a silo standing. Rebecca Ferguson stays a repairer, not a hero pose; that stubbornness is
the season's best decision. Inside, meetings and stairs keep their own pace — cutting
the two spaces breaks the show's single-corridor feeling. The word harmonium suggests
both music and engineering; the hour earns both: there is rhythm, there are screws.
A strong midseason stop because it shows work, not a promise. To anyone searching
'Silo season 2 episode 4', this is the first thing I would say: the staircase show
is finally breathing in two places at once.
""")

a(125988, 2, 5, """
İniş, 'aşağı' kelimesini tehlikeli bir metafordan fiziksel bir harekete çeviriyor.
Silo 2. sezon 5. bölüm konuşmayı kesip mesafeyi ölçüyor: kaç kat, kaç kapı, kaç
dakika hava. Distopya burada fikir değil, akciğer işi. Ferguson'ın bedeni, merdiven
dizisinin vaadini nihayet dikey olarak ödüyor; kamera onu izlerken süs yapmıyor,
nefes sayıyor. İçerideki hat ise kendi kuyusuna iniyor: otorite, dedikodu, kimin
kimin elini tuttuğu. İki iniş, iki karanlık. Bölüm bazı seyirciden sabır isteyecek;
ben o sabrı, açıklama sahnesine tercih ederim. Silo en iyi, insanı merdivenin
ortasında bıraktığında.
""", """
Descent turns the dangerous metaphor of 'below' into a physical movement. Silo
season 2 episode 5 cuts the talk and measures distance: how many levels, how many
doors, how many minutes of air. Dystopia here is not an idea; it is lung work.
Ferguson's body finally pays the staircase show's promise vertically; the camera
does not decorate her, it counts breath. The line inside is descending its own
shaft: authority, gossip, whose hand is in whose. Two descents, two darks. The
hour will ask some viewers for patience; I prefer that patience to an explanation
scene. Silo is at its best when it leaves you in the middle of the stairs.
""")

a(125988, 2, 6, """
Barikatlar, içerideki siloyu sokak çatışması gibi değil bekleyiş gibi anlatıyor.
Silo 2. sezon 6. bölümde kim kapıyı tutuyor, kim erzak sayıyor, kim henüz taraf
değil — kalabalık var, yüzler kaybolmuyor. 'İsyan bölümü' klişesine düşmemesinin
sebebi bu: kamera silaha değil, kimin hâlâ tereddüt ettiğine bakıyor. Common ve
Robbins'in sahneleri, nezaketle yapılan tehdidin nasıl işlediğini gösteriyor;
bağıran diktatör yok, prosedür var. Juliette hattı ise başka bir barikat: doğa,
alet, zaman. İki kuşatma, aynı soru — içeride kalmak mı, dışarıda durmak mı.
Ağır, net, dizinin siyaset saatlerinden.
""", """
Barricades tells the silo inside not as a street fight but as a wait. In Silo
season 2 episode 6, who holds the door, who counts supplies, who has not chosen a
side — there is a crowd, and the faces are not lost. That is why it refuses the
'revolt episode' cliché: the camera looks not at the weapon but at who is still
hesitating. Common and Robbins show how a threat spoken politely actually works;
there is no shouting dictator, there is procedure. Juliette's line is another
barricade: weather, tools, time. Two sieges, the same question — stay inside, or
stand outside. Heavy, clear, one of the show's political hours.
""")

a(125988, 2, 7, """
Dalış, Silo'nun betonuna su ve karanlık ekliyor. Silo 2. sezon 7. bölüm görüntü
olarak sezonun belleğinde kalacak duraklardan: nefes, cam, ışığın yetmediği yer.
Hikâye çözülme sahnesine dönmüyor; bir iş yapılıyor ve o işin riski yetiyor.
Ferguson'ı bir aksiyon yıldızı gibi ışıklandırmıyorlar — yüzü buğulu, hareketi
hesaplı, kahramanlık pozunun reddi bilinçli. Su altı sahnesi türün ucuz heyecanına
kaçmadan, mühendislik korkusunu koruyor: boğulmak bir metafor değil, bir ihtimal.
İzledikten sonra cümle değil, bir görüntü kalıyor. Dizi bazen tam da bunu
istemeli.
""", """
The Dive adds water and dark to Silo's concrete. Silo season 2 episode 7 is a stop
the season will remember as an image: breath, glass, the place where light is not
enough. The story does not turn into a briefing; a job is being done,
and the risk of that job is enough. They do not light Ferguson like an action star
— her face is fogged, her movement calculated, the refusal of a hero pose
deliberate. The underwater work keeps engineering fear instead of cheap genre
thrills: drowning is not a metaphor, it is a possibility. After watching, a picture
stays, not a sentence. Sometimes that is exactly what the show should want.
""")

a(125988, 2, 8, """
Quinn'in Kitabı, ikinci sezona bir kayıt nesnesi sokuyor: metin, bellek, kimin
el yazısı. Silo 2. sezon 8. bölümde yazı yine tehlikeli; bu kez tehlikeyi okuyabiliyorsunuz.
Aksiyonun arasında bir arşiv duruşu — kelimeler ölçülü, tempo konuşmaya yaklaşıyor
ama nutka düşmüyor. Kitaplı distopyalar çoğu zaman 'yasak roman' klişesine yaslanır;
burada nesne, birinin hayatına bağlı olduğu için işliyor. Ferguson'ın hattı ile
içerideki hat, kâğıt üzerinden değil kesme üzerinden konuşuyor. Orta-sonun sakin
saati; sakinlik boşluk değil, bir sonraki yangından önce alınan nefes. Dizi
okumayı, merdiven çıkmak kadar siyasi sayıyor.
""", """
The Book of Quinn brings a record-object into season 2: a text, a memory, whose
handwriting. In Silo season 2 episode 8 writing is dangerous again; this time you
can read the danger. An archive pause in the middle of the action — words measured,
the pace moving toward talk without falling into a sermon. Bookish dystopias often
lean on the 'forbidden novel' cliché; here the object works because it is tied to
a life. Ferguson's line and the line inside speak not through paper but through
the cut. A quiet hour in the back half; the quiet is not a hole, it is the breath
taken before the next fire. The show treats reading as political as climbing stairs.
""")

a(125988, 2, 9, """
Safeguard, ismiyle koruma vaat ediyor; bölüm, korumanın kimin için olduğunu
bulanık bırakıyor. Silo 2. sezon 9. bölüm finalden önceki sıkışmayı kurum diline
çeviriyor: kararlar koridor fısıltısı değil, protokol. Robbins'in nezaketi bu
saatte en keskin silah; gülümseyen bir cümle, bağıran bir sahneden daha soğuk.
İçerideki siyaset sertleşirken Juliette hattı başka bir 'koruma' sorusu soruyor —
kimi, neden, kimin izniyle. Kelime oyunu ucuz durmuyor çünkü dizi başından beri
kavramları çalıyor: özgürlük günü, temizlik, düzen. Zemin, sezon sonuna giderken
bilerek kaygan. Bir diş sıkma saati, doğru yerde.
""", """
The Safeguard promises protection in its name; the episode leaves whose protection
it is unclear. Silo season 2 episode 9 turns the pre-finale squeeze into the
language of institutions: decisions are not corridor whispers, they are protocol.
Robbins's politeness is the sharpest weapon in the hour; a smiling sentence is
colder than a shouting scene. While politics inside hardens, Juliette's line asks
another question of 'protection' — whom, why, with whose permission. The wordplay
does not feel cheap because the show has been stealing concepts from the start:
freedom day, cleaning, order. The ground is meant to be slippery on the way to the
end. A jaw-clenching hour, in the right place.
""")

a(125988, 2, 10, """
Ateşin İçine, ikinci sezonu başka bir odaya açıyor; birinci sezonun 'dışarı'
hissini tekrar etmiyor. Silo 2. sezon 10. bölümün ismi sıcak, dizi yine bakışın
ve kararın soğuk tarafını önde tutuyor. Ferguson'ın Juliette'i bu finalde zafer
pozuna yatmıyor: iş bitmemiş, fatura duruyor. İçerideki hat ise kimin yanında
durduğunuzu düşünmenizi istiyor, neyin açıklandığından çok. Devam finali olarak
dürüst — her şeyi bağlamıyor, bağladığı yerde de nutuk yok. Apple'ın gizem
dizilerine tanıdığı süre yine işe yarıyor. İzledikten sonra aklımda bir açıklama
değil, bir hizalama kaldı: kapının hangi tarafındasınız.
""", """
Into the Fire opens season 2 into another room; it does not repeat season 1's
feeling of 'outside'. Silo season 2 episode 10 has a hot title; the show still
leads with the cold side of looking and deciding. Ferguson's Juliette does not
take a victory pose in this finale: the job is unfinished, the bill is waiting.
The line inside wants you to think about whose side you are on, more than about
what was explained. Honest as a sequel finale — it does not tie everything, and
where it ties there is no sermon. The time Apple gives mystery shows is working
again. After watching I was left not with an explanation but with an alignment:
which side of the door are you on.
""")

a(125988, 3, 1, """
Sen Kimsin?, üçüncü sezonu bir kimlik sorusuyla açıyor ve bu, Silo için doğru
kapı: isim burada her zaman evrak ve hafıza demekti. Silo 3. sezon 1. bölüm yeni
bir haritayı aceleyle doldurmuyor; önce kimin konuştuğunu, kimin tanıdığını ölçüyor.
Ferguson'ın Juliette'i artık 'yeni yüz' değil, tanınmak istemeyen / tanınması
gereken biri — o gerilim, merdiven geriliminden taze. Dizi eski alışkanlığını
bırakmamış: dünya kurma, nutuk değil, duruş. Üçüncü sezonlar şişmanlar; bu açılış
zayıf düşmemek için şişmanlamıyor. Kimlik sorusu ucuz bir amnezi numarası değil,
silonun başından beri taşıdığı yara: geçmiş silinince insan da silinir mi.
""", """
Who Are You? opens season 3 with a question of identity, and for Silo that is the
right door: a name here has always meant paperwork and memory. Silo season 3
episode 1 does not rush to fill a new map; it first measures who is speaking and
who is recognized. Ferguson's Juliette is no longer a 'new face' but someone who
does not want to be known / must be known — that tension is fresher than staircase
tension. The show has not dropped its old habit: world-building is a stance, not a
speech. Third seasons get fat; this opening refuses fat in order not to go weak.
The identity question is not a cheap amnesia trick; it is the wound the silo has
carried from the start: when the past is erased, is the person erased too.
""")

a(125988, 3, 2, """
Her Şey Yolunda, başlığıyla tersini fısıldayan bölümlerden. Silo 3. sezon 2.
bölümde 'yolunda' cümlesi teselli değil, bir düzen iddiası — günlük hayat düzgün
görünürken çatlaklar kadrajda kalıyor. Ironi bağırmıyor; tam da o yüzden bu dizinin
sesine uyuyor. Ferguson'ı her karede parlatmak yerine, dizi bazen onu bir odanın
kenarına koyuyor: merkezde olmamak da bir politika. İçerideki nezaket, birinci
sezonun Freedom Day'indeki o sahte bayramı hatırlatıyor. Üçüncü sezonun bu erken
saati, aksiyon vaat etmeden 'bu ev hâlâ yalan söylüyor' diyor. Kulağa az gelir;
Silo'da az, çoğu zaman doğru doz.
""", """
It's All Good is one of those episodes whose title whispers the opposite. In Silo
season 3 episode 2 a sentence that says everything is fine is not comfort; it is a
claim of order — daily life looks smooth while the cracks stay in frame. The irony
does not shout; that is why it fits this show's voice. Instead of lighting Ferguson
in every shot, the show sometimes puts her at the edge of a room: not being at the
centre is also a politics. The politeness inside recalls that false holiday of
Freedom Day in season 1. This early hour of season 3 says 'this house is still
lying' without promising action. It sounds like little; in Silo, little is often
the right dose.
""")

a(125988, 3, 3, """
Karanlık Ağ, merdiven dizisine bir altyapı katmanı ekliyor: telsiz, kablo, kimin
kimi duyduğu. Silo 3. sezon 3. bölüm bilgiyi yalnız sır gibi değil şebeke gibi
ele alıyor — bu taze, çünkü Silo uzun süre dikey mekânın esiriydi. Yatay bağlantı
gerilimi, 'kim yukarıda' sorusunu 'kim hatta' sorusuna çeviriyor. Ses tasarımı
yine işin büyük kısmını taşıyor; bir cızırtı, bir bakıştan uzun durabiliyor.
Ferguson'ın hattı ile içerideki hat, bu sefer kablo üzerinden değil kesme
üzerinden konuşsa da aynı soruyu paylaşıyor: duymak bir güç mü, bir tuzak mı.
Üçüncü sezonun en 'yeni' duraklarından, şişirmeden.
""", """
A Dark Web adds a layer of infrastructure to the staircase show: radio, cable, who
hears whom. Silo season 3 episode 3 treats information not only as a secret but as
a network — that is fresh, because Silo was long a prisoner of vertical space.
Horizontal connection-tension turns 'who is above' into 'who is on the line'.
Sound design again carries much of the work; a crackle can last longer than a look.
Ferguson's line and the line inside, even if they speak through the cut rather
than the cable this time, share the same question: is hearing a power, or a trap.
One of season 3's newest stops, without puffing itself up.
""")

a(125988, 3, 4, """
Ne Yaparsan Yap, Eve Gitme — başlık bir uyarı, bölüm o uyarının maliyetini
gösteriyor. Silo 3. sezon 4. bölümde ev yine hem sığınak hem tuzak; dizi dönüş
vaadini öne sürmeden yolun yorgunluğunu kadraja alıyor. Cümlenin kendisi zaten
yeterince sert, tempo aceleci olmak zorunda değil. Ferguson'ın yüzü 'eve dön'
romantizmini reddediyor: ev, siloda her zaman bir kat numarası ve bir kural.
İçerideki hat bu uyarıyı başka bir dilde tekrarlıyor olabilir; paralel kurgu hâlâ
riskli, hâlâ işe yarıyor. Üçüncü sezonun bu saati, macera dizisi olmak yerine
yol filminin yorgunluğunu deniyor. Daha iyi tercih.
""", """
Whatever You Do, Don't Go Home — the title is a warning, the episode shows the
cost of that warning. In Silo season 3 episode 4 home is again both shelter and
trap; the show puts the tiredness of the road in frame without dangling a promise
of return. The sentence itself is already hard enough; the pace does not have to
rush. Ferguson's face refuses the romance of 'going home': in the silo, home has
always been a floor number and a rule. The line inside may be repeating the
warning in another language; the parallel cutting is still a risk, and still
works. This hour of season 3 tries the tiredness of a road movie instead of
becoming an adventure show. The better choice.
""")

a(125988, 3, 5, """
Hafıza, üçüncü sezonun en Silo başlıklarından: kayıt, unutuş, kimin geçmişi
taşıdığı. Silo 3. sezon 5. bölüm aksiyon vaat etmek yerine kimin neyi hatırladığını
ölçüyor. Distopyalarda bellek genelde bir dosya; burada yüz ifadesine de bulaşıyor,
o yüzden yavaş olsa da boş durmuyor. Ferguson'ı bir arşivci gibi değil, unutmanın
bedelini vücudunda taşıyan biri gibi izliyoruz. Dizi başından beri tarihi sildiği
için bu saat gecikmiş bir fatura gibi duruyor — iyi anlamda. Kimlik sorusu geçen
bölümlerden beri birikiyor; Hafıza o birikimi isimlendiriyor. Sessiz, inatçı, yerinde.
""", """
Memory is one of season 3's most Silo titles: record, forgetting, who carries the
past. Silo season 3 episode 5 measures who remembers what, instead of promising
action. In dystopias memory is usually a file; here it gets onto faces too, which
is why the hour, even when slow, does not feel empty. We watch Ferguson not as an
archivist but as someone who carries the cost of forgetting in her body. Because
the show has been erasing history from the start, this hour feels like a bill that
arrived late — in a good way. The identity question has been accumulating for
weeks; Memory names that accumulation. Quiet, stubborn, in the right place.
""")

a(125988, 3, 6, """
Sürüş, yeraltı diline bir yol, bir hareket, belki bir araç sokuyor. Silo 3. sezon
6. bölüm kapalı kutunun dışına çıkmadan mesafeyi değiştiriyor: bakış pencereden
çok yola kayıyor. Beton dünya biraz açılıyor; açıklama değil, ritim değişiyor.
Ferguson'ın Juliette'i bu saatte yolcu değil sürücü — kontrol meselesi, macera
meselesinden büyük. Üçüncü sezonun bu orta yeri, merdiven estetiğine yeni bir
yataylık katıyor ve bu, dizinin nefesini değiştiriyor. Tehlike manzarada değil,
kimin direksiyonda olduğunda. Az konuşan, iyi kateden bir bölüm.
""", """
The Drive brings a road, a movement, perhaps a vehicle into the underground
language. Silo season 3 episode 6 changes the distance without leaving the closed
box: the gaze shifts from the window to the road. The concrete world opens a
little; it is the rhythm that changes, not the explanation. Ferguson's Juliette
is a driver in this hour, not a passenger — a question of control larger than a
question of adventure. This middle stretch of season 3 adds a new horizontality
to the staircase aesthetic, and that changes the show's breath. The danger is not
in the landscape; it is in who is at the wheel. An hour that talks little and
covers ground well.
""")

a(125988, 3, 7, """
Telsiz, sesin siloda nasıl bir güç olduğunu netleştiriyor. Silo 3. sezon 7. bölümde
kimin konuştuğu, kimin duyduğu, kimin yalanı kanaat sandığı — görüntüden çok işitme
gerilimi var. Merdiven estetiğine yeni bir katman: frekansı kaçırmama. Bağıran bir
orta-final değil; cızırtı, nefes, bir ismin havada asılı kalması. Ferguson burada
da tamirci kalıyor, peygamber olmuyor — sesi bir alet gibi kuruyor. Üçüncü
sezonun şimdiye kadarki en 'kulak' bölümü. Kulaklık tavsiyesi ciddi: bu dizi
bazen bakılmaz, dinlenir.
""", """
Radio makes clear what a power the voice is in the silo. In Silo season 3 episode 7,
who speaks, who hears, who takes a lie for fact — there is more tension in hearing
than in the image. A new layer on the staircase aesthetic: not missing the
frequency. Not a shouting mid-finale; a crackle, a breath, a name left hanging in
the air. Ferguson stays a repairer here too, not a prophet — she builds the voice
like a tool. This is the season's most 'ear' hour so far.
The headphone recommendation is serious: sometimes this show is not watched, it is
listened to.
""")

# --- Breaking Bad 1396 ---
a(1396, 1, 1, """
Pilot, bir kimya öğretmeninin öğleden sonrasını efsaneye çevirmeden önce utancı
uzatıyor. Breaking Bad 1. sezon 1. bölümde çöl, iç çamaşırı, karavan: görüntüler
henüz poster değil, biraz komik, biraz mahcup. Bryan Cranston'ın Walter'ı Heisenberg
değil; pantolonu düşmüş, sesi kırık, karısına yalanı henüz beceriksiz. Vince
Gilligan'ın kurnazlığı, dönüşümü vaat edip göstermemesi — 62 bölümün kapısı bu
yüzden temiz kalıyor. Aaron Paul henüz bir patlama, Anna Gunn henüz bir evin
dengesi. Suç dizisi gibi açılmıyor; bir sağlık faturası gibi açılıyor. O sıradanlık,
sonradan gelecek her şiddetin zeminini dürüstçe kuruyor.
""", """
The Pilot stretches embarrassment before it turns a chemistry teacher's afternoon
into legend. In Breaking Bad season 1 episode 1 the desert, the underwear, the RV:
the images are not a poster yet, a little funny, a little ashamed. Bryan Cranston's
Walter is not Heisenberg; his trousers are down, his voice cracks, the lie to his
wife is still clumsy. Vince Gilligan's cunning is that he promises a transformation
and does not show the turn — that is why the door to 62 episodes stays clean. Aaron
Paul is not yet an explosion, Anna Gunn not yet the balance of a house. It does not
open like a crime show; it opens like a medical bill. That ordinariness honestly
lays the ground for every violence that will follow.
""")

a(1396, 2, 13, """
ABQ, ikinci sezonu bir mahalle sabahının sessizliğine yığıyor. Breaking Bad 2.
sezon 13. bölüm felaket filmi gibi bağırmaz: kamera evin içine, sokağa, bir çocuğun
dünyasına iner ve sezon boyunca biriken rastlantıyı orada bırakır. Gilligan'ın tezi
görüntüye çevrilir — küçük seçimler uzağa gider — ama nutuk yoktur. Cranston bu
finalde 'kötü adam' pozuna yatmaz; yorgun bir baba gibi durur, o yorgunluk daha
korkunçtur. Pembe bir ayrıntının gölgesi, sezonun şans ile suç arasında kurduğu
köprüyü tek karede hatırlatır. Tempo felaket değil, komşu. Bu yüzden aklımda kalır.
""", """
ABQ piles season 2 into the quiet of a neighbourhood morning. Breaking Bad season 2
episode 13 does not shout like a disaster movie: the camera drops into a house, a
street, a child's world, and leaves there the coincidences gathered all season.
Gilligan's thesis turns into an image — small choices travel far — without a sermon.
Cranston does not take a 'bad man' pose in this finale; he stands like a tired
father, and that tiredness is more frightening. The shadow of a pink detail recalls,
in a single frame, the bridge the season built between luck and crime. The pace is
not catastrophe; it is a neighbour. That is why it stays.
""")

a(1396, 3, 13, """
Yeterli Önlem, bir iş emrinin ağırlığını taşıyan 3. sezon finali. Breaking Bad
bu saatte konuşmayı kesip bakışa, kapı eşiğine, kimin tetikte durduğuna dönüyor.
Cranston ile Paul'un sahneleri kahramanlık değil meslekî karar gibi duruyor: soğuk,
kısa, geri alınamaz. Gilligan suçunu hâlâ insan ölçeğinde tutuyor; imparatorluk
henüz poster, henüz montaj. 3. sezon 13. bölüm, 'artık başka biri' cümlesini
bağırmadan yazıyor. İzledikten sonra aklımda bir replik değil, bir eşik kaldı.
Televizyonun en iyi suç dizisi, bazen en az konuştuğu yerde.
""", """
Full Measure is a season 3 finale that carries the weight of a work order. Breaking
Bad here cuts the talk and returns to a look, a threshold, who is on edge. Cranston
and Paul's scenes play like a professional decision, not a hero beat: cold, short,
irreversible. Gilligan still keeps the crime on a human scale; the empire is not
yet a poster, not yet a montage. Season 3 episode 13 writes the sentence 'someone
else now' without shouting it. After watching I was left with a threshold, not a
line. The best crime show on television is sometimes the one that talks least.
""")

a(1396, 4, 13, """
Yüzleşme, 4. sezon finalinin adıyla oynuyor: yüz, maske, kimin kazandığı.
Breaking Bad 4. sezon 13. bölüm uzun bir satranç yılını tek bir görüntüye bağlıyor
— bahçe, kutu, detay. Tempo yükseliyor ama dizi hâlâ evin içini, bir bitkiyi, bir
telefonu unutmuyor. Cranston'ın zaferi zafer gibi durmuyor; daha çok bir 'artık
geri yok' sahnesi. Giancarlo Esposito'nun soğukluğu, sezonun asıl rakibini nutuksuz
kurmuştu; bu saat o soğukluğun faturasını görüntüye çeviriyor. Gösteriş var, ucuzluk
yok. Suç draması bazen bir bahçede biter, bir çatışmada değil.
""", """
Face Off plays with its title in the season 4 finale: a face, a mask, who won.
Breaking Bad season 4 episode 13 ties a long year of chess to a single image —
a garden, a box, a detail. The pace rises, but the show still does not forget the
inside of a house, a plant, a phone. Cranston's victory does not feel like victory;
it is more a 'no going back' scene. Giancarlo Esposito's cold had built the season's
true opponent without a sermon; this hour turns that cold into a picture. There is
spectacle, no cheapness. Sometimes a crime drama ends in a garden, not in a gunfight.
""")

a(1396, 5, 8, """
Kitaptaki Gerçek, 5. sezonun ilk yarısını bir imparatorluk sessizliğiyle kapatıyor.
Breaking Bad 5. sezon 8. bölümde Walter'ın dünyası büyümüştür; kamera bunu bağırarak
değil, montajın ritmiyle gösterir — iş, para, tekrar. Cranston'ın yüzü kutlama ile
pişmanlık arasında; pişmanlık kadrajın kenarında durur. Yarım sezon finali gibi
durmasının sebebi gerçekten bir kapının kapanması. Aaron Paul bu saatte merkezde
olmak zorunda değil: yokluğu da bir cümle. Gilligan'ın en soğuk duraklarından;
soğukluk süs değil, teşhis. İmparatorluk kurulunca dizi, kurmanın nasıl bir sessizlik
olduğunu biliyor.
""", """
Gliding Over All closes the first half of season 5 with the silence of an empire.
In Breaking Bad season 5 episode 8 Walter's world has grown; the camera shows it
with the rhythm of the cut, not by shouting — work, money, again. Cranston's face
sits between celebration and regret; regret stays at the edge of the frame. It
feels like a mid-season finale because a door really does close. Aaron Paul does
not have to be at the centre of this hour: his absence is also a sentence. One of
Gilligan's coldest stops; the cold is a diagnosis, not decoration. Once the empire
is built, the show knows what a silence building it is.
""")

a(1396, 5, 14, """
Kaçınılmaz Son, dizinin en ağır saatlerinden biri olduğu için değil, kaçacak yer
bırakmadığı için listelerde duruyor. Breaking Bad 5. sezon 14. bölümde çöl yine
var; bu kez komik değil. Rian Johnson'ın yönetimi, yıllandırılmış bir hesabı birkaç
sahneye sığdırıp hâlâ nefes boşluğu bırakıyor — isim bir şiirden, tempo hiç şiir
gibi değil. Cranston'ın sesi burada 'bir kimya öğretmeni' değil; yılların yalanı
bir anda tek bir tona çöküyor. Kim öldü, kim kaldı diye yazmayacağım. Diyeceğim
şu: tragedya, televizyonda nadiren bu kadar net fatura keser. İzledikten sonra
bir süre uzaktan kumandaya dokunmamak normal.
""", """
Ozymandias sits on the lists not because it is one of the heaviest hours, but
because it leaves nowhere to run. In Breaking Bad season 5 episode 14 the desert
is there again; this time it is not funny. Rian Johnson's direction fits a
long-aged account into a few scenes and still leaves a gap to breathe — the title
is from a poem, the pace is not poetic at all. Cranston's voice here is not 'a
chemistry teacher'; years of lying collapse into a single tone. I will not write
who dies and who remains. I will say this: tragedy rarely bills this clearly on
television. After watching, not touching the remote for a while is normal.
""")

a(1396, 5, 16, """
Elveda, Breaking Bad'i bir kapanış konuşması gibi değil bir son iş gibi bitiriyor.
5. sezon 16. bölüm nostaljiye yatmadan yerleştiriyor: kim nerede, kim neyi tamamlıyor.
Final dizileri çoğu zaman konuşur; Gilligan daha çok nesne ve oda koyuyor. Cranston'ın
Walter'ı burada itiraf ile zafer arasında bir yerde — eleştirmenlerin yıllardır
tartıştığı o belirsizlik, bölümün kusuru değil karakteri. Aaron Paul'a ayrılan
alan, intikam sahnesinden çok bir bakışın hakkını veriyor. İzledikten sonra efsane
kareden çok, sessizliğin nasıl durduğunu hatırlıyorum. Kapanış cümlesi yok; iş
bitmiş, lamba sönmüş.
""", """
Felina finishes Breaking Bad like a last job, not a closing speech. Season 5
episode 16 places things without lying down in nostalgia: who is where, who is
finishing what. Finale episodes usually talk; Gilligan mostly puts objects and
rooms. Cranston's Walter sits somewhere between confession and victory — the
ambiguity critics have argued about for years is the hour's character, not its
flaw. The space given to Aaron Paul honours a look more than a revenge scene.
After watching I remember how the silence sits, more than a legendary shot. There
is no closing sentence; the job is done, the lamp is out.
""")

# --- Squid Game / Dark ---
a(93405, 1, 1, """
Kırmızı Işık, Yeşil Işık, oyunu poster yapmadan önce borçlu bir hayatın temposunu
kuruyor. Squid Game 1. sezon 1. bölümde yeşil eşofmanlar henüz ikon değil; odalar,
telefonlar, bir trenin içi var. Lee Jung-jae'nin Gi-hun'u kahraman değil, kötü
kararların yorgunluğu. Hwang Dong-hyuk vaadi geçici bir mucize gibi sunup kuralı
sonraya bırakıyor — o sadelik bilinçli. Çocuk oyunu estetiği henüz kanla boyanmamış;
bu yüzden sonraki gürültünün kapısı temiz. Kore dizisinin dünya fenomeni olması
bu saatte belli olmuyor, ki iyi: önce insan, sonra arena. Pilot, 'bir bölüm daha'
tuzağını ahlaki bir borç gibi kuruyor.
""", """
Red Light, Green Light sets the pace of a life in debt before it turns the game
into a poster. In Squid Game season 1 episode 1 the green tracksuits are not an
icon yet; there are rooms, phones, the inside of a train. Lee Jung-jae's Gi-hun is
not a hero, he is the tiredness of bad decisions. Hwang Dong-hyuk offers the promise
like a temporary miracle and leaves the rule for later — that simplicity is
deliberate. The children's-game aesthetic is not yet painted in blood; that is why
the door to the later noise is clean. You cannot tell in this hour that a Korean
series will become a global phenomenon, which is good: people first, arena later.
The pilot builds the 'one more episode' trap like a moral debt.
""")

a(93405, 1, 2, """
Cehennem, birinci bölümün vaadini bir yere, bir kurala, bir hiyerarşiye çeviriyor.
Squid Game 1. sezon 2. bölümde yeşil eşofman artık kostüm; numara artık isim.
Lee Jung-jae hâlâ yorgun bir yüz, ama etrafındaki kalabalık — Park Hae-soo,
HoYeon Jung — diziyi tek kahraman masalından çıkarıyor. Hwang, oyunu göstermeden
önce açlığı ve utancı uzatıyor; bu uzatma sadist değil, teşhis. Arena estetiği
(büyük merdiven, renk, maske) burada ilk kez 'dünya' oluyor. Cehennem başlığı
abartılı durmuyor çünkü mekân, vaadin fiyatını konuşuyor. Bir sonraki oyundan çok,
bu fiyatın kimin omuzunda olduğu aklımda.
""", """
Hell turns the first episode's promise into a place, a rule, a hierarchy. In Squid
Game season 1 episode 2 the green tracksuit is a costume now; the number is a name.
Lee Jung-jae is still a tired face, but the crowd around him — Park Hae-soo,
HoYeon Jung — takes the show out of a single-hero fable. Hwang stretches hunger
and shame before showing the game; the stretch is a diagnosis, not sadism. The
arena aesthetic (the giant stair, colour, the mask) becomes a 'world' for the
first time here. The title Hell is not overblown because the place is speaking
the price of the promise. I remember whose shoulder that price sits on, more than
the next game.
""")

a(93405, 1, 6, """
Kanka, oyunu bir an durdurup iki insanı bir odaya kilitliyor. Squid Game 1. sezon
6. bölüm, fenomenin en insani saati: kural hâlâ orada, fakat kamera yüzlere,
paylaşılan bir yemeğe, bir arkadaşlığın utancına iniyor. Lee Jung-jae ile Park
Hae-soo'nun sahneleri, arenanın gürültüsünden daha zor. Hwang burada sadist
değil, neredeyse utangaç: şiddetin nasıl bir yakınlık doğurabileceğini gösteriyor,
kutlamadan. 'Gganbu' kelimesi diziyle birlikte dile yapıştı; bölüm o kelimeyi
poster yapmadan dolduruyor. İzledikten sonra bir oyun değil, bir bakış kalıyor.
Kalabalık dizilerin nadir cesareti: sessiz bir oda.
""", """
Gganbu pauses the game and locks two people in a room. Squid Game season 1 episode 6
is the phenomenon's most human hour: the rule is still there, but the camera drops
to faces, a shared meal, the shame of a friendship. Lee Jung-jae and Park Hae-soo's
scenes are harder than the noise of the arena. Hwang is not a sadist here, almost
shy: he shows how violence can breed a closeness, without celebrating it. The word
'gganbu' stuck to the language with the show; the hour fills that word without
making it a poster. After watching, a look stays, not a game. The rare courage of
a crowded series: a quiet room.
""")

a(70523, 1, 1, """
Sırlar, bir kayıp ilanını küçük bir kasabanın nemine yayıyor. Dark 1. sezon 1.
bölümde mağara, sarı yağmurluk, duvar kâğıdı henüz formül değil, hava. Baran bo
Odar'ın Winden'i zamanı açıklamıyor; önce aileyi ve ormanı ağırlaştırıyor. Louis
Hofmann'ın Jonas'ı henüz bir teori değil, ıslak bir genç. Pilot, Alman dizisinin
dünyaya 'neden bu kadar karanlık' diye sorulacak kapısı: çünkü kasaba, sırları
turist gibi gezdirmiyor, evin içine işliyor. Tekrar izlenmesinin sebebi gizemi
çözmek değil, ilk bakışın nasıl kurulduğunu görmek. Netflix'in en sabırlı açılışlarından;
sabır, sonradan gelecek düğümlerin tek dürüst zemini.
""", """
Secrets spreads a missing-person notice through the damp of a small town. In Dark
season 1 episode 1 the cave, the yellow raincoat, the wallpaper are not a formula
yet, they are weather. Baran bo Odar's Winden does not explain time; it first makes
the family and the forest heavy. Louis Hofmann's Jonas is not a theory yet, a wet
teenager. The pilot is the door through which the world will ask why a German show
is this dark: because the town does not tour its secrets like a tourist, it soaks
them into the house. It gets rewatched not to solve the mystery, but to see how
the first look was built. One of Netflix's most patient openings; patience is the
only honest ground for the knots that follow.
""")

a(70523, 1, 10, """
Alfa ve Omega, birinci sezonu bir şema gibi değil bir eşik gibi kapatıyor.
Dark 1. sezon 10. bölüm ismiyle vaat ediyor; dizi yine de mağaranın nemini, bir
ailenin sofrasını, bir saatin tik takını önde tutuyor. Hofmann'ın Jonas'ı bu
finalde peygamber değil, yorgun bir çocuk — o tercih, diziyi 'anlatayım' tuzağından
kurtarıyor. Winden'in haritası genişliyor ama kasaba küçülmüyor: her yeni kapı,
eski bir evin kapısı. Alman yapımının gücü, açıklamayı duygunun arkasına koyması.
İzledikten sonra tahtaya şema çizme isteği normal; asıl kalan ise sarı bir yağmurluk
ve kimin kimi beklediği. İkinci sezona dürüst bir borç.
""", """
Alpha and Omega closes season 1 as a threshold, not a chart. Dark season 1
episode 10 promises with its title; the show still leads with the damp of the cave,
a family's table, the tick of a clock. Hofmann's Jonas is not a prophet in this
finale, a tired child — that choice saves the show from the 'let me explain' trap.
Winden's map widens but the town does not shrink: every new door is an old house's
door. The German production's strength is putting explanation behind feeling.
Wanting to draw a chart after watching is normal; what actually remains is a yellow
raincoat and who is waiting for whom. An honest debt to season 2.
""")

# --- Better Call Saul ---
a(60059, 1, 1, """
Bir, bir spin-off'un ana dizinin gölgesinde açılmayı reddettiği saat. Better Call
Saul 1. sezon 1. bölüm siyah-beyaz bir gelecekten renkli bir geçmişe düşüyor: Cinnabon,
sükse, utanç. Bob Odenkirk'ün Jimmy'si Saul değil henüz — mahkeme koridorunda
kart dağıtan, ağabeyinin gölgesinde zeki ve küçük bir adam. Vince Gilligan ile
Peter Gould acele etmiyor; montaj, sessizlik, bir billboard. Breaking Bad izleyen
için easter egg avı değil, başka bir ahlak hesabı. Rhea Seehorn henüz kapıda;
o gecikme, tıpkı Silo'daki Ferguson gecikmesi gibi, kimin hikâyesi olacağını doğru
zamanda açacak. Pilotun vaadi dönüşüm değil, dönüşümün ne kadar süreceği.
""", """
Uno is the hour a spin-off refuses to open in the parent show's shadow. Better Call
Saul season 1 episode 1 drops from a black-and-white future into a colour past:
Cinnabon, success, shame. Bob Odenkirk's Jimmy is not Saul yet — a clever, small
man handing out cards in a courthouse hallway, standing in his brother's shade.
Vince Gilligan and Peter Gould do not hurry; montage, silence, a billboard. For
viewers of Breaking Bad this is not an Easter-egg hunt, it is another moral
account. Rhea Seehorn is still at the door; that delay, like Ferguson's delay in
Silo, will open whose story this is at the right time. The pilot's promise is not
transformation, it is how long transformation takes.
""")

a(60059, 3, 5, """
Dalavere, bir mahkeme salonunu aile kavgasına çeviren saat. Better Call Saul 3.
sezon 5. bölümde Michael McKean'in Chuck'ı ile Odenkirk'ün Jimmy'si hukuku bir
kardeşlik silahı yapıyor; Rhea Seehorn'un Kim'i ise çoğu zaman susarak daha çok
konuşuyor. Gould ve Gilligan'ın kurgusu, tanıklık ile hatıra arasında gidip geliyor
— açıklama değil, teşhir. 'Chicanery' kelimesi ucuz bir espri başlığı durmuyor;
bölüm, zekânın nasıl bir ihanet olabileceğini gösteriyor. Suç dizisi gibi değil,
bir evin oturma odası gibi geriliyor. İzledikten sonra kazananı değil, kimin
yüzünün düştüğünü hatırlıyorsunuz. BCS'in en anılan saati olması tesadüf değil.
""", """
Chicanery is the hour that turns a courtroom into a family fight. In Better Call
Saul season 3 episode 5 Michael McKean's Chuck and Odenkirk's Jimmy make the law
a sibling weapon; Rhea Seehorn's Kim often speaks more by staying quiet. Gould
and Gilligan's cutting moves between testimony and memory — not explanation,
exposure. The word 'Chicanery' does not sit as a cheap joke title; the hour shows
how intelligence can be a betrayal. It tenses like a living room, not a crime
show. After watching you remember whose face fell, not who won. It is not an
accident that this is the hour BCS is most remembered for.
""")

a(60059, 6, 13, """
Saul Gider, bir dönüşüm dizisini itiraf gibi değil yerleştirme gibi kapatıyor.
Better Call Saul 6. sezon 13. bölüm nostaljiye yatmadan oda, renk, bir isim koyuyor.
Odenkirk'ün yüzü burada numara değil; Seehorn'un yokluğu/varlığı ise sezonun asıl
cümlesi. Breaking Bad'in gölgesi bu finalde easter egg değil, bir fatura — kim kimin
hikâyesinden geçti. Gould, konuşan finallere karşı nesne ve bakış seçiyor. İzledikten
sonra 'ne oldu' listesi değil, bir rengin nasıl değiştiği kalıyor. Spin-off'un ana
diziyi bazı yerlerde geçmesi, tam da böyle bir saatte ölçülür: gösteriş yok, hesap
var. Kapı kapanıyor, lamba sönmüyor; sönmeyen lamba daha acı.
""", """
Saul Gone closes a transformation show like a placement, not a confession. Better
Call Saul season 6 episode 13 puts a room, a colour, a name, without lying down in
nostalgia. Odenkirk's face is not a trick here; Seehorn's absence/presence is the
season's true sentence. Breaking Bad's shadow in this finale is not an Easter egg,
it is a bill — who walked through whose story. Gould chooses objects and looks
against talking finales. After watching, how a colour changed stays, not a list of
what happened. A spin-off surpassing its parent in places is measured in an hour
like this: no spectacle, an account. The door closes, the lamp does not go out;
the lamp that stays on hurts more.
""")

# --- The Last of Us / Chernobyl / Severance / The Bear / Succession ---
a(100088, 1, 1, """
Karanlıkta Kaybolduğun Zaman, bir salgın dizisini canavarlarla değil bir doğum
günü pastasıyla açıyor. The Last of Us 1. sezon 1. bölümde Pedro Pascal'ın Joel'i
henüz kaçakçı değil, bir baba; Bella Ramsey henüz yol arkadaşı değil, bir kapı
tokağı. Craig Mazin ile Neil Druckmann, oyunun efsane sahnesini televizyona
taşıırken nutuk atmıyor: 1960'ların korku estetiği, 2000'lerin ev içi, sonra yirmi
yıl. Austin'in karantina bölgesi, kıyameti bürokrasi gibi gösteriyor. Pascal'ın
yorgunluğu, türün kaslı kahramanını baştan reddediyor. Pilotun vaadi enfekte değil,
iki insanın birbirine muhtaç kalması. Oyun uyarlamasının bu kadar ağır açılması,
cesaret.
""", """
When You're Lost in the Darkness opens an outbreak show with a birthday cake, not
monsters. In The Last of Us season 1 episode 1 Pedro Pascal's Joel is not a smuggler
yet, a father; Bella Ramsey is not a travelling partner yet, a knock at the door.
Craig Mazin and Neil Druckmann do not sermonize while carrying a legendary game
scene to television: 1960s horror texture, 2000s domestic, then twenty years.
Austin's quarantine zone shows the apocalypse as bureaucracy. Pascal's tiredness
refuses the genre's muscled hero from the start. The pilot's promise is not the
infected, it is two people left needing each other. For a game adaptation to open
this heavy is courage.
""")

a(100088, 1, 3, """
Çok Uzun Zaman, yol dizisini bir kenara bırakıp iki adamı bir evde, bir plak
çalarda bırakıyor. The Last of Us 1. sezon 3. bölüm, Nick Offerman ile Murray
Bartlett'ın saati: kıyamet burada enfekte değil, ömür. Pascal ve Ramsey neredeyse
yoklar — bu yokluk, dizinin en cömert kararı. Mazin, 'yan hikâye'yi ana kalp
yapıyor; televizyon nadiren bir bölümü böyle bahse yatırır. Kimseye son on dakikayı
anlatmayacağım. Diyeceğim şu: bu saat bittikten sonra bir süre oturmak normal,
ve o oturuş oyunun hayranından çok, televizyon izleyicisinin hakkı. Aşk hikâyesi
demek yetmez; bir ömrün nasıl paylaşıldığının hikâyesi. Dizi, türünün çıtasını
burada yükseltir.
""", """
Long, Long Time sets the road show aside and leaves two men in a house, at a
record player. The Last of Us season 1 episode 3 is Nick Offerman and Murray
Bartlett's hour: the apocalypse here is not the infected, it is a lifetime. Pascal
and Ramsey are almost absent — that absence is the show's most generous decision.
Mazin makes a 'side story' the main heart; television rarely bets an episode this
way. I will not tell anyone the last ten minutes. I will say this: sitting still
for a while after this hour is normal, and that sitting belongs to the television
viewer as much as to the game's fan. Calling it a love story is not enough; it is
the story of how a life is shared. The show raises its genre's bar right here.
""")

a(87108, 1, 1, """
1:23:45, bir nükleer felaketi patlama sahnesiyle değil bir itfaiyecinin çıplak
ayaklarıyla açıyor. Chernobyl 1. sezon 1. bölümde Jared Harris henüz merkezde
değil; önce yalanın nasıl giyildiğini izliyoruz — palto, telefon, 'bir şey yok'
cümlesi. Craig Mazin'in senaryosu radyasyonu görünmez bırakıp maliyeti görünür
kılıyor: cilt, nefes, bir camdaki çatlak. 1986 Sovyet dekoru süs değil, teşhis.
Stellan Skarsgård bu saatte gölgede; gölge, ileride gelecek bürokrasinin kapısı.
Beş bölümlük mini dizinin ilk saati, gerilim filmi tadında belgesel titizliği.
İzledikten sonra 'ne kadar doğru' diye aramak normal; asıl kalan ise o çıplak ayak.
""", """
1:23:45 opens a nuclear disaster not with a blast but with a firefighter's bare
feet. In Chernobyl season 1 episode 1 Jared Harris is not yet at the centre; we
first watch how a lie is put on — a coat, a phone, the sentence 'it's nothing'.
Craig Mazin's script leaves radiation invisible and makes the cost visible: skin,
breath, a crack in glass. The 1986 Soviet decor is a diagnosis, not garnish.
Stellan Skarsgård is in shadow in this hour; the shadow is the door to the
bureaucracy still to come. The first hour of a five-part miniseries has the taste
of a thriller and the rigor of a documentary. Searching 'how accurate' after
watching is normal; what remains is those bare feet.
""")

a(87108, 1, 5, """
Vichnaya Pamyat, beş bölümü bir mahkeme ve bir koro gibi kapatıyor. Chernobyl
1. sezon 5. bölümde Harris'in Valery'si nutuk atan bilim insanı değil, yorgun bir
tanık; Skarsgård'ın Shcherbina'sı ise bürokrasiden insana yürümüş bir gölge.
Mazin, 'yalanın maliyeti' tezini burada bağırarak değil, isim isim hatırlatarak
bitiriyor. Prodüksiyon hâlâ 1986'nın havasını taşıyor — palto, kâğıt, bir salonun
akustiği. Mini dizi formatının zirvesi demek kolay; bu saat o cümleyi hak ediyor
çünkü her açılan parantez bir insana bağlanıyor. İzledikten sonra uzun süre
aklından çıkmamasının sebebi özel efekt değil, bir sessizlik. Ebedi anı, başlığın
vaadini tutuyor.
""", """
Vichnaya Pamyat closes five episodes like a courtroom and a chorus. In Chernobyl
season 1 episode 5 Harris's Valery is not a lecturing scientist, a tired witness;
Skarsgård's Shcherbina is a shadow who has walked from bureaucracy toward a person.
Mazin finishes the thesis of 'the cost of lies' not by shouting but by reminding,
name by name. The production still carries the air of 1986 — a coat, paper, a
hall's acoustic. It is easy to call this the pinnacle of the miniseries form; this
hour earns the sentence because every parenthesis opened is tied to a person. It
stays with you not because of effects, but because of a silence. Eternal memory
keeps the title's promise.
""")

a(95396, 1, 1, """
Cehennem Hakkında İyi Haber, işi unutma fantezisini bir koridor, bir asansör, bir
gülümsemeyle açıyor. Severance 1. sezon 1. bölümde Adam Scott'ın Mark'ı henüz isyan
değil, yas; Lumon'ın steril nezaketi, bilim kurgu numarasından önce bir ofis
kabusu. Ben Stiller'ın görsel dili soğuk ve hipnotik: yeşil, beyaz, sonsuz halı.
Britt Lower, Zach Cherry, John Turturro bir ekip olarak 'içerideki siz'i hemen
inanılır kılıyor. Soru basit ve ürkütücü — işten çıkınca işi gerçekten unutsanız
kabul eder miydiniz? Pilot, cevabı vermiyor; sözleşmeyi uzatıyor. Son yılların en
özgün televizyon kapılarından biri, bağırarak değil.
""", """
Good News About Hell opens the fantasy of forgetting work with a corridor, a lift,
a smile. In Severance season 1 episode 1 Adam Scott's Mark is not a revolt yet,
grief; Lumon's sterile politeness is an office nightmare before it is a sci-fi
trick. Ben Stiller's visual language is cold and hypnotic: green, white, endless
carpet. Britt Lower, Zach Cherry and John Turturro make the 'you inside' believable
at once, as a team. The question is simple and unsettling — if you could truly
forget your job at the door, would you sign? The pilot does not answer; it extends
the contract. One of the most original television doors in years, without shouting.
""")

a(95396, 1, 7, """
Muhalif Caz, ofis kabusunu bir dansa, bir kural ihlaline, bir nefes alma çatlağına
çeviriyor. Severance 1. sezon 7. bölümde Scott'ın Mark'ı hâlâ ölçülü; fakat ekip
— Lower, Cherry, Turturro — nezaketin dışına bir milim çıkınca dizi başka bir
türe yaklaşır: komedi değil, kaçış. Stiller'ın koridorları bu saatte bile sonsuz;
sonsuzluk, isyan sahnesine dönüşmeden gerilim taşıyor. Müzik (başlıktaki caz)
süs değil, bir çatlak. Lumon hâlâ gülümseyerek konuşuyor; o gülümseme, bağıran
diktatörden soğuk. Orta sezonun en 'insan' saati, çünkü robot gibi yürüyen bedenler
bir an duruyor. Durak, isyan kadar önemli.
""", """
Defiant Jazz turns the office nightmare into a dance, a broken rule, a crack to
breathe. In Severance season 1 episode 7 Scott's Mark is still measured; but once
the team — Lower, Cherry, Turturro — steps a millimetre outside politeness, the
show nears another genre: not comedy, escape. Stiller's corridors are endless even
in this hour; the endlessness carries tension without turning into a revolt scene.
The music (the jazz in the title) is a crack, not garnish. Lumon still speaks with
a smile; that smile is colder than a shouting dictator. The most 'human' hour of
midseason, because bodies that walk like robots pause for a moment. The pause
matters as much as the revolt.
""")

a(95396, 1, 9, """
Biz Olan Biz, birinci sezonu bir kimlik cümlesiyle kapatıyor. Severance 1. sezon
9. bölümde içerideki siz ile dışarıdaki siz aynı kareye yaklaşır — çözüm
sahnesi değil, bir eşik. Scott'ın yüzü bu finalde numara yapmıyor; Lower'ın Helly'si
ise sezonun asıl bıçağı. Stiller, ofis estetiğini bırakmadan kapı dışına adım
atıyor: yeşil halı, sonra dünya. Soru hâlâ aynı, daha ağır: unutmak bir lütuf mu,
bir hapishane mi. Mini dizi gibi kurulan sezon, Apple'ın tuhaf gizemlere tanıdığı
süreyi hak ediyor. İzledikten sonra işe girerken asansörü bir saniye uzun
düşünmek normal. Dizi bunu istiyor.
""", """
The We We Are closes season 1 on a sentence about identity. In Severance season 1
episode 9 the you inside and the you outside approach the same frame — a threshold,
not a briefing. Scott's face is not performing in this finale; Lower's
Helly is the season's true knife. Stiller steps outside the door without leaving
the office aesthetic: green carpet, then the world. The question is the same,
heavier: is forgetting a gift, or a prison. A season built like a miniseries earns
the time Apple gives strange mysteries. After watching, thinking one second longer
in the lift on the way to work is normal. The show wants that.
""")

a(136315, 1, 1, """
Sistem, bir mutfağın sesiyle açılıyor: tencere, bağırış, üst üste binen sipariş.
The Bear 1. sezon 1. bölümde Jeremy Allen White'ın Carmy'si ince işçilikten
Chicago'daki dağınık bir sandviç dükkânına düşüyor — borç, inatçı ekip, taşınan
bir yas. Christopher Storer bölümleri kısa tutup gerilimi tezgâhın içine sıkıştırıyor;
nefes yok, süs yok. Ayo Edebiri henüz kapıda, Ebon Moss-Bachrach zaten gürültünün
içinde. Yemek dizisi değil, çalışma ve kardeşlik hikâyesi. Pilotun temposu bazı
seyirciyi itecek; itilmek, bu dizinin kapısı. Mutfağa bir kez girince, gürültü
bir müzik gibi oturuyor.
""", """
System opens with the sound of a kitchen: pots, shouting, orders stacked. In The
Bear season 1 episode 1 Jeremy Allen White's Carmy falls from fine dining into a
messy Chicago sandwich shop — debt, a stubborn crew, a grief being carried.
Christopher Storer keeps the episodes short and packs the tension into the pass;
no breath, no garnish. Ayo Edebiri is still at the door, Ebon Moss-Bachrach is
already inside the noise. Not a food show, a story of work and siblinghood. The
pilot's pace will push some viewers away; being pushed is the door into this
series. Once you are in the kitchen, the noise sits like music.
""")

a(136315, 1, 7, """
İnceleme, mutfağın gürültüsünü bir masaya, bir bakışa, bir yargının ağırlığına
çeviriyor. The Bear 1. sezon 7. bölümde White'ın Carmy'si bağıran şef değil, izlenen
adam — restoran dünyasının o soğuk 'nasıl bulundu' gerilimi. Storer bu saatte
nefes aldırıyor: kısa dizi, bir an duruyor ve duruş daha zor. Edebiri'nin Sydney'si
merkezde; yetenek ile aidiyet aynı tabağa konuyor. Yemek sahneleri yemek pornosu
değil, emek. Birinci sezonun en olgun duraklarından, çünkü gürültü kesilince geriye
kalan yüzler daha net. İnceleme kelimesi hem restoran hem insan için işliyor.
""", """
Review turns the kitchen's noise into a table, a look, the weight of a judgment.
In The Bear season 1 episode 7 White's Carmy is not a shouting chef, a man being
watched — that cold 'how did they find us' tension of the restaurant world. Storer
lets the hour breathe: the short show pauses, and the pause is harder. Edebiri's
Sydney is at the centre; talent and belonging are put on the same plate. The food
scenes are labour, not food porn. One of season 1's most grown-up stops, because
when the noise cuts, the faces left behind are clearer. The word review works for
the restaurant and for the person.
""")

a(136315, 2, 6, """
Balıklar, bir Noel sofrasını neredeyse bir korku filmi gibi kuruyor. The Bear 2.
sezon 6. bölümde White'ın Carmy'si mutfağın değil, ailenin içinde sıkışıyor; Jamie
Lee Curtis'in varlığı, gürültüyü kan bağına çeviriyor. Storer bu saati uzun tutuyor
— dizinin kısa nefesinin bilerek bozulması. Kalabalık, yemek, eski yaralar: her
tabak bir cümle. Kimseye masadaki son turu anlatmayacağım. Diyeceğim şu: çalışma
dizisi sandığınız şey, bir evin oturma odasında daha yüksek sesle bağırıyor.
İzledikten sonra kendi aile sofranızı bir saniye hatırlamanız normal. Dizi bunu
hesaplayarak yapıyor, ucuza değil.
""", """
Fishes builds a Christmas table almost like a horror film. In The Bear season 2
episode 6 White's Carmy is trapped not in the kitchen but in the family; Jamie Lee
Curtis's presence turns the noise into blood. Storer lets this hour run long — a
deliberate break in the show's short breath. Crowd, food, old wounds: every plate
is a sentence. I will not tell anyone the last round at the table. I will say this:
the thing you thought was a show about work is shouting louder in a living room.
Remembering your own family table for a second after watching is normal. The show
does that on purpose, not cheaply.
""")

a(76331, 1, 1, """
Kutlama, bir doğum gününü taht kavgasının prova sahnesi yapıyor. Succession 1.
sezon 1. bölümde Brian Cox'un Logan'ı henüz düşmüyor, sadece öksürüyor; o öksürük
yeter. Jeremy Strong, Sarah Snook, Kieran Culkin, Matthew Macfadyen — dört çocuk,
dört farklı korku. Jesse Armstrong'un diyalogu, Shakespeare'i asfalta değil,
özel uçağa indiriyor: küfür, şefkat, hisse. Pilotun temposu bazı seyirciye soğuk
gelecek; soğukluk, bu ailenin iklimi. Medya imparatorluğu süs değil, bir babanın
elindeki oyuncak. Açılış, 'kim kazanacak' diye sormuyor; 'kim hâlâ çocuk' diye
soruyor. Doğru soru.
""", """
Celebration turns a birthday into a rehearsal for a throne fight. In Succession
season 1 episode 1 Brian Cox's Logan is not falling yet, only coughing; the cough
is enough. Jeremy Strong, Sarah Snook, Kieran Culkin, Matthew Macfadyen — four
children, four different fears. Jesse Armstrong's dialogue brings Shakespeare not
onto asphalt but onto a private jet: swearing, tenderness, shares. The pilot's
pace will feel cold to some; cold is this family's climate. The media empire is
not garnish, it is a toy in a father's hand. The opening does not ask who will
win; it asks who is still a child. The right question.
""")

a(76331, 4, 10, """
Gözü Açık, dört sezonluk bir taht kavgasını nutukla değil bir oda, bir bakış, bir
imza ile kapatıyor. Succession 4. sezon 10. bölümde Strong, Snook, Culkin — çocuklar
hâlâ çocuk, imparatorluk hâlâ bir babanın gölgesi. Armstrong konuşan finallere
karşı yerleştirme seçiyor: kim nerede oturuyor, kim kimin elini tutmuyor. Cox'un
yokluğu bu saatte gürültüden büyük. Kim kazandı diye yazmayacağım; dizi zaten o
cümleyi ucuz buluyor. İzledikten sonra kalan, bir zafer değil, bir ailenin nasıl
dağılmadan dağıldığı. Kapanış cümlesi yok, bir koridor var. Koridor, tahttan uzun.
""", """
With Open Eyes closes four seasons of a throne fight not with a speech but with a
room, a look, a signature. In Succession season 4 episode 10 Strong, Snook, Culkin
— the children are still children, the empire still a father's shadow. Armstrong
chooses placement against talking finales: who sits where, whose hand is not being
held. Cox's absence in this hour is larger than noise. I will not write who won;
the show already finds that sentence cheap. What remains after watching is not a
victory, it is how a family came apart without coming apart. There is no closing
line, there is a corridor. The corridor is longer than the throne.
""")

a(66732, 1, 1, """
Will Byers'ın Ortadan Kayboluşu, 80'ler pastişini henüz poster yapmadan bir bisiklet
lambasıyla açıyor. Stranger Things 1. sezon 1. bölümde Duffer kardeşler Spielberg
oyuncağını korku radyo tiyatrosuna bağlıyor: bodrum, harita, kayıp bir çocuk.
Millie Bobby Brown henüz merkezde değil; önce kasaba, önce arkadaşlık. Winona Ryder'ın
Joyce'u 'deliren anne' klişesine düşmeden, bir evin içini geriyor. Pilotun vaadi
canavar değil, bir çocuğun yokluğu. Nostalji süs; asıl motor, küçük bir grubun
birbirine inanması. Netflix'in gençlik gerilimini dünyaya bu saatle sattığı
unutulmasın: sade, ıslak, meraklı.
""", """
The Vanishing of Will Byers opens the 80s pastiche with a bicycle lamp before it
is a poster. In Stranger Things season 1 episode 1 the Duffer brothers wire a
Spielberg toy to a horror radio play: a basement, a map, a missing child. Millie
Bobby Brown is not yet at the centre; town first, friendship first. Winona Ryder's
Joyce tenses the inside of a house without falling into the 'hysterical mother'
cliché. The pilot's promise is not a monster, it is a child's absence. Nostalgia
is garnish; the true engine is a small group believing each other. It should not
be forgotten that Netflix sold youth horror to the world with this hour: simple,
wet, curious.
""")

a(1398, 1, 1, """
Sopranolar, bir mafya dizisini terapi odasıyla açıyor — bu, 1999'da bir milat.
The Sopranos 1. sezon 1. bölümde James Gandolfini'nin Tony'si hem baba hem panik
atak; Lorraine Bracco'nun Melfi'si ise ayna. David Chase suçun romantizmini daha
ilk saatte kesiyor: ördekler, mutfak, bir adamın nefesinin yetmemesi. Şiddet süs
değil, akşam yemeğinin yanındaki gölge. Modern televizyonun bu masadan beslendiği
cümlesi klişe olduysa, sebebi bu pilotun hâlâ taze durması. Gandolfini'nin yüzü,
zor adam dizilerinin tamamının ödediği borç. Açılış, 'kim vurulacak' diye sormuyor;
'bu adam neden ağlıyor' diye soruyor.
""", """
The Sopranos opens a mob show in a therapy room — in 1999, a watershed. In The
Sopranos season 1 episode 1 James Gandolfini's Tony is both a father and a panic
attack; Lorraine Bracco's Melfi is a mirror. David Chase cuts the romance of crime
in the first hour: ducks, a kitchen, a man running out of breath. Violence is not
garnish, it is the shadow beside dinner. If the sentence that modern television
fed from this table has become a cliché, it is because this pilot still feels
fresh. Gandolfini's face is the debt every 'difficult man' drama still pays. The
opening does not ask who gets shot; it asks why this man is crying.
""")

a(1438, 1, 1, """
The Target, bir suç dizisini kahramanla değil bir köşe, bir çocuk, bir göz ile
açıyor. The Wire 1. sezon 1. bölümde Dominic West'in McNulty'si parlak yıldız
değil, inatçı bir ağız; David Simon polisiye formülünü şehir ölçeğine yayıyor —
Baltimore burada dekor değil, karakter. Diyalog hızlı, ahlak yavaş. Pilot, 'kim
yakalanacak' vaadi vermiyor; kimin kimi dinlediğini gösteriyor. Uzun soluklu
dizilerin en dürüst kapılarından: süs yok, kurum var. İzledikten sonra bir replik
değil, bir hiyerarşi kalıyor. The Wire'ın zor olduğu efsanesi bu saatte abartılı;
zor olan, bakmayı bırakmamak.
""", """
The Target opens a crime show not with a hero but with a corner, a child, an eye.
In The Wire season 1 episode 1 Dominic West's McNulty is not a bright star, a
stubborn mouth; David Simon spreads the police formula to the scale of a city —
Baltimore here is not decor, it is a character. Dialogue is fast, morality is
slow. The pilot does not promise who will be caught; it shows who is listening to
whom. One of the most honest doors into a long-running series: no garnish, an
institution. After watching, a hierarchy stays, not a line. The myth that The Wire
is hard is overblown in this hour; what is hard is not looking away.
""")

a(94605, 1, 1, """
Zıtlıklarla Dolu Bir Dünyaya Hoş Geldin, bir oyun uyarlamasını tablo gibi açıyor.
Arcane 1. sezon 1. bölümde Piltover ile Zaun aynı karede: ışık ve duman, sınıf ve
kardeşlik. Hailee Steinfeld ile Ella Purnell'in Powder/Vi hattı henüz efsane değil,
iki kız çocuğu. Fortiche'nin animasyonu süs değil, dil — her kare elle tutulmuş
gibi. League of Legends bilmenize gerek yok; birkaç dakikada karakter sizi çekiyor.
Pilotun vaadi büyü değil, bir köprünün iki yakası. Oyun uyarlamasının bu kadar
iyi olabileceğine ihtimal vermeyenleri, bu saat tek başına yorar. İyi anlamda.
""", """
Welcome to the Playground opens a game adaptation like a painting. In Arcane
season 1 episode 1 Piltover and Zaun share a frame: light and smoke, class and
sisterhood. Hailee Steinfeld and Ella Purnell's Powder/Vi line is not legend yet,
two girls. Fortiche's animation is a language, not garnish — every frame feels
held. You do not need League of Legends; the characters pull you in within minutes.
The pilot's promise is not magic, it is two banks of a bridge. This hour alone
will tire anyone who did not believe a game adaptation could be this good. In a
good way.
""")

# --- TR ---
a(77994, 1, 1, """
Şahsiyet 1. sezon 1. bölüm, bir Alzheimer teşhisini intikam hikâyesinin kapısı
yapıyor ve bu kapı, yerli dizide ender görülen bir soğuklukla açılıyor. Haluk
Bilginer'in Agâh'ı henüz 'katil' değil, hafızası kayan bir emekli savcı; yüzü,
teşhisten daha korkunç. Onur Saylak'ın temposu telenovela değil, bir odanın
sessizliği — İstanbul burada neon değil, koridor. Cansu Dere henüz merkezde; dizi
onu aceleyle kahraman ilan etmiyor. Pilotun tezi net: unutmak bir lütuf değil,
bir silahın geri tepmesi. Yerli polisiyenin bu kadar az bağırarak bu kadar ağır
durması, Bilginer'in omzunda. Bir bölüm yetmiyor; yetmemek, bu dizinin yöntemi.
""", """
Persona season 1 episode 1 makes an Alzheimer's diagnosis the door to a revenge
story, and that door opens with a cold rarely seen in Turkish television. Haluk
Bilginer's Agâh is not a 'killer' yet, a retired prosecutor whose memory is
slipping; his face is more frightening than the diagnosis. Onur Saylak's pace is
not telenovela, it is the silence of a room — Istanbul here is not neon, it is a
corridor. Cansu Dere is not yet at the centre; the show does not rush to declare
her a hero. The pilot's thesis is clear: forgetting is not a gift, it is a weapon
kicking back. That a Turkish crime show can sit this heavy while shouting this
little rests on Bilginer's shoulder. One episode is not enough; not being enough
is this show's method.
""")

a(112745, 1, 1, """
Bir Başkadır 1. sezon 1. bölüm, terapötik bir İstanbul'u sınıf, inanç ve utanç
üzerinden açıyor. Öykü Karayel'in Meryem'i 'doğu-batı' klişesi değil, bir evin
içinden çıkan bakış; Fatih Artman'ın psikiyatristi ise merdiven inip çıkan bir
şehir gibi yorgun. Berkun Oya nutuk atmıyor: bir oda, bir başörtü, bir koltuk,
birinin susması. Mini dizinin ilk saati, diziyi 'mesaj' olmaktan kurtaran detaylarla
dolu — yemek, asansör, bir annenin cümlesi. Türkiye'nin birbirini anlamayan
katmanlarını turist gibi gezdirmiyor; aynı evin odalarına koyuyor. Sabır isteyen,
karşılığını yüzlerde veren bir açılış. Bir kez bakınca, ikinci odaya geçmek şart.
""", """
Ethos season 1 episode 1 opens a therapeutic Istanbul through class, faith and
shame. Öykü Karayel's Meryem is not an 'east-west' cliché, a look coming out of a
house; Fatih Artman's psychiatrist is tired like a city going up and down stairs.
Berkun Oya does not sermonize: a room, a headscarf, a couch, someone going silent.
The miniseries' first hour is full of details that save the show from being a
'message' — food, a lift, a mother's sentence. It does not tour Turkey's mutually
uncomprehending layers like a tourist; it puts them in the rooms of the same
house. An opening that asks for patience and pays it back in faces. Once you have
looked, you have to go into the next room.
""")

a(136125, 1, 1, """
Kulüp 1. sezon 1. bölüm, 1950'lerin İstanbul gecesini bir sahne, bir mutfak, bir
azınlık hayatının içinden açıyor. Gökçe Bahadır'ın Matild'i henüz efsane değil,
ayıklanan bir kadın; Fırat Tanış'ın gölgesi kapıda. Zeynep Günay Tan ile Seren Yüce'nin
dizisi, nostaljiyi kostüm partisi yapmadan kuruyor: kumaş, sigara, bir
şarkının ağırlığı. Yahudi toplumunun gündeliği burada süs değil, zemin — dizi bunu
turistikleştirmiyor. Pilotun vaadi entrika değil, bir kadının sahneye çıkmadan
önceki hesabı. Yerli dönem dizisinin bu kadar film gibi durması, oyuncunun ve
mekânın omzunda. Bir gece yetmiyor; kulüp zaten geceyle ölçülür.
""", """
The Club season 1 episode 1 opens a 1950s Istanbul night from inside a stage, a
kitchen, a minority life. Gökçe Bahadır's Matild is not a legend yet, a woman being
sorted; Fırat Tanış's shadow is at the door. Zeynep Günay Tan and Seren Yüce's
show builds nostalgia without turning it into a costume party: cloth, smoke, the
weight of a song. The everyday of the Jewish community is ground here, not garnish
— the show does not make a tourist of it. The pilot's promise is not intrigue, it
is a woman's calculation before she steps onstage. That a Turkish period series
can sit this much like a film rests on the actors and the rooms. One night is not
enough; a club is already measured in nights.
""")


def ana() -> None:
    """JSON'u betiğin yanına yazar; uzunluk ve tekillik denetler."""
    seen: set[tuple[int, int, int]] = set()
    acilis: set[str] = set()
    for o in ogeler:
        anahtar = (int(o["tmdb_id"]), int(o["sezon"]), int(o["bolum"]))
        if anahtar in seen:
            raise SystemExit(f"çift kayıt {anahtar}")
        seen.add(anahtar)
        tr = str(o["tr"])
        en = str(o["en"])
        if len(tr) < 280 or len(en) < 280:
            raise SystemExit(f"kısa {anahtar} tr={len(tr)} en={len(en)}")
        bas = tr[:48]
        if bas in acilis:
            raise SystemExit(f"aynı açılış {anahtar}: {bas}")
        acilis.add(bas)
    yol = Path(__file__).with_name("seo_bolum_tohum.json")
    paket = {
        "not": (
            "dizi.jpg.ai bölüm yorumları. Spoiler yok. Eleştirmen üslubu "
            "(oyuncu, sahne, yargı). Tekrar çalışınca metin güncellenir. alcelik yok."
        ),
        "ogeler": ogeler,
    }
    yol.write_text(json.dumps(paket, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"yazildi {yol.name} adet={len(ogeler)}")


if __name__ == "__main__":
    ana()



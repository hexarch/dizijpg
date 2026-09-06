// ÜRETİLMİŞ DOSYA — ELLE DÜZENLEME.
// Kaynak: backend/seo_dil.js  ·  Üretici: araclar/seo_basliklari_uret.mjs
// Yeniden üret:  node araclar/seo_basliklari_uret.mjs
//
// 46 dilin ANA SAYFA başlığı ve açıklaması. SSR'nin bota bastığı metnin
// aynısıdır — insan da aynı başlığı görsün diye (bkz. üreticinin başlığı).

/// Dil kodu -> (sayfa başlığı, meta açıklama).
const Map<String, (String, String)> seoAnaMetin = {
  'am': (
    'የተከታታይ ፊልምና ፊልም መከታተያ መተግበሪያ – ነጻ | dizi.jpg',
    'ነጻ የተከታታይ ፊልም መከታተያ መተግበሪያ፦ ያዩትን እያንዳንዱን ክፍል መዝግቡ፣ የፊልም ዝርዝር ይያዙ፣ ደረጃና አስተያየት ይስጡ፣ ጓደኞችዎ ምን እንደሚመለከቱ ይዩ።',
  ),
  'ar': (
    'تطبيق تتبع المسلسلات والأفلام – مجاني | dizi.jpg',
    'تطبيق مجاني لتتبع المسلسلات: سجّل كل حلقة تشاهدها، ونظّم قائمة أفلامك، وقيّم واكتب مراجعات، وشاهد ما يتابعه أصدقاؤك. على الويب وأندرويد.',
  ),
  'az': (
    'Serial və film izləmə tətbiqi – Pulsuz | dizi.jpg',
    'Pulsuz serial izləmə tətbiqi: izlədiyin hər epizodu qeyd et, film siyahısı apar, qiymətləndir və rəy yaz, dostlarının nə izlədiyini gör. Veb və Android.',
  ),
  'bg': (
    'Проследяване на сериали и филми – безплатно | dizi.jpg',
    'Безплатно приложение за проследяване на сериали: отмятай изгледаните епизоди, води списък с филми, оценявай и ревюирай, виж какво гледат приятелите ти.',
  ),
  'bn': (
    'সিরিজ ও সিনেমা ট্র্যাকার অ্যাপ – ফ্রি | dizi.jpg',
    'ফ্রি সিরিজ ট্র্যাকার অ্যাপ: দেখা প্রতিটি পর্ব লিখে রাখুন, সিনেমার তালিকা বানান, রেটিং ও রিভিউ দিন এবং বন্ধুরা কী দেখছে তা দেখুন। ওয়েব ও অ্যান্ড্রয়েড।',
  ),
  'cs': (
    'Sledování seriálů a filmů – aplikace zdarma | dizi.jpg',
    'Aplikace zdarma na sledování seriálů: odškrtávej zhlédnuté díly, veď si seznam filmů, hodnoť a recenzuj a sleduj, co koukají tví přátelé.',
  ),
  'da': (
    'Hold styr på serier og film – gratis app | dizi.jpg',
    'Gratis app til at holde styr på serier: kryds hvert afsnit af, før en filmliste, giv karakterer og anmeldelser, og se hvad dine venner ser på.',
  ),
  'de': (
    'Serien-Tracker App – Serien & Filme verfolgen | dizi.jpg',
    'Kostenloser Serien-Tracker: jede gesehene Folge eintragen, Filme-Watchlist führen, bewerten und kommentieren und sehen, was Freunde schauen.',
  ),
  'el': (
    'Παρακολούθηση σειρών και ταινιών – Δωρεάν | dizi.jpg',
    'Δωρεάν εφαρμογή παρακολούθησης σειρών: σημείωσε κάθε επεισόδιο που είδες, κράτα λίστα ταινιών, βαθμολόγησε και σχολίασε, δες τι βλέπουν οι φίλοι σου.',
  ),
  'en': (
    'TV Show Tracker – Track Series & Movies You Watch | dizi.jpg',
    'Free TV show tracker: log every episode you watch, keep a movie watchlist, rate and review, and see what your friends are watching. Web and Android.',
  ),
  'es': (
    'App para seguir series y películas – Gratis | dizi.jpg',
    'App gratuita para seguir series: registra cada episodio que ves, guarda tu lista de películas, puntúa y comenta, y descubre qué ven tus amigos. Web y Android.',
  ),
  'fa': (
    'برنامه پیگیری سریال و فیلم – رایگان | dizi.jpg',
    'برنامه رایگان پیگیری سریال: هر قسمتی را که می‌بینید ثبت کنید، فهرست فیلم بسازید، امتیاز و نقد بنویسید و ببینید دوستانتان چه تماشا می‌کنند. وب و اندروید.',
  ),
  'fi': (
    'Sarjaseuranta ja elokuvapäiväkirja – ilmainen | dizi.jpg',
    'Ilmainen sarjaseurantasovellus: merkitse jokainen katsomasi jakso, pidä elokuvalistaa, anna arvosanoja ja arvosteluja ja katso, mitä kaverisi katsovat.',
  ),
  'fil': (
    'Subaybayan ang serye at pelikula – Libreng app | dizi.jpg',
    'Libreng app na pansubaybay ng serye: markahan ang bawat napanood na episode, gumawa ng listahan ng pelikula, mag-rate at mag-review. Web at Android.',
  ),
  'fr': (
    'Suivi de séries et films – Application gratuite | dizi.jpg',
    'Application gratuite de suivi de séries : note chaque épisode vu, gère ta liste de films, donne notes et avis et vois ce que regardent tes amis.',
  ),
  'gu': (
    'શ્રેણી અને ફિલ્મ ટ્રેકર એપ – મફત | dizi.jpg',
    'મફત શ્રેણી ટ્રેકર એપ: જોયેલો દરેક એપિસોડ નોંધો, ફિલ્મોની યાદી બનાવો, રેટિંગ અને સમીક્ષા આપો અને મિત્રો શું જુએ છે તે જુઓ.',
  ),
  'he': (
    'מעקב אחר סדרות וסרטים – אפליקציה חינמית | dizi.jpg',
    'אפליקציה חינמית למעקב אחר סדרות: סמנו כל פרק שצפיתם בו, נהלו רשימת סרטים, דרגו וכתבו ביקורות וראו במה החברים שלכם צופים. בדפדפן ובאנדרואיד.',
  ),
  'hi': (
    'सीरीज़ और फ़िल्म ट्रैकर ऐप – मुफ़्त | dizi.jpg',
    'मुफ़्त सीरीज़ ट्रैकर ऐप: देखा हुआ हर एपिसोड दर्ज करें, फ़िल्मों की वॉचलिस्ट बनाएँ, रेटिंग और समीक्षा दें और देखें कि आपके दोस्त क्या देख रहे हैं।',
  ),
  'hu': (
    'Sorozat- és filmkövető alkalmazás – Ingyenes | dizi.jpg',
    'Ingyenes sorozatkövető alkalmazás: jelöld a látott epizódokat, vezess filmlistát, értékelj és írj véleményt, és nézd meg, mit néznek a barátaid.',
  ),
  'id': (
    'Aplikasi pelacak serial dan film – Gratis | dizi.jpg',
    'Aplikasi pelacak serial gratis: tandai setiap episode yang kamu tonton, susun daftar film, beri nilai dan ulasan, dan lihat tontonan teman-temanmu.',
  ),
  'it': (
    'App per seguire serie TV e film – Gratis | dizi.jpg',
    'App gratuita per seguire serie TV: segna ogni episodio visto, gestisci la lista dei film, vota e commenta e scopri cosa guardano i tuoi amici.',
  ),
  'ja': (
    'ドラマ・映画の視聴記録アプリ – 無料 | dizi.jpg',
    '無料の視聴記録アプリ。観たドラマのエピソードを記録し、映画のウォッチリストを管理、評価やレビューを投稿。友だちが何を観ているかもわかります。',
  ),
  'kn': (
    'ಸರಣಿ ಮತ್ತು ಸಿನಿಮಾ ಟ್ರ್ಯಾಕಿಂಗ್ ಆ್ಯಪ್ – ಉಚಿತ | dizi.jpg',
    'ಉಚಿತ ಸರಣಿ ಟ್ರ್ಯಾಕಿಂಗ್ ಆ್ಯಪ್: ನೋಡಿದ ಪ್ರತಿ ಸಂಚಿಕೆಯನ್ನು ದಾಖಲಿಸಿ, ಸಿನಿಮಾ ಪಟ್ಟಿ ಮಾಡಿ, ರೇಟಿಂಗ್ ಮತ್ತು ವಿಮರ್ಶೆ ನೀಡಿ, ಸ್ನೇಹಿತರು ಏನು ನೋಡುತ್ತಿದ್ದಾರೆ ಎಂದು ನೋಡಿ.',
  ),
  'ko': (
    '드라마·영화 시청 기록 앱 – 무료 | dizi.jpg',
    '무료 시청 기록 앱: 본 드라마의 모든 에피소드를 기록하고 영화 위시리스트를 관리하며 평점과 리뷰를 남기고 친구들이 무엇을 보는지 확인하세요.',
  ),
  'ml': (
    'പരമ്പര, സിനിമ ട്രാക്കിംഗ് ആപ്പ് – സൗജന്യം | dizi.jpg',
    'സൗജന്യ പരമ്പര ട്രാക്കിംഗ് ആപ്പ്: കണ്ട ഓരോ എപ്പിസോഡും രേഖപ്പെടുത്തുക, സിനിമാ പട്ടിക ഉണ്ടാക്കുക, റേറ്റിംഗും നിരൂപണവും നൽകുക, സുഹൃത്തുക്കൾ കാണുന്നത് അറിയുക.',
  ),
  'mr': (
    'मालिका आणि चित्रपट ट्रॅकर ॲप – मोफत | dizi.jpg',
    'मोफत मालिका ट्रॅकर ॲप: पाहिलेला प्रत्येक भाग नोंदवा, चित्रपटांची यादी करा, रेटिंग आणि परीक्षण द्या आणि मित्र काय पाहत आहेत ते पाहा.',
  ),
  'ms': (
    'Aplikasi penjejak siri dan filem – Percuma | dizi.jpg',
    'Aplikasi penjejak siri percuma: tandakan setiap episod yang anda tonton, susun senarai filem, beri penilaian dan ulasan, dan lihat tontonan rakan anda.',
  ),
  'my': (
    'ဇာတ်လမ်းတွဲနှင့် ရုပ်ရှင် မှတ်တမ်းအက်ပ် – အခမဲ့ | dizi.jpg',
    'အခမဲ့ ဇာတ်လမ်းတွဲ မှတ်တမ်းအက်ပ် — ကြည့်ပြီးသော အပိုင်းတိုင်းကို မှတ်တမ်းတင်ပါ၊ ရုပ်ရှင်စာရင်းပြုစုပါ၊ အဆင့်သတ်မှတ်ပြီး သုံးသပ်ချက်ရေးပါ။',
  ),
  'nb': (
    'Hold oversikt over serier og film – gratis app | dizi.jpg',
    'Gratis app for å holde oversikt over serier: kryss av hver episode du har sett, før filmliste, gi terningkast og anmeldelser, og se hva vennene dine ser.',
  ),
  'nl': (
    'Series en films bijhouden – Gratis tracker-app | dizi.jpg',
    'Gratis app om series bij te houden: vink elke aflevering af, maak een filmlijst, geef cijfers en reviews en zie wat je vrienden kijken. Web en Android.',
  ),
  'pa': (
    'ਲੜੀ ਅਤੇ ਫ਼ਿਲਮ ਟਰੈਕਰ ਐਪ – ਮੁਫ਼ਤ | dizi.jpg',
    'ਮੁਫ਼ਤ ਲੜੀ ਟਰੈਕਰ ਐਪ: ਵੇਖਿਆ ਹਰ ਐਪੀਸੋਡ ਦਰਜ ਕਰੋ, ਫ਼ਿਲਮਾਂ ਦੀ ਸੂਚੀ ਬਣਾਓ, ਰੇਟਿੰਗ ਅਤੇ ਸਮੀਖਿਆ ਦਿਓ ਅਤੇ ਵੇਖੋ ਕਿ ਦੋਸਤ ਕੀ ਵੇਖ ਰਹੇ ਹਨ।',
  ),
  'pl': (
    'Śledzenie seriali i filmów – darmowa aplikacja | dizi.jpg',
    'Darmowa aplikacja do śledzenia seriali: zaznaczaj obejrzane odcinki, prowadź listę filmów, oceniaj i recenzuj i zobacz, co oglądają znajomi.',
  ),
  'pt': (
    'App para acompanhar séries e filmes – Grátis | dizi.jpg',
    'App grátis para acompanhar séries: marque cada episódio assistido, monte sua lista de filmes, avalie e comente e veja o que seus amigos assistem.',
  ),
  'ro': (
    'Urmărire seriale și filme – aplicație gratuită | dizi.jpg',
    'Aplicație gratuită pentru urmărirea serialelor: bifează episoadele văzute, ține o listă de filme, dă note și recenzii și vezi ce urmăresc prietenii tăi.',
  ),
  'ru': (
    'Трекер сериалов и фильмов – бесплатно | dizi.jpg',
    'Бесплатный трекер сериалов: отмечайте просмотренные серии, ведите список фильмов, ставьте оценки и пишите рецензии, смотрите, что смотрят друзья.',
  ),
  'sr': (
    'Праћење серија и филмова – бесплатна апликација | dizi.jpg',
    'Бесплатна апликација за праћење серија: означи сваку одгледану епизоду, води списак филмова, оцењуј и пиши рецензије и види шта гледају пријатељи.',
  ),
  'sv': (
    'Håll koll på serier och filmer – gratis app | dizi.jpg',
    'Gratis app för att hålla koll på serier: bocka av varje avsnitt du sett, för filmlista, betygsätt och recensera och se vad dina vänner tittar på.',
  ),
  'sw': (
    'Kufuatilia mifululizo na filamu – Programu bure | dizi.jpg',
    'Programu bure ya kufuatilia mifululizo: weka alama kila kipindi ulichotazama, tunza orodha ya filamu, toa alama na maoni, ona marafiki wanatazama nini.',
  ),
  'ta': (
    'தொடர், திரைப்பட கண்காணிப்பு செயலி – இலவசம் | dizi.jpg',
    'இலவச தொடர் கண்காணிப்பு செயலி: பார்த்த ஒவ்வொரு அத்தியாயத்தையும் பதிவு செய்யுங்கள், திரைப்படப் பட்டியல் உருவாக்குங்கள், மதிப்பீடும் விமர்சனமும் எழுதுங்கள்.',
  ),
  'te': (
    'సిరీస్, సినిమా ట్రాకింగ్ యాప్ – ఉచితం | dizi.jpg',
    'ఉచిత సిరీస్ ట్రాకింగ్ యాప్: మీరు చూసిన ప్రతి ఎపిసోడ్‌ను నమోదు చేయండి, సినిమా జాబితా చేయండి, రేటింగ్ మరియు సమీక్ష ఇవ్వండి, స్నేహితులు ఏం చూస్తున్నారో చూడండి.',
  ),
  'th': (
    'แอปติดตามซีรีส์และภาพยนตร์ – ฟรี | dizi.jpg',
    'แอปติดตามซีรีส์ฟรี: บันทึกทุกตอนที่คุณดู จัดลิสต์ภาพยนตร์ ให้คะแนนและเขียนรีวิว และดูว่าเพื่อนกำลังดูอะไรอยู่ ใช้ได้บนเว็บและ Android',
  ),
  'tr': (
    'Dizi ve Film Takip Uygulaması – Ücretsiz | dizi.jpg',
    'Ücretsiz dizi takip uygulaması: izlediğin her bölümü kaydet, film listeni tut, puanla ve yorumla, arkadaşlarının ne izlediğini gör. Web ve Android.',
  ),
  'uk': (
    'Трекер серіалів і фільмів – безкоштовно | dizi.jpg',
    'Безкоштовний трекер серіалів: позначайте переглянуті серії, ведіть список фільмів, ставте оцінки й пишіть рецензії, дивіться, що дивляться друзі.',
  ),
  'ur': (
    'سیریز اور فلم ٹریکر ایپ – مفت | dizi.jpg',
    'مفت سیریز ٹریکر ایپ: آپ جو قسط دیکھیں اسے محفوظ کریں، فلموں کی فہرست بنائیں، درجہ بندی اور جائزے لکھیں اور دیکھیں کہ آپ کے دوست کیا دیکھ رہے ہیں۔',
  ),
  'vi': (
    'Ứng dụng theo dõi phim bộ và phim lẻ – Miễn phí | dizi.jpg',
    'Ứng dụng theo dõi phim miễn phí: đánh dấu từng tập đã xem, lập danh sách phim, chấm điểm và viết đánh giá, xem bạn bè đang xem gì. Web và Android.',
  ),
  'zh': (
    '追剧记录应用 – 剧集与电影追踪，免费 | dizi.jpg',
    '免费追剧记录应用：标记看过的每一集，管理电影片单，打分写影评，还能看看朋友都在看什么。支持网页版和 Android。',
  ),
};

/// Bu dilin SEO ana sayfa başlığı; tanınmayan dilde Türkçe karşılığı.
String seoAnaBaslik(String dil) => (seoAnaMetin[dil] ?? seoAnaMetin['tr']!).$1;

/// Bu dilin SEO ana sayfa açıklaması; tanınmayan dilde Türkçe karşılığı.
String seoAnaAciklama(String dil) =>
    (seoAnaMetin[dil] ?? seoAnaMetin['tr']!).$2;

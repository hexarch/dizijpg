#!/usr/bin/env bash
# dizi.jpg GEO ölçümü — GEO-PLANI.md §6 kanal 1 ve 2.
# Sunucuda çalışır: ssh root@154.53.163.3 'bash /root/geo-olcum.sh [kip]'
#   kip: bugun (varsayilan) | dun | trend
# ⚠ Kendi testlerimizi (?n= ve 127.0.0.1) BILEREK haric tutar — GEO-PLANI §6.1.
#
# ---------------------------------------------------------------------------
# 29 AGU 2026 — IKI KUSUR OLCULDU VE DUZELTILDI
# ---------------------------------------------------------------------------
# 1) YOL REGEX'INDE `bolum` ONEKI OLU DALDI. Bolum sayfasinin yolu
#    `/dizi/<id>/sezon/<s>/bolum/<b>` — yani ILK segment `dizi`, `bolum` DEGIL.
#    `^/(icerik|kisi|sirket|bolum)/` kalibi hicbir bolum sayfasini saymiyordu.
#    Olcum (28+27 Agu): birinci segmenti `/bolum/` olan istek sayisi = 0, yani
#    dal tanimi geregi hic calismamis. Bugune kadar SAYIYI BOZMADI (cevap
#    botlari henuz hic bolum sayfasi cekmedi) ama 28 Agu'da bolum SSS'i canliya
#    ciktigi icin tam da olcmek istedigimiz yuzey gorunmez kalacakti.
#    `gsc_izle.js`in `genel` kovasi dersinin aynisi: olcmedigin yuzey yoktur.
# 2) TEK GUNLUK BAKIS YANLIS ALARM URETIYOR. 28 Agu'da bu betik
#    "OAI-SearchBot istek=9 icerik=0" dedi; 27 Agu'da ayni bot 20 icerik
#    sayfasi cekmisti. Tek gune bakan okuyucu "kazanim geri gitti" sanir.
#    Gercek: cevap botu trafigi SEYREK ve dalgali; anlam ancak seride var.
#    `trend` kipi gunluk seriyi (dondurulmus loglar dahil) basar.
#
# ---------------------------------------------------------------------------
# 3 EYL 2026 — UC KUSUR DAHA OLCULDU VE DUZELTILDI
# ---------------------------------------------------------------------------
# 3) DIL ONEKLI YOLLAR SAYILMIYORDU — kusur 1'in birebir kardesi, ama bu sefer
#    SAYIYI BOZDU. 29 Agu'da SSR 46 DILLI oldu (`seo_dil.js`) ve URL uzayi
#    45 dil onekiyle carpildi: `/kn/kisi/92908`, `/de/icerik/tv/1396`.
#    `^/(icerik|kisi|sirket|dizi)/` kalibi bunlarin HICBIRINI tutmuyor.
#    Olcum (3 Eyl): betik "icerik=9.329" dedi, gercek 49.887 — 5,3 KAT EKSIK.
#    Botun o gunku isteklerinin %81'i dil onekliydi. Cozum: yolu saymadan once
#    bilinen dil onegini soy (`ONEK` — 45 kodun TAM listesi, `[a-z]{2}` gibi
#    tahmin DEGIL; `fil`/`nb`/`zh` uc harfli ve iki harfli kodlar karisik).
# 4) `ort_bayt` YANILTIYORDU — nginx SIKISTIRILMIS govdeyi yazar ($body_bytes_sent),
#    belge boyunca olcut olarak kullanilan "16.215 B = SSR / 12.679 B = kabuk"
#    ise `curl`un HAM boyu. Ikisi kiyaslanamaz. Olcum (3 Eyl): logda 2.109 B
#    goruluyordu, ayni sayfa origin'den ham 20.273 B / gzip 2.337 B — yani
#    "2 KB" SSR'in ta kendisiydi, kabuk degil. §0.3'un "4.726 bayt = kabuk
#    imzasi" akil yurutmesi dogru sonuca varmis ama YANLIS olcu cubuguyla.
#    Cozum: sutun adi `ort_gzip` oldu ve betik her kosuda origin'den CANLI
#    OLCU CUBUGU basar (§5) — artik log baytini neyle kiyaslayacagin ekranda.
# 5) TREND KIPI GUNU DEGIL DOSYAYI SAYIYORDU. Gun etiketi her dosyanin ILK
#    satirindan aliniyor, sonra o dosyanin TUM satirlari o gune yaziliyordu.
#    Gunluk donen logda dosya sinirindaki satirlar komsu gune sizar (3 Eyl:
#    access.log.1 icinde 1 adet 03/Eyl satiri 02/Eyl'e yazildi). Cozum: gun
#    her satirin KENDI zaman damgasindan okunuyor, sonra takvim sirasiyla
#    basiliyor.
# ---------------------------------------------------------------------------
set -uo pipefail

KIP="${1:-bugun}"
CEVAP='OAI-SearchBot|ChatGPT-User|PerplexityBot|Perplexity-User|Claude-User|Claude-SearchBot|DuckAssistBot|Applebot/'
EGITIM='GPTBot|ClaudeBot|CCBot|Bytespider|Amazonbot|meta-externalagent|Applebot-Extended'
# Bir "icerik sayfasi" nedir: dort SSR yuzeyinin ilk segmenti.
# `dizi` = bolum sayfasi (bkz. yukarida 1. kusur).
ICERIK_YOL='^/(icerik|kisi|sirket|dizi)/'
# SSR dil onekleri — `seo_dil.js` SEO_DILLER listesinin `tr` disindaki 45'i.
# `tr` oneksiz servis edilir. TAHMIN EDILMEZ: liste degisirse buraya da yazilir
# (kaynak: node -e "console.log(require('./seo_dil.js').SEO_DILLER.join(' '))").
ONEK='en|es|de|fr|it|pt|nl|ru|uk|pl|cs|bg|sr|el|hu|ro|sv|da|nb|ja|ko|zh|th|vi|id|ms|fil|my|ar|he|fa|ur|hi|bn|fi|az|sw|am|ta|te|kn|ml|mr|gu|pa'

# awk'a gecen ortak cozumleyici: sorguyu at, dil onegini soy, yuzey kovasi ver.
AWK_ORTAK='
function yol(p,   q) { q=p; sub(/\?.*$/,"",q); sub("^/(" ONEK ")/","/",q); return q }
function onekli(p) { return (p ~ ("^/(" ONEK ")/")) }
function kova(p,   q,a) { q=yol(p)
  if (q ~ /^\/dizi\/.*\/bolum\//) return "bölüm"
  split(q,a,"/"); if (a[2]=="icerik") return "/icerik/" a[3]
  return "/" a[2] "/" }
function gunu(s,   d,a,ay) { ay["Jan"]="01";ay["Feb"]="02";ay["Mar"]="03";ay["Apr"]="04"
  ay["May"]="05";ay["Jun"]="06";ay["Jul"]="07";ay["Aug"]="08";ay["Sep"]="09"
  ay["Oct"]="10";ay["Nov"]="11";ay["Dec"]="12"
  d=s; sub(/^\[/,"",d); split(d,a,/[\/:]/); return a[3] "-" ay[a[2]] "-" a[1] }
'

# ---------------------------------------------------------------------------
# TREND KIPI — gunluk seri. Tek gunun sifiri sinyal degil, gurultudur.
# ---------------------------------------------------------------------------
if [ "$KIP" = "trend" ]; then
  echo "### dizi.jpg GEO trendi — $(date '+%Y-%m-%d %H:%M %Z')"
  echo "cevap botu = OAI-SearchBot·ChatGPT-User·Perplexity(Bot|-User)·Claude(-User|-SearchBot)·DuckAssistBot·Applebot"
  echo
  printf '%-12s %9s %9s %9s %9s\n' 'gün' 'istek' 'içerik' 'dil_sür.' 'eğitim_iç'
  # Eskiden yeniye: dondurulmus loglar ters numaralidir (.14 en eski).
  # Gun DOSYADAN degil, her SATIRIN kendi damgasindan okunur (bkz. kusur 5).
  { for n in $(seq 14 -1 2); do
      f=/var/log/nginx/access.log.$n.gz
      [ -f "$f" ] && zcat "$f" 2>/dev/null
    done
    cat /var/log/nginx/access.log.1 2>/dev/null
    cat /var/log/nginx/access.log   2>/dev/null
  } | grep -av '127\.0\.0\.1' | grep -av '?n=' \
    | awk -v ONEK="$ONEK" -v ic="$ICERIK_YOL" -v cv="$CEVAP" -v eg="$EGITIM" "
      $AWK_ORTAK"'
      { g = gunu($4) }
      $0 ~ cv { t[g]++; if (yol($7) ~ ic) { c[g]++; if (onekli($7)) d[g]++ } }
      $0 ~ eg && yol($7) ~ ic { e[g]++ }
      END { for (g in t) printf "%-12s %9d %9d %9d %9d\n", g, t[g], c[g]+0, d[g]+0, e[g]+0 }' \
    | sort
  echo
  echo "OKUMA NOTU: 'içerik' sütunu 0 olan tek bir gün BAŞARISIZLIK DEĞİLDİR"
  echo "(GEO-PLANI §8: cevap botu trafiği seyrek). 'eğitim_iç' 0'DAN BÜYÜKSE"
  echo "gerçek arıza: eğitim botu içerik çekiyor, robots.txt beyanımız çiğneniyor."
  echo "'dil_sür.' = içerik sayfalarının kaçı dil önekli (/de/, /kn/ …)."
  exit 0
fi

LOG=/var/log/nginx/access.log
[ "$KIP" = "dun" ] && LOG=/var/log/nginx/access.log.1

temiz() { grep -av '127\.0\.0\.1' "$LOG" | grep -av '?n='; }

echo "### dizi.jpg GEO ölçümü — $(date '+%Y-%m-%d %H:%M %Z') · kaynak: $LOG"
echo "(seri için: bash geo-olcum.sh trend — tek günün sıfırı sinyal değildir)"
echo
echo "-- 1) CEVAP BOTLARI: istek / içerik sayfası --"
temiz | grep -aE "$CEVAP" | awk -v ONEK="$ONEK" -v ic="$ICERIK_YOL" "
  $AWK_ORTAK"'
  { n=split("Claude-SearchBot Claude-User OAI-SearchBot ChatGPT-User PerplexityBot Perplexity-User DuckAssistBot Applebot",a," ");
    b="?"; for(i=1;i<=n;i++) if (index($0,a[i])) { b=a[i]; break }
    t[b]++; if (yol($7) ~ ic) { c[b]++; by[b]+=$10; if (onekli($7)) d[b]++ } }
  END { for (k in t) printf "%-18s istek=%-6d icerik=%-6d dil_sür=%-6d ort_gzip=%d\n",
          k, t[k], c[k]+0, d[k]+0, (c[k]?by[k]/c[k]:0) }' | sort
echo "(ort_gzip = nginx'in yazdigi SIKISTIRILMIS govde; ham karsiligi §5'te)"
echo
echo "-- 2) ÇEKİLEN YÜZEYLER (dil öneki soyulmuş) --"
temiz | grep -aE "$CEVAP" | awk -v ONEK="$ONEK" -v ic="$ICERIK_YOL" "
  $AWK_ORTAK"'
  yol($7) ~ ic { print kova($7) }' | sort | uniq -c | sort -rn | head
echo
echo "-- 3) ATIF TRAFİĞİ (Referer) --"
# ⚠ ALAN SINIRLI: satirin tamamina bakan grep, `Claude-SearchBot` UA'sini
# "claude" diye sayiyordu (3 Eyl: sahte 291). Referer combined logda 4. tirnak alani.
printf 'chatgpt/perplexity/claude/copilot yönlendirmesi: %s\n' \
  "$(awk -F'"' '{print $4}' "$LOG" | grep -aicE 'chatgpt\.com|perplexity\.ai|claude\.ai|copilot\.microsoft')"
echo
echo "-- 4) EĞİTİM BOTLARI (içerik çekmemeli; yalnız robots.txt bekleriz) --"
temiz | grep -aiE "$EGITIM" | awk -v ONEK="$ONEK" -v ic="$ICERIK_YOL" "
  $AWK_ORTAK"'
  { if (yol($7) ~ ic) i++; else r++ }
  END { printf "robots/sitemap=%d  ⚠ ICERIK=%d\n", r+0, i+0 }'
echo
echo "-- 5) ÖLÇÜ ÇUBUĞU (origin'den canlı, bot UA'sı ile) --"
echo "Log 'ort_gzip' sütunu bununla kıyaslanır; ham boyla ASLA (bkz. kusur 4)."
UA_BOT='Mozilla/5.0 (compatible; Claude-SearchBot/1.0; +searchbot@anthropic.com)'
printf '%-22s %9s %9s  %s\n' 'yüzey' 'ham' 'gzip' 'SSS'
for u in /icerik/tv/1396 /kisi/8293 /sirket/7382 /de/icerik/tv/1396; do
  ham=$(curl -sk -A "$UA_BOT" -H 'Host: dizijpg.com' "https://127.0.0.1$u?n=$RANDOM" 2>/dev/null)
  gz=$(curl -sk -o /dev/null -w '%{size_download}' -A "$UA_BOT" -H 'Host: dizijpg.com' \
       -H 'Accept-Encoding: gzip, br' "https://127.0.0.1$u?n=$RANDOM" 2>/dev/null)
  printf '%-22s %9s %9s  %s\n' "$u" "$(printf '%s' "$ham" | wc -c | tr -d ' ')" "${gz:-?}" \
    "$(printf '%s' "$ham" | grep -c FAQPage)"
done

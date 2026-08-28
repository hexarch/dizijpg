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
# ---------------------------------------------------------------------------
set -uo pipefail

KIP="${1:-bugun}"
CEVAP='OAI-SearchBot|ChatGPT-User|PerplexityBot|Perplexity-User|Claude-User|Claude-SearchBot|DuckAssistBot|Applebot/'
EGITIM='GPTBot|ClaudeBot|CCBot|Bytespider|Amazonbot|meta-externalagent|Applebot-Extended'
# Bir "icerik sayfasi" nedir: dort SSR yuzeyinin ilk segmenti.
# `dizi` = bolum sayfasi (bkz. yukarida 1. kusur).
ICERIK_YOL='^/(icerik|kisi|sirket|dizi)/'

# ---------------------------------------------------------------------------
# TREND KIPI — gunluk seri. Tek gunun sifiri sinyal degil, gurultudur.
# ---------------------------------------------------------------------------
if [ "$KIP" = "trend" ]; then
  echo "### dizi.jpg GEO trendi — $(date '+%Y-%m-%d %H:%M %Z')"
  echo "cevap botu = OAI-SearchBot·ChatGPT-User·Perplexity(Bot|-User)·Claude(-User|-SearchBot)·DuckAssistBot·Applebot"
  echo
  printf '%-12s %8s %8s %8s\n' 'gün' 'istek' 'içerik' 'eğitim_iç'
  # Eskiden yeniye: dondurulmus loglar ters numaralidir (.14 en eski).
  for n in $(seq 14 -1 2); do
    f=/var/log/nginx/access.log.$n.gz
    [ -f "$f" ] && echo "zcat $f"
  done > /tmp/geo-trend-kaynak.$$
  echo "cat /var/log/nginx/access.log.1" >> /tmp/geo-trend-kaynak.$$
  echo "cat /var/log/nginx/access.log"   >> /tmp/geo-trend-kaynak.$$
  while read -r komut; do
    veri=$($komut 2>/dev/null | grep -v '127\.0\.0\.1' | grep -v '?n=')
    gun=$(printf '%s\n' "$veri" | head -1 | grep -o '\[[0-9]*/[A-Za-z]*/[0-9]*' | tr -d '[')
    [ -z "$gun" ] && continue
    printf '%s\n' "$veri" | awk -v g="$gun" -v ic="$ICERIK_YOL" -v cv="$CEVAP" -v eg="$EGITIM" '
      $0 ~ cv { t++; if ($7 ~ ic) c++ }
      $0 ~ eg && $7 ~ ic { e++ }
      END { printf "%-12s %8d %8d %8d\n", g, t+0, c+0, e+0 }'
  done < /tmp/geo-trend-kaynak.$$
  rm -f /tmp/geo-trend-kaynak.$$
  echo
  echo "OKUMA NOTU: 'içerik' sütunu 0 olan tek bir gün BAŞARISIZLIK DEĞİLDİR"
  echo "(GEO-PLANI §8: cevap botu trafiği seyrek). 'eğitim_iç' 0'DAN BÜYÜKSE"
  echo "gerçek arıza: eğitim botu içerik çekiyor, robots.txt beyanımız çiğneniyor."
  exit 0
fi

LOG=/var/log/nginx/access.log
[ "$KIP" = "dun" ] && LOG=/var/log/nginx/access.log.1

temiz() { grep -v '127\.0\.0\.1' "$LOG" | grep -v '?n='; }

echo "### dizi.jpg GEO ölçümü — $(date '+%Y-%m-%d %H:%M %Z') · kaynak: $LOG"
echo "(seri için: bash geo-olcum.sh trend — tek günün sıfırı sinyal değildir)"
echo
echo "-- 1) CEVAP BOTLARI: istek / içerik sayfası --"
temiz | grep -aE "$CEVAP" | awk -v ic="$ICERIK_YOL" '
  { n=split("Claude-SearchBot Claude-User OAI-SearchBot ChatGPT-User PerplexityBot Perplexity-User DuckAssistBot Applebot",a," ");
    b="?"; for(i=1;i<=n;i++) if (index($0,a[i])) { b=a[i]; break }
    t[b]++; if ($7 ~ ic) { c[b]++; by[b]+=$10 } }
  END { for (k in t) printf "%-18s istek=%-4d icerik=%-4d ort_bayt=%d\n", k, t[k], c[k]+0, (c[k]?by[k]/c[k]:0) }' | sort
echo
echo "-- 2) EN ÇOK ÇEKİLEN YÜZEYLER --"
temiz | grep -aE "$CEVAP" | awk -v ic="$ICERIK_YOL" '$7 ~ ic { split($7,p,"/"); print "/"p[2]"/"p[3] }' | sort | uniq -c | sort -rn | head
echo
echo "-- 3) ATIF TRAFİĞİ (Referer) --"
printf 'chatgpt/perplexity/claude/copilot yönlendirmesi: %s\n' \
  "$(grep -acE '"https?://[^"]*(chatgpt\.com|perplexity\.ai|claude\.ai|copilot\.microsoft)' "$LOG")"
echo
echo "-- 4) EĞİTİM BOTLARI (içerik çekmemeli; yalnız robots.txt bekleriz) --"
temiz | grep -aiE "$EGITIM" | awk -v ic="$ICERIK_YOL" '{ if ($7 ~ ic) i++; else r++ }
  END { printf "robots/sitemap=%d  ⚠ ICERIK=%d\n", r+0, i+0 }'

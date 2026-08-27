#!/usr/bin/env bash
# dizi.jpg GEO ölçümü — GEO-PLANI.md §6 kanal 1 ve 2.
# Sunucuda çalışır: ssh root@154.53.163.3 'bash /root/geo-olcum.sh [gun]'
#   gun: bugun (varsayilan) | dun
# ⚠ Kendi testlerimizi (?n= ve 127.0.0.1) BILEREK haric tutar — GEO-PLANI §6.1.
set -uo pipefail
LOG=/var/log/nginx/access.log
[ "${1:-bugun}" = "dun" ] && LOG=/var/log/nginx/access.log.1
CEVAP='OAI-SearchBot|ChatGPT-User|PerplexityBot|Perplexity-User|Claude-User|Claude-SearchBot|DuckAssistBot|Applebot/'
EGITIM='GPTBot|ClaudeBot|CCBot|Bytespider|Amazonbot|meta-externalagent|Applebot-Extended'

temiz() { grep -v '127\.0\.0\.1' "$LOG" | grep -v '?n='; }

echo "### dizi.jpg GEO ölçümü — $(date '+%Y-%m-%d %H:%M %Z') · kaynak: $LOG"
echo
echo "-- 1) CEVAP BOTLARI: istek / içerik sayfası --"
temiz | grep -aE "$CEVAP" | awk '
  { n=split("Claude-SearchBot Claude-User OAI-SearchBot ChatGPT-User PerplexityBot Perplexity-User DuckAssistBot Applebot",a," ");
    b="?"; for(i=1;i<=n;i++) if (index($0,a[i])) { b=a[i]; break }
    t[b]++; if ($7 ~ /^\/(icerik|kisi|sirket|bolum)\//) { c[b]++; by[b]+=$10 } }
  END { for (k in t) printf "%-18s istek=%-4d icerik=%-4d ort_bayt=%d\n", k, t[k], c[k]+0, (c[k]?by[k]/c[k]:0) }' | sort
echo
echo "-- 2) EN ÇOK ÇEKİLEN YÜZEYLER --"
temiz | grep -aE "$CEVAP" | awk '$7 ~ /^\/(icerik|kisi|sirket|bolum)\// { split($7,p,"/"); print "/"p[2]"/"p[3] }' | sort | uniq -c | sort -rn | head
echo
echo "-- 3) ATIF TRAFİĞİ (Referer) --"
printf 'chatgpt/perplexity/claude/copilot yönlendirmesi: %s\n' \
  "$(grep -acE '"https?://[^"]*(chatgpt\.com|perplexity\.ai|claude\.ai|copilot\.microsoft)' "$LOG")"
echo
echo "-- 4) EĞİTİM BOTLARI (içerik çekmemeli; yalnız robots.txt bekleriz) --"
temiz | grep -aiE "$EGITIM" | awk '{ if ($7 ~ /^\/(icerik|kisi|sirket|bolum)\//) i++; else r++ }
  END { printf "robots/sitemap=%d  ⚠ ICERIK=%d\n", r+0, i+0 }'

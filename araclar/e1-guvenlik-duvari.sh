#!/bin/bash
# dizi.jpg E1+E2+E3 — guvenlik duvari kurulumu (12 Agu 2026)
# NOT: ufw kural/config dosyalarini ASCII yazar — bu dosyada TURKCE KARAKTER
# KULLANILMAZ (ilk deneme ğ ile UnicodeEncodeError verdi).
# Sira kritik: kurallar INAKTIFKEN yazilir, olu-adam sigortasi kurulur,
# EN SON etkinlestirilir. Kilitlenme olursa sigorta 5 dk'da duvari kapatir.
set -euo pipefail

# Ilk denemenin yarim kalan after.rules eki geri alinir (yedek o denemede alindi)
cp /etc/ufw/after.rules.yedek-20260812 /etc/ufw/after.rules

# --- E3: dopamall-redis (6379) Docker yayini ufw'yi BAYPAS eder (DNAT,
# PREROUTING). Tek care DOCKER-USER zinciri. Localhost ve konteyner-ici
# erisim etkilenmez; yalniz dis arayuzden gelen YENI baglanti duser.
cat >> /etc/ufw/after.rules <<'EOF'

# E3 (12 Agu 2026): dopamall-redis parolasiz; Docker yayini ufw INPUT'a
# ugramadigi icin disariya buradan kapatilir. Kalici cozum compose'da
# 127.0.0.1:6379 baglamak (dopamall sahibinin isi).
*filter
:DOCKER-USER - [0:0]
-A DOCKER-USER -i ens18 -p tcp --dport 6379 -j DROP
-A DOCKER-USER -j RETURN
COMMIT
EOF

# --- E1: varsayilan kapali, gerekenler acik
ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp    comment 'SSH (fail2ban aktif)'
ufw allow 80/tcp    comment 'nginx http'
ufw allow 443/tcp   comment 'nginx https'

# Posta: mevcut acik yuzey korunuyor (110/143 duz metin - ileride kapatilabilir)
ufw allow 25/tcp    comment 'Postfix SMTP gelen'
ufw allow 587/tcp   comment 'Postfix submission'
ufw allow 110/tcp   comment 'Dovecot POP3'
ufw allow 143/tcp   comment 'Dovecot IMAP'
ufw allow 993/tcp   comment 'Dovecot IMAPS'
ufw allow 995/tcp   comment 'Dovecot POP3S'

# Konteyner -> host Postfix (dizijpg API mail hatti: host.docker.internal:25).
# Duvar bunu kapatirsa sifre sifirlama/saglik mailleri SESSIZCE kirilir.
ufw allow from 172.16.0.0/12 to any port 25 proto tcp comment 'docker-Postfix'

# TURN (coturn): sinyal + TLS + UDP role araligi (no-tcp-relay)
ufw allow 3478/tcp  comment 'TURN'
ufw allow 3478/udp  comment 'TURN'
ufw allow 5349/tcp  comment 'TURNS TLS'
ufw allow 24000:24499/udp comment 'TURN role'

# E2: host Postgres yalniz iki istemci IP (pg_hba ile ayni liste)
ufw allow from 188.119.45.48 to any port 5432 proto tcp comment 'dopamine PG'
ufw allow from 154.53.163.5 to any port 5432 proto tcp comment 'dopamine PG 2'

# --- Olu-adam sigortasi: 5 dk icinde elle durdurulmazsa duvar kendini kapatir
systemd-run --unit=ufw-emniyet --on-active=300 /usr/sbin/ufw disable

# --- Etkinlestir
ufw --force enable
ufw status verbose

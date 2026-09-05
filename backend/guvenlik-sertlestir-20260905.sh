#!/usr/bin/env bash
# dizi.jpg — Güvenlik denetimi 2026-09-05, sunucu tarafı sertleştirme.
# Sunucuda root olarak koş:  ssh karanew 'bash -s' < backend/guvenlik-sertlestir-20260905.sh
# Her adım önce yedek alır; nginx/postfix/dovecot yapılandırması sınanmadan reload edilmez.
# Geri alma: /root/*.yedek-guvenlik-<damga> dosyalarını yerine kopyala + ilgili servisi reload et.
set -euo pipefail
D=$(date +%Y%m%d-%H%M%S)

echo "### 1) Postfix: SASL kimlik doğrulama yalnız TLS üzerinden (§2.3)"
cp -a /etc/postfix/main.cf "/root/main.cf.yedek-guvenlik-$D"
postconf -e "smtpd_tls_auth_only = yes"
postfix check
systemctl reload postfix
postconf smtpd_tls_auth_only

echo "### 2) Dovecot: düz-metin kimlik doğrulama kapalı (§2.3)"
# Node uygulaması Postfix'e mynetworks (172.19.0.0/16) üzerinden kimliksiz gider; etkilenmez.
# Dovecot yerel (127.0.0.1) bağlantıyı zaten 'secured' sayar; Postfix SASL köprüsü etkilenmez.
cp -a /etc/dovecot/conf.d/10-auth.conf "/root/10-auth.conf.yedek-guvenlik-$D"
if grep -qE '^#?disable_plaintext_auth' /etc/dovecot/conf.d/10-auth.conf; then
  sed -i -E 's/^#?disable_plaintext_auth\s*=.*/disable_plaintext_auth = yes/' /etc/dovecot/conf.d/10-auth.conf
else
  echo 'disable_plaintext_auth = yes' >> /etc/dovecot/conf.d/10-auth.conf
fi
doveconf -n > /dev/null
systemctl reload dovecot
doveconf disable_plaintext_auth

echo "### 3) avahi (mDNS 5353/udp) kapalı (§2.4)"
systemctl disable --now avahi-daemon.socket avahi-daemon.service || true
systemctl is-active avahi-daemon || true
ss -ulnp | grep -c 5353 || echo "5353 dinleyen yok"

echo "### 4) nginx admin CSP: unpkg.com kaldırıldı (§2.2 — varlıklar artık /api/admin/varlik/)"
F=/etc/nginx/sites-enabled/dizijpg.com
cp -a "$F" "/root/nginx-yedek-dizijpg-csp-$D.conf"
sed -i -E "s#script-src 'self' 'unsafe-inline' https://unpkg.com;#script-src 'self' 'unsafe-inline';#; s#img-src 'self' data: blob: https://unpkg.com #img-src 'self' data: blob: #" "$F"
echo "kalan unpkg satırı: $(grep -c unpkg "$F" || true)"
nginx -t
systemctl reload nginx

echo "### 5) Mac tarafı (elle): kara parolasını kilitlemek istersen: passwd -l kara  (sudo parola ister, ÖNCE karar ver)"
echo "TAMAM"

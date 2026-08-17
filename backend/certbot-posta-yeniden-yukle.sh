#!/bin/bash
# certbot YENILEME KANCASI — Postfix + Dovecot'u yeni sertifikayla yeniden yukle.
#
# NEDEN SART: certbot sertifikayi diske yeniler ama Postfix ve Dovecot
# sertifikayi ACILISTA belege alir. Kanca olmadan 90 gun sonra dosya
# yenilenir, servisler ESKI (suresi dolmus) sertifikayi sunmaya devam eder ve
# posta istemcileri bir sabah "sertifika suresi doldu" hatasi vermeye baslar.
# Sessiz ve gecikmeli bir ariza — tam da fark edilmesi en zor tur.
#
# `--deploy-hook` YALNIZ sertifika GERCEKTEN yenilendiginde calisir; her
# yenileme denemesinde degil. Yani gunde iki kez bosuna reload olmaz.
set -e

systemctl reload postfix
# Dovecot'ta reload SSL baglamini her surumde tazelemiyor; restart kesin.
# Kesinti milisaniyeler surer, acik IMAP oturumlari yeniden baglanir.
systemctl restart dovecot

logger -t certbot-posta "Postfix + Dovecot yeni sertifikayla yeniden yuklendi"

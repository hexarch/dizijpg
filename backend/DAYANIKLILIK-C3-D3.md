# dizi.jpg — C3 (journald sınırı) + D3 (Postgres ayarları) HAZIRLIK

> Bu dosya YALNIZCA hazırlıktır. Buradaki hiçbir adım henüz sunucuya
> UYGULANMADI. İkisi de sunucuda ana oturumun elle uygulaması gereken,
> **kesinti riski taşıyan** değişikliklerdir. Değerler `yapilacaklar2`de
> ölçülen donanıma göredir: **16 çekirdek · 131 GB RAM**.

---

## C3 — systemd journal boyut sınırı

**Sorun (`yapilacaklar2` C3):** `/var/log/journal` sınırsız büyümüş, ölçümde
2,1 GB. Sınır konmazsa disk dolana kadar büyür.

**Uygulanacak dosya:** `/etc/systemd/journald.conf`
`[Journal]` bölümü altına (varsa `#SystemMaxUse=` satırını aç ve değeri ver):

```ini
[Journal]
SystemMaxUse=500M
```

**Neden 500M:** Teşhis için birkaç haftalık journal fazlasıyla yeter; disk
tuzağını da kapatır. Docker logları ayrıca C2 ile sınırlandığı için
(`50m × 5`), journal'ın büyük tutulmasına gerek yok.

**Etkinleştirme (ana oturum, sunucuda):**
```sh
sudo nano /etc/systemd/journald.conf      # SystemMaxUse=500M ekle
sudo systemctl restart systemd-journald
journalctl --disk-usage                   # doğrula: 500M altına inmeli
```

**KESİNTİ:** YOK. `systemd-journald` yeniden başlatması hizmeti etkilemez;
yalnız log toplayıcı bir an duraklar. Güvenli.

---

## D3 — Postgres performans ayarları

**Sorun (`yapilacaklar2` D3):** Postgres varsayılan ayarlarda —
`shared_buffers = 128MB`, 131 GB RAM'li makinede. Birkaç satırla belirgin
hızlanır, risksiz.

> ⚠ ÖNEMLİ MİMARİ NOTU: `docker-compose.yml`deki `db` servisi
> `postgres:16-alpine` konteyneridir. AMA `yapilacaklar2` (E2) HOST üzerinde
> ayrı bir Postgres'ten (`listen_addresses='*'`, 5432 dışa açık, `dopamine_db`)
> söz ediyor. **Hangi Postgres'in uygulamaya hizmet verdiği ana oturumca
> doğrulanmalı.** Aşağıdaki değerler, dizi.jpg'e hizmet veren örneğin
> **131 GB / 16 çekirdek makinede tek başına** çalıştığı varsayımıyladır.
> Makinede başka ağır servisler (CRM, host PG, Redis) da varsa
> `shared_buffers`/`effective_cache_size` bir tık düşürülmeli — RAM paylaşımlı.

### Önerilen değerler ve gerekçe

| Ayar | Varsayılan | Önerilen | Gerekçe |
|------|-----------|----------|---------|
| `shared_buffers` | 128MB | **8GB** | Klasik kural RAM'in ~%25'i. 131 GB'de bu ~32 GB eder; ama veritabanı yalnız 359 MB (D bölümü ölçümü) ve makine paylaşımlı. Tüm DB + indeksler zaten belleğe sığdığından 8 GB fazlasıyla yeterli; kalan RAM'i işletim sistemi önbelleği ve diğer servisler kullanır. DB büyürse 16–32 GB'ye çıkılabilir. |
| `effective_cache_size` | 4GB | **32GB** | Bu bir TAHSİS değil, planlayıcıya "OS önbelleği dahil ne kadar RAM okumaya ayrılabilir" ipucudur. Yüksek tutmak indeks taramasını tercih ettirir. 131 GB'de 32 GB muhafazakâr ve güvenli. |
| `work_mem` | 4MB | **64MB** | Sıralama/hash başına AYRILIR ve bağlantı × işlem sayısıyla çarpılır — asıl risk burada. Havuz `max: 30` bağlantı; en kötü durumda 30 × birkaç işlem × 64MB hâlâ birkaç GB, 131 GB'de güvenli. Sayfalama/arama sorgularını diske taşmadan bellekte bitirir. |
| `maintenance_work_mem` | 64MB | **1GB** | VACUUM, CREATE INDEX, ALTER TABLE için. Tek seferliktir (eşzamanlı çok sayıda olmaz), yüksek tutmak indeks kurmayı ve otomatik vakumu hızlandırır. |
| `max_wal_size` | 1GB | **4GB** | (opsiyonel) Yazma yükünde checkpoint sıklığını azaltır, yazma tepe noktalarını yumuşatır. Yazma hacmi düşük olduğu için ikincil önem. |

### Nereye yazılır

- **Konteyner Postgres ise:** kalıcı olması için `docker-compose.yml`deki `db`
  servisine `command` ile geçilebilir, ör.:
  ```yaml
  command:
    - "postgres"
    - "-c"
    - "shared_buffers=8GB"
    - "-c"
    - "effective_cache_size=32GB"
    - "-c"
    - "work_mem=64MB"
    - "-c"
    - "maintenance_work_mem=1GB"
  ```
  VEYA veri biriminde `postgresql.conf` düzenlenir. **Yalnız `logging`
  bloğu gibi mevcut yapıyı bozmadan eklenmeli.**
- **Host Postgres ise:** `postgresql.conf` (genelde
  `/etc/postgresql/16/main/postgresql.conf`) düzenlenir.

### Uygulama

```sh
# Değişikliklerin çoğu (shared_buffers hariç) reload ile devreye girer:
#   shared_buffers → RESTART gerektirir.
sudo systemctl restart postgresql        # host ise
# veya
docker compose restart db                # konteyner ise
```

**KESİNTİ:** VAR. `shared_buffers` bir yeniden başlatma gerektirir; Postgres
birkaç saniye kapanır ve bu sürede API 500/503 döner (B2 zarif kapanma yalnız
API tarafını korur, DB'nin kendisini değil). **Düşük trafikli bir pencerede
yapılmalı.** `work_mem`, `effective_cache_size`, `maintenance_work_mem`
tek başına `SELECT pg_reload_conf();` ile kesintisiz uygulanabilir — yalnız
`shared_buffers` için yeniden başlatma şarttır; onu en sona bırakıp tek
kesintide toplamak en azıdır.

---

## ANA OTURUM İÇİN ÖZET — kim kesinti yaratır?

| İş | Kesinti | Not |
|----|---------|-----|
| C2 (docker log sınırı) | **YOK** | Zaten `docker-compose.yml`e eklendi; sonraki `up`/`recreate`de devreye girer. |
| C3 (journald 500M) | **YOK** | `systemd-journald` restart, hizmeti etkilemez. |
| D3 — work_mem / effective_cache_size / maintenance_work_mem | **YOK** | `pg_reload_conf()` yeterli. |
| D3 — shared_buffers | **VAR (birkaç sn)** | Postgres restart. Düşük trafikli pencerede yap. |

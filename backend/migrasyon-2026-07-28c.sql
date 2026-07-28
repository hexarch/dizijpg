-- Yorumlarda kullanıcı-işaretli spoiler bayrağı.
-- Akıştaki otomatik (izlenmemiş içerik) bulanıklaştırmanın yanına, yazan kişinin
-- "bu yorum spoiler içerir" diyebilmesi için. Akış ve yorum listesinde bulanık gösterilir.
ALTER TABLE yorumlar ADD COLUMN IF NOT EXISTS spoiler BOOLEAN NOT NULL DEFAULT false;

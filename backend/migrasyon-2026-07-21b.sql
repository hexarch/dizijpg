-- 2026-07-21b: yorumlara yanıt (tek seviye iş parçacığı)
ALTER TABLE yorumlar ADD COLUMN IF NOT EXISTS ust_id INT REFERENCES yorumlar(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS yorumlar_ust ON yorumlar (ust_id);

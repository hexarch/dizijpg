-- Kişi başı tek görüntülenme (2026-07-16 üçüncü parti)
CREATE TABLE IF NOT EXISTS yorum_goruntuleyen (
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  izleyen TEXT NOT NULL,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (yorum_id, izleyen)
);

-- Eski görüntülenme sayıları her yenilemede artıyordu (şişkin); benzersiz
-- sayıma geçerken sıfırlıyoruz, bundan sonra kişi başı tek sayılacak.
UPDATE yorumlar SET goruntulenme = 0;

#!/bin/bash
# Her JPEG için dHash (algısal parmak izi) üretir: 9x8 griye küçültüp
# komşu pikselleri karşılaştırır → 64 bit. Çıktı: "<hex16> <dosya>"
d="/var/lib/docker/volumes/dizijpg_dizijpg_dosyalar/_data/medya"
hash_one() {
  f="$1"
  ffmpeg -v error -i "$f" -vf "scale=9:8,format=gray" -f rawvideo - 2>/dev/null |
  od -An -tu1 -v | tr -s ' ' '\n' | grep -v '^$' |
  awk -v ad="$(basename "$f")" '
    {p[NR-1]=$1}
    END{
      if(NR<72){print "SKIP " ad; exit}
      bits=""
      for(y=0;y<8;y++) for(x=0;x<8;x++)
        bits = bits (p[y*9+x] > p[y*9+x+1] ? "1" : "0")
      # 64 biti 16 hex hanesine çevir
      out=""
      for(i=1;i<=64;i+=4){
        v=0
        for(j=0;j<4;j++) v = v*2 + substr(bits,i+j,1)
        out = out sprintf("%x", v)
      }
      print out " " ad
    }'
}
export -f hash_one
ls "$d"/m51-*.jpg | xargs -P 8 -I{} bash -c 'hash_one "$@"' _ {}

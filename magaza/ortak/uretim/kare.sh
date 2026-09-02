#!/bin/bash
# kullanım: SER=emulator-5556 OUT=dir kare.sh tap x y [bekle] | swipe x1 y1 x2 y2 [ms] [bekle] | cap ad | key code [bekle]
A=~/Library/Android/sdk/platform-tools/adb
cmd=$1; shift
case $cmd in
  tap) $A -s $SER shell input tap $1 $2; sleep ${3:-2};;
  swipe) $A -s $SER shell input swipe $1 $2 $3 $4 ${5:-400}; sleep ${6:-2};;
  key) $A -s $SER shell input keyevent $1; sleep ${2:-2};;
  cap) mkdir -p $OUT; $A -s $SER exec-out screencap -p > $OUT/$1.png
       python3 -c "
from PIL import Image
im=Image.open('$OUT/$1.png'); im=im.crop((0,64,1080,64+2160)); im.save('$OUT/$1.png'); print(im.size)";;
  raw) mkdir -p $OUT; $A -s $SER exec-out screencap -p > $OUT/$1.png; python3 -c "
from PIL import Image; im=Image.open('$OUT/$1.png'); im.resize((360,741)).save('$OUT/$1.small.png')";;
esac

"""Canlı siteyi GERÇEK cihaz emülasyonunda açıp ekran görüntüsü alır.

NEDEN: Flutter web tuvali erişilebilirlik ağacı vermediği için tarayıcı
otomasyonu metni bulamaz; gördüğümüzü kanıtlamanın tek yolu PİKSEL. `--headless
--screenshot --window-size` ise mobil emülasyon DEĞİLDİR (dokunmatik yok, UA
masaüstü kalır) — platformа göre değişen davranış (ör. uygulama daveti) orada
hiç görünmez. Bu araç CDP ile UA + cihaz ölçüleri + dokunmatiği birlikte kurar.

KİP'LER: android · ios · ipad (iPadOS 13+ kendini Macintosh tanıtır, dokunmatik
açık) · masaustu · bot (Googlebot mobil — SSR'a düşmeli).

Kullanım (sistem python3 + `pip install websocket-client`):
  python3 araclar/mobil_kesit.py https://dizijpg.com/ android /tmp/a.png 22
  python3 araclar/mobil_kesit.py https://dizijpg.com/ android /tmp/b.png 22 --tikla=346,620

TUZAK: aynı `--user-data-dir` localStorage'ı SAKLAR. "Kapattıktan sonra bir
daha çıkmıyor" gibi kalıcı kararları böyle kanıtlarsın; TEMİZ ziyaret için
profili silmen gerekir (`rm -rf /tmp/claude-501-davet-profile`).
"""
import json, subprocess, sys, time, urllib.request, base64
import websocket

URL = sys.argv[1]
KIP = sys.argv[2]
CIKTI = sys.argv[3]
BEKLE = float(sys.argv[4]) if len(sys.argv) > 4 and not sys.argv[4].startswith("--") else 14

UA = {
    "android": "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36",
    "ios": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
    "masaustu": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
    "bot": "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
    "ipad": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
}[KIP]
MOBIL = KIP != "masaustu"
TIKLA = None
for arg in sys.argv[4:]:
    if arg.startswith("--tikla="):
        TIKLA = [float(v) for v in arg.split("=", 1)[1].split(",")]
GENIS, YUKSEK = (834, 1112) if KIP == "ipad" else (390, 844) if MOBIL else (1280, 800)

CH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
port = 9344
proc = subprocess.Popen(
    [CH, "--headless=new", "--hide-scrollbars", f"--remote-debugging-port={port}",
     "--user-data-dir=/tmp/claude-501-davet-profile", "--no-first-run",
     "--use-gl=swiftshader", "--enable-unsafe-swiftshader", "about:blank"],
    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    for _ in range(60):
        try:
            tabs = [t for t in json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json")) if t.get("type") == "page"]
            if not tabs:
                raise RuntimeError("sayfa hedefi yok")
            break
        except Exception:
            time.sleep(0.2)
    ws = websocket.create_connection(tabs[0]["webSocketDebuggerUrl"], suppress_origin=True, timeout=240)
    mid = [0]

    def send(method, **params):
        mid[0] += 1
        ws.send(json.dumps({"id": mid[0], "method": method, "params": params}))
        while True:
            r = json.loads(ws.recv())
            if r.get("id") == mid[0]:
                if "error" in r:
                    raise SystemExit(f"{method}: {r['error']}")
                return r.get("result", {})

    send("Page.enable")
    send("Runtime.enable")
    send("Emulation.setUserAgentOverride", userAgent=UA)
    send("Emulation.setDeviceMetricsOverride", width=GENIS, height=YUKSEK,
         deviceScaleFactor=1, mobile=MOBIL)
    if MOBIL:
        send("Emulation.setTouchEmulationEnabled", enabled=True, maxTouchPoints=5)
    send("Page.navigate", url=URL)
    time.sleep(BEKLE)
    ua_gercek = send("Runtime.evaluate", expression="navigator.userAgent", returnByValue=True)
    print("UA:", ua_gercek["result"]["value"][:60])
    if TIKLA:
        x, y = TIKLA
        for tur in ("mousePressed", "mouseReleased"):
            send("Input.dispatchMouseEvent", type=tur, x=x, y=y, button="left",
                 clickCount=1, buttons=1 if tur == "mousePressed" else 0)
        time.sleep(2)
    veri = send("Page.captureScreenshot", format="png")["data"]
    open(CIKTI, "wb").write(base64.b64decode(veri))
    print("yazıldı:", CIKTI)
finally:
    proc.terminate()

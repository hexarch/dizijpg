import asyncio, json, sys
from playwright.async_api import async_playwright
URLS=sys.argv[1:]
JS="""
() => new Promise(res => {
  const out={lcp:null, cls:0, longTasks:0, tbt:0};
  try{
    new PerformanceObserver(l=>{for(const e of l.getEntries()) out.lcp=e.renderTime||e.loadTime;}).observe({type:'largest-contentful-paint',buffered:true});
    new PerformanceObserver(l=>{for(const e of l.getEntries()) if(!e.hadRecentInput) out.cls+=e.value;}).observe({type:'layout-shift',buffered:true});
    new PerformanceObserver(l=>{for(const e of l.getEntries()){out.longTasks++; out.tbt+=Math.max(0,e.duration-50);}}).observe({type:'longtask',buffered:true});
  }catch(e){}
  setTimeout(()=>{const n=performance.getEntriesByType('navigation')[0]; const p=performance.getEntriesByType('paint');
    out.ttfb=n&&n.responseStart; out.domContentLoaded=n&&n.domContentLoadedEventEnd; out.load=n&&n.loadEventEnd;
    out.fcp=(p.find(x=>x.name==='first-contentful-paint')||{}).startTime;
    out.transferKB=Math.round(performance.getEntriesByType('resource').reduce((a,r)=>a+(r.transferSize||0),0)/1024);
    out.resources=performance.getEntriesByType("resource").length; out.title=document.title;
    res(out);},12000);
})
"""
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch()
        for url in URLS:
            for dev in ['mobile','desktop']:
                if dev=='mobile':
                    ctx=await b.new_context(viewport={'width':390,'height':844},device_scale_factor=3,is_mobile=True,user_agent='Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Mobile Safari/537.36')
                else:
                    ctx=await b.new_context(viewport={'width':1366,'height':768})
                pg=await ctx.new_page()
                if dev=='mobile':
                    cdp=await ctx.new_cdp_session(pg)
                    await cdp.send('Network.emulateNetworkConditions',{'offline':False,'latency':150,'downloadThroughput':1.6*1024*1024/8,'uploadThroughput':750*1024/8})
                    await cdp.send('Emulation.setCPUThrottlingRate',{'rate':4})
                await pg.goto(url,wait_until='commit',timeout=90000)
                r=await pg.evaluate(JS)
                r.update(url=url,device=dev); print(json.dumps(r))
                await ctx.close()
        await b.close()
asyncio.run(main())

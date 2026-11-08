const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ deviceScaleFactor: 2, viewport: { width: 1400, height: 900 } });
  const out = process.argv[2];
  for (const [f, n] of [['pp.html','professionprofit-window.png'],['rt.html','rolltracker.png'],['flow.html','professionprofit-flow.png']]) {
    await p.goto('file://' + __dirname + '/' + f);
    await (await p.$('body > *')).screenshot({ path: out + '/' + n });
  }
  await b.close();
})();

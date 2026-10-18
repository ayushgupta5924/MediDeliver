// Isolated development test: fake API replies; never contacts a bank or production.
import {chromium} from 'playwright';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const files={'/upi.html':'text/html','/upi.js':'text/javascript','/checkout.css':'text/css','/vendor/qrcode.js':'text/javascript'};
let browser;
try {
  browser=await chromium.launch(process.env.TEST_CHROME ? {executablePath:process.env.TEST_CHROME} : {});
  for(const width of [390,1280]) {
    const page=await browser.newPage({viewport:{width,height:900}}), errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    let state={id:'test-session',mode:'mock',amount_paise:20950,status:'pending',expires_at:new Date(Date.now()+300000).toISOString(),payable:true,intent:null};
    await page.route('https://upi.test/**', async route => {
      const path=new URL(route.request().url()).pathname;
      if(!files[path]) return route.fulfill({status:404});
      await route.fulfill({contentType:files[path],body:readFileSync('web'+path)});
    });
    await page.route('**/api/upi/*',async route=>{
      if(route.request().url().endsWith('/claim')) {
        assert.equal(route.request().postDataJSON().utr,'123456789012'); state.status='review'; state.payable=false;
        await route.fulfill({json:{status:'review'}});
      } else await route.fulfill({json:state});
    });
    await page.goto(`https://upi.test/upi.html#${'a'.repeat(64)}`);
    await page.getByText('SIMULATION — No money will be requested or transferred.').waitFor();
    assert.equal(await page.locator('#qr').isVisible(),false);
    assert.equal(await page.locator('#intent').getAttribute('href'),null);
    await page.getByLabel('12-digit UPI transaction reference').fill('123456789012');
    await page.getByRole('button',{name:'Submit for bank verification'}).click();
    await page.getByText('Reference received. Bank verification is pending; do not pay again.').waitFor();
    state={...state,mode:'manual',payee_name:'<img src=x onerror=alert(1)>',vpa:'test@bank',status:'pending',payable:true,intent:'upi://pay?pa=test%40bank&am=209.50&cu=INR'};
    await page.getByRole('button',{name:'Refresh status'}).click();
    await page.locator('#qr:visible').waitFor();
    assert.match(await page.locator('#qr').getAttribute('src'),/^data:image\/gif;base64,/);
    assert.equal(await page.locator('#payee img').count(),0);
    state={...state,payable:false,intent:null,expires_at:'2000-01-01T00:00:00Z'};
    await page.getByRole('button',{name:'Refresh status'}).click();
    await page.getByText('Do not send another payment. Submit an existing reference or contact support.').waitFor();
    assert.equal(await page.locator('#qr').isVisible(),false);
    assert.deepEqual(errors,[]);
    await page.close(); console.log(`UPI checkout browser scenarios passed at ${width}px`);
  }
} finally {if(browser) await browser.close();}

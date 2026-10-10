import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
const origin='https://medideliver-eight.vercel.app';
mkdirSync('smoke-results',{recursive:true});
const health=await fetch(`${origin}/api/health`);
assert.equal(health.status,200);
assert.equal((await health.json()).paymentsEnabled,false);
assert.equal((await fetch(`${origin}/api/payments/create`)).status,503);
const browser=await chromium.launch();
try {
 for(const width of [1280,390]) {
  const page=await browser.newPage({viewport:{width,height:900}});
  const errors=[];
  try {
  page.on('pageerror',error=>errors.push(error.message));
  await page.goto(origin,{waitUntil:'networkidle'});
  const accessibility=page.getByRole('button',{name:'Enable accessibility'});
  // Flutter places this screen-reader activation target outside the visual viewport.
  if(await accessibility.count()) await accessibility.dispatchEvent('click');
  const demo=page.getByRole('button',{name:'Try the COD demo — no sign-in needed'});
  await demo.waitFor({timeout:60000});
  await page.screenshot({path:`smoke-results/login-${width}.png`});
  await demo.click();
  const tap=async name=>page.getByRole(['Customer','Pharmacy','Rider','Operations'].includes(name)?'checkbox':'button',{name,exact:true}).click();
  await tap('Pharmacy');
  await tap('Verified prescription / eligible medicine: quote');
  await tap('Customer');
  await tap('Accept total • Cash on delivery');
  await tap('Pharmacy');
  await tap('Start preparing');
  await tap('Ready for pickup');
  await tap('Rider');
  await tap('Accept delivery');
  await tap('Confirm pickup');
  await tap('Cash collected • Confirm delivery');
  await page.getByText('Cash collected: ₹209.50',{exact:true}).waitFor();
  await page.screenshot({path:`smoke-results/delivered-${width}.png`});
  assert.deepEqual(errors,[],'browser must not throw startup or interaction errors');
  } catch(error) {
    await page.screenshot({path:`smoke-results/failure-${width}.png`});
    writeFileSync(`smoke-results/failure-${width}.txt`,await page.locator('body').ariaSnapshot());
    throw error;
  } finally {await page.close();}
  console.log(`PASS: ${width}px demo COD flow; health OK; prepaid disabled`);
 }
} finally {await browser.close();}



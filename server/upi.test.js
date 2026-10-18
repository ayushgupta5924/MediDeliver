import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {upiConfig, upiService} from './upi.js';
import handler from '../api/upi/[action].js';
const env = {UPI_MODE: 'manual', DEMO_MODE: 'false', APP_URL: 'https://example.invalid',
  SUPABASE_URL: 'https://example.supabase.co', SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: 'secret',
  UPI_PAYEE_VPA: 'merchant@bank', UPI_PAYEE_NAME: 'Test Merchant'};
const row = {id:'10000000-0000-4000-8000-000000000001',mode:'manual',vpa:'merchant@bank',
  payee_name:'Test Merchant',amount_paise:20950,status:'pending',order_status:'quoted',expires_at:'2030-01-01T00:05:00Z'};
const token = 'a'.repeat(64);
test('UPI config fails closed and prevents real money in mock deployments', () => {
  assert.equal(upiConfig(env).UPI_MODE,'manual');
  for (const bad of [{UPI_MODE:'disabled'},{DEMO_MODE:'true'},{UPI_PAYEE_VPA:'evil@bank&am=1'},
    {UPI_PAYEE_NAME:'<script>'},{SUPABASE_SERVICE_ROLE_KEY:''},{APP_URL:'http://example.invalid'}])
    assert.throws(()=>upiConfig({...env,...bad}));
});
test('create ignores browser pricing and stores a hash, not the checkout capability', async () => {
  let params;
  const s = {rpc:async(name,p)=>{assert.equal(name,'upi_begin');params=p;}};
  const result = await upiService(s,env).create('customer',row.id);
  const t = result.url.split('#')[1];
  assert.match(t,/^[a-f0-9]{64}$/); assert.notEqual(params.p_hash,t);
  assert.equal(params.p_customer,'customer'); assert.equal(params.p_order,row.id);
  assert.equal('amount' in params,false); assert.equal('p_amount' in params,false);
});
test('intent uses immutable database payee and exact paise; mock and expired sessions have no payable URI', async () => {
  let current = row;
  const p = upiService({rpc:async()=>current},env,()=>Date.parse('2030-01-01T00:00:00Z'));
  const details = await p.details(token), uri = new URL(details.intent);
  assert.equal(uri.searchParams.get('am'),'209.50'); assert.equal(uri.searchParams.get('pa'),'merchant@bank');
  for (const patch of [{expires_at:'2020-01-01T00:00:00Z'},{status:'review'},{order_status:'cancelled'}]) {
    current={...row,...patch}; assert.equal((await p.details(token)).intent,null);
  }
  const mock=upiService({rpc:async()=>({...row,mode:'mock',vpa:null})},{...env,UPI_MODE:'mock'},()=>0);
  assert.equal((await mock.details(token)).intent,null);
});
test('invalid tokens and mode mismatches cannot access checkout; malformed references cannot reach claim RPC', async () => {
  const calls=[];
  const p=upiService({rpc:async(name)=>{calls.push(name);return row;}},env);
  await assert.rejects(p.details('bad')); assert.equal(calls.length,0);
  await assert.rejects(p.claim(token,'123')); assert.deepEqual(calls,['upi_checkout']);
  await assert.rejects(upiService({rpc:async()=>row},{...env,UPI_MODE:'mock'}).details(token));
});
test('UPI exposes no browser verification or observer webhook endpoint', async () => {
  for(const action of ['verify','webhook','success']) {
    const r=await handler.fetch(new Request(`https://example.invalid/api/upi/${action}`,{method:'POST',body:'{}'}));
    assert.equal(r.status,404);
  }
});
test('QR renderer is local and handles maximum supported UPI payload without external network', () => {
  const context=vm.createContext({});
  vm.runInContext(readFileSync('web/vendor/qrcode.js','utf8'),context);
  const qr=context.qrcode(0,'M');
  qr.addData('upi://pay?'+new URLSearchParams({pa:'x'.repeat(128)+'@'+'b'.repeat(64),pn:'M'.repeat(80),
    tr:row.id,tn:'MediDeliver '+row.id,am:'100000.00',cu:'INR'})); qr.make();
  assert.match(qr.createDataURL(4,16),/^data:image\/gif;base64,/);
});

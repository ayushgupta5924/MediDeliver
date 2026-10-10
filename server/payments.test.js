import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {validSignature,capturedPayment,hashToken} from './crypto.js';
import {paymentService} from './payments.js';
import {readBody} from './http.js';
import handler from '../api/payments/[action].js';
const secret='test-only-secret';
const sign=raw=>createHmac('sha256',secret).update(raw).digest('hex');
const env={RAZORPAY_KEY_SECRET:secret,RAZORPAY_WEBHOOK_SECRET:secret,RAZORPAY_KEY_ID:'rzp_test_demo',APP_URL:'https://example.invalid'};
const row={id:'11111111-1111-4111-8111-111111111111',provider_order_id:'order_abc',amount_paise:12345};
test('signatures cover raw bytes and reject malformed/tampered values',()=>{
  const raw=' {"event":"payment.captured"}';
  assert(validSignature(raw,sign(raw),secret));
  assert(!validSignature(raw.trim(),sign(raw),secret));
  for(const invalid of [null,'',sign(raw)+'0','z'.repeat(64)]) assert(!validSignature(raw,invalid,secret));
});
test('authorized, wrong amount/currency/order payments cannot fulfill',()=>{
  const p={id:'pay_abc',order_id:'order_abc',amount:12345,currency:'INR',status:'captured',captured:true};
  assert(capturedPayment(p,row));
  for(const change of [{amount:1},{currency:'USD'},{order_id:'order_other'},{status:'authorized'},{captured:false}]) assert(!capturedPayment({...p,...change},row));
});
test('lost provider creation response does not create a second order on retry',async()=>{
  let creates=0;
  const s={rpc:async name=>name==='payment_begin'?{...row,create_provider:false,provider_order_id:null}:null,razorpay:async()=>{creates++;}};
  await assert.rejects(paymentService(s,env).create('user',row.id),/reconciled/);
  assert.equal(creates,0);
});
test('create uses database price and an opaque short-lived checkout token',async()=>{
  const calls=[];
  const s={rpc:async(name,args)=>{calls.push([name,args]);return name==='payment_begin'?{...row,create_provider:true}:null;},razorpay:async(path,body)=>{
    assert.equal(body.amount,12345);assert.equal(body.receipt,row.id);assert.equal(path,'orders');
    return {id:'order_abc',amount:12345,currency:'INR'};
  }};
  const result=await paymentService(s,env).create('user',row.id);
  const token=new URL(result.url).hash.slice(1);
  assert.equal(token.length,64);
  assert.equal(calls.find(c=>c[0]==='payment_token')[1].p_token_hash,hashToken(token));
});
test('browser verification fetches captured state before writing',async()=>{
  let writes=0;
  const s={rpc:async name=>{if(name==='payment_captured') writes++;return row;},razorpay:async()=>({id:'pay_abc',order_id:'order_abc',status:'authorized',captured:false,amount:12345,currency:'INR'})};
  await assert.rejects(paymentService(s,env).verify({token:'a'.repeat(64),razorpay_order_id:'order_abc',razorpay_payment_id:'pay_abc',razorpay_signature:sign('order_abc|pay_abc')}),/not captured/);
  assert.equal(writes,0);
});
test('forged webhooks perform no database calls',async()=>{
  const s={rpc:async()=>{throw Error('should not reach database');}};
  await assert.rejects(paymentService(s,env).webhook('{}','a'.repeat(64)),/signature/);
});
test('duplicate valid webhooks reach the same idempotent database operation',async()=>{
  const writes=[];const s={rpc:async(name,args)=>{if(name==='payment_by_provider')return row;writes.push(args);return {status:'captured'};}};
  const raw=JSON.stringify({event:'payment.captured',payload:{payment:{entity:{id:'pay_abc',order_id:'order_abc',status:'captured',captured:true,amount:12345,currency:'INR'}}}});
  await paymentService(s,env).webhook(raw,sign(raw));await paymentService(s,env).webhook(raw,sign(raw));
  assert.equal(writes.length,2);assert.deepEqual(writes[0],writes[1]);
});
test('refund retries use a stable idempotency header and failures are per row',async()=>{
  const checked=[];
  const s={rpc:async(name,args)=>{if(name==='payment_work')return [
    {...row,status:'refund_pending',provider_payment_id:'pay_abc'},
    {...row,id:'other',status:'ready'},
  ];if(name==='payment_checked')checked.push(args);},razorpay:async(path,body,headers)=>{
    if(path.endsWith('/refund')) {assert.equal(headers['X-Refund-Idempotency'],row.id);throw Error('timeout');}
    return {items:[]};
  }};
  assert.deepEqual(await paymentService(s,env).reconcile(),{processed:1,failed:1});
  assert.deepEqual(checked.map(c=>c.p_failed),[true,false]);
});
test('oversized request is rejected without buffering it all',async()=>{
  await assert.rejects(readBody(new Request('https://example.invalid',{method:'POST',body:'a'.repeat(65537)})),/too large/);
});
test('payments are unavailable while merchant setup is disabled',async()=>{
  const previous=process.env.PAYMENTS_ENABLED;process.env.PAYMENTS_ENABLED='false';
  try {const r=await handler.fetch(new Request('https://example.invalid/api/payments/create',{method:'POST',body:'{}'}));assert.equal(r.status,503);}
  finally {if(previous===undefined)delete process.env.PAYMENTS_ENABLED;else process.env.PAYMENTS_ENABLED=previous;}
});

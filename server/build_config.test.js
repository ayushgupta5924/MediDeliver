import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve,dirname} from 'node:path';
import {spawnSync} from 'node:child_process';
const script=resolve('scripts/build_config.js');
const valid={SUPABASE_URL:'https://example.supabase.co',SUPABASE_ANON_KEY:'sb_publishable_test_configuration_key',APP_URL:'https://example.invalid',PAYMENTS_ENABLED:'false',DEMO_MODE:'true'};
function run(extra={}) {
  const cwd=mkdtempSync(join(tmpdir(),'medideliver-config-'));
  mkdirSync(join(cwd,'config'));
  try {
    const result=spawnSync(process.execPath,[script],{cwd,env:{...process.env,...valid,...extra},encoding:'utf8'});
    return {status:result.status,config:result.status===0?JSON.parse(readFileSync(join(cwd,'config/build.json'),'utf8')):null};
  } finally {
    const target=resolve(cwd), tempRoot=resolve(tmpdir());
    if(dirname(target)!==tempRoot || !target.startsWith(join(tempRoot,'medideliver-config-'))) throw Error('Unsafe temporary cleanup target');
    rmSync(target,{recursive:true,force:true});
  }
}
test('release config contains only public settings',()=>{
  const result=run({SUPABASE_SERVICE_ROLE_KEY:'server-only-test-marker',RAZORPAY_KEY_SECRET:'server-secret-marker'});
  assert.equal(result.status,0);assert.deepEqual(Object.keys(result.config).sort(),Object.keys(valid).sort());
  assert(!JSON.stringify(result.config).includes('server-secret-marker'));
});
test('build blocks insecure URLs, privileged keys and partial payment setup',()=>{
  for(const input of [
    {SUPABASE_URL:'http://example.supabase.co'},
    {SUPABASE_ANON_KEY:'sb_secret_never_ship'},
    {SUPABASE_ANON_KEY:`head.${Buffer.from('{"role":"service_role"}').toString('base64url')}.sig`},
    {PAYMENTS_ENABLED:'true',RAZORPAY_KEY_ID:''},
    {APP_URL:'https://example.invalid/path'},
    {DEMO_MODE:'yes'},
  ]) assert.notEqual(run(input).status,0);
});

test('fictional demo cannot enable checkout even with complete server settings',()=>{
  assert.notEqual(run({PAYMENTS_ENABLED:'true',RAZORPAY_KEY_ID:'test',RAZORPAY_KEY_SECRET:'test',RAZORPAY_WEBHOOK_SECRET:'test',SUPABASE_SERVICE_ROLE_KEY:'test',CRON_SECRET:'test'}).status,0);
  assert.equal(run({DEMO_MODE:'false'}).status,0);
});

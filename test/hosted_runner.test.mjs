import fs from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
test('dashboard runner requires verified admin access and expires', async () => {
  let handler;
  const originalFetch=globalThis.fetch, originalDeno=globalThis.Deno, originalNow=Date.now;
  Date.now=()=>Date.parse('2026-10-10T12:00:00Z');
  globalThis.fetch=async (url, init)=>{
    assert.equal(url,'https://mehtwvkvbjytnpjyzhxr.supabase.co/auth/v1/admin/users?page=1&per_page=1');
    return new Response(null,{status:init.headers.apikey==='fixture-service-key'?200:403});
  };
  globalThis.Deno={env:{get:()=>undefined},serve:fn=>{handler=fn}};
  try {
    const source=fs.readFileSync(new URL('../scripts/hosted_acceptance_function.ts',import.meta.url),'utf8');
    await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
    for(const auth of ['', 'Bearer anon','Bearer fixture-user']) assert.equal((await handler(new Request('https://fixture',{method:'POST',headers:{Authorization:auth}}))).status,401);
    const headers={'x-acceptance-service-key':'fixture-service-key'};
    assert.equal((await handler(new Request('https://fixture',{method:'POST',headers,body:'{}'}))).status,400);
    assert.equal((await handler(new Request('https://fixture',{headers}))).status,405);
    Date.now=()=>Date.parse('2026-10-12T00:00:00Z');
    assert.equal((await handler(new Request('https://fixture',{headers}))).status,410);
  } finally {globalThis.fetch=originalFetch;globalThis.Deno=originalDeno;Date.now=originalNow;}
});

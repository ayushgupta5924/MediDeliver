// Temporary dashboard runner for the same HTTP acceptance cases as test_hosted.py.
// Deploy manually only to the owner's MOCK project. Never accepts anon/user JWTs.
// Service credential stays inside Supabase dashboard/runtime; never returned/logged.
// Replace this deployment with HTTP 410 after the run. No automatic deployment.
const PROJECT = 'mehtwvkvbjytnpjyzhxr';
const EXPIRES = Date.parse('2026-10-11T00:00:00Z');
let busy = false;
export async function acceptance(env, fetcher = fetch) {
  const origin = env.url.replace(/\/$/, '');
  if (origin !== `https://${PROJECT}.supabase.co`) throw new Error('Wrong project');
  const run = crypto.randomUUID();
  const users = {}, sessions = {}, orders = [], uploads = [], passed = [], cleanupErrors = [];
  const pharmacy = crypto.randomUUID(); let createdPharmacy = false;
  const check = (name, condition = true) => { if (!condition) throw new Error(name); passed.push(name); };
  async function call(method, path, body, token, mime = 'application/json') {
    const response = await fetcher(origin + path, {method, headers: {
      apikey: token === env.service ? env.service : env.anon,
      Authorization: 'Bearer ' + (token || env.anon), 'Content-Type': mime,
    }, body: body === undefined ? undefined : mime === 'application/json' ? JSON.stringify(body) : body,
      signal: AbortSignal.timeout(20000)});
    const bytes = new Uint8Array(await response.arrayBuffer());
    let data;
    try { data = bytes.length ? JSON.parse(new TextDecoder().decode(bytes)) : null; } catch { data = bytes; }
    return {status: response.status, data};
  }
  async function ok(method, path, body, token, mime) {
    const r = await call(method, path, body, token, mime);
    if (r.status < 200 || r.status >= 300) throw new Error(`${method} ${path.split('?')[0]} HTTP ${r.status}`);
    return r.data;
  }
  const rpc = (role, name, args) => ok('POST', '/rest/v1/rpc/' + name, args, sessions[role]);
  const listed = async (role, id) => (await rpc(role, 'list_orders', {p_offset: 0})).find(x => x.id === id);
  const transition = (role, id, action) => rpc(role, 'transition_order', {p_id: id, p_action: action});
  async function deny(method, path, body, role = 'stranger', mime) {
    const r = await call(method, path, body, sessions[role], mime);
    if (![400,401,403,404,409,413,415,422].includes(r.status)) throw new Error(`Expected denial HTTP ${r.status}`);
  }
  let failure = null;
  try {
    const roles = {customer:'customer',stranger:'customer',pharmacy:'pharmacy_owner',rider:'delivery_partner',rider2:'delivery_partner',operator:'admin'};
    for (const [name, role] of Object.entries(roles)) {
      const email = `md-test-${run}-${name}@example.invalid`, password = crypto.randomUUID() + crypto.randomUUID();
      const user = await ok('POST','/auth/v1/admin/users',{email,password,email_confirm:true,user_metadata:{test_run:run}},env.service);
      users[name] = user.id;
      await ok('PATCH','/rest/v1/profiles?id=eq.'+user.id,{role,full_name:'Disposable mock '+name,service_postal_codes:['382010']},env.service);
      sessions[name] = (await ok('POST','/auth/v1/token?grant_type=password',{email,password})).access_token;
      const profile = await ok('GET','/rest/v1/profiles?select=role',undefined,sessions[name]);
      check('separate authenticated profile: '+name,profile.length===1 && profile[0].role===role);
    }
    await ok('POST','/rest/v1/pharmacies',{id:pharmacy,name:'Disposable mock test '+run,postal_codes:['382010'],active:true,
      pickup_address:'123 Fictional Test Road',contact_phone:'+919876543210',license_reference:'TEST-NOT-A-LICENSE',verified_at:new Date().toISOString()},env.service);
    createdPharmacy = true;
    await ok('POST','/rest/v1/pharmacy_members',{pharmacy_id:pharmacy,user_id:users.pharmacy},env.service);
    const lot = await rpc('pharmacy','save_inventory',{p_pharmacy_id:pharmacy,p_name:'Fictional test item',p_batch:run,
      p_expiry:new Date(Date.now()+365*86400000).toISOString().slice(0,10),p_price:9225,p_stock:10});
    const png = Uint8Array.from(atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg=='),c=>c.charCodeAt(0));
    const req = crypto.randomUUID(), path = `${users.customer}/${req}.png`;
    uploads.push(path);
    await ok('POST','/storage/v1/object/prescriptions/'+path,png,sessions.customer,'image/png');
    check('customer PNG upload');
    await deny('POST','/storage/v1/object/prescriptions/'+path,png,'customer','image/png');
    await deny('POST','/storage/v1/object/prescriptions/'+path,png,'stranger','image/png');
    const badPath = `${users.customer}/${crypto.randomUUID()}.txt`, bigPath = `${users.customer}/${crypto.randomUUID()}.png`;
    uploads.push(badPath,bigPath);
    await deny('POST','/storage/v1/object/prescriptions/'+badPath,'fictional','customer','text/plain');
    const big = new Uint8Array(5*1024*1024+png.length); big.set(png);
    await deny('POST','/storage/v1/object/prescriptions/'+bigPath,big,'customer','image/png');
    check('duplicate, foreign-folder, invalid MIME and oversized uploads denied');
    const args = {p_request_id:req,p_pharmacy_id:pharmacy,p_address:'12 Fictional Test Garden',p_postal_code:'382010',
      p_items:[],p_prescription_path:path,p_notes:'Synthetic acceptance image; not a prescription',p_recipient_phone:'+919876543210'};
    const order = (await rpc('customer','create_order',args)).id; orders.push(order);
    check('request replay is idempotent',(await rpc('customer','create_order',args)).id===order);
    check('foreign customer cannot list order',!await listed('stranger',order));
    check('pharmacy and operator can list assigned order',!!await listed('pharmacy',order) && !!await listed('operator',order));
    for (const role of ['stranger','rider','rider2']) {
      await deny('POST','/storage/v1/object/sign/prescriptions/'+path,{expiresIn:60},role);
      check('private image signing denied: '+role);
    }
    await deny('GET','/storage/v1/object/public/prescriptions/'+path,undefined,'anonymous');
    let signedPath;
    for (const role of ['customer','pharmacy','operator']) {
      const signed = (await ok('POST','/storage/v1/object/sign/prescriptions/'+path,{expiresIn:2},sessions[role])).signedURL;
      signedPath = signed.startsWith('/object/') ? '/storage/v1'+signed : signed;
      const downloaded = await ok('GET',signedPath);
      check('authorized signed image download: '+role,downloaded instanceof Uint8Array && downloaded.length===png.length && downloaded.every((b,i)=>b===png[i]));
    }
    await new Promise(resolve=>setTimeout(resolve,4000));
    await deny('GET',signedPath,undefined,'anonymous'); check('signed image expires');
    const quote = {p_id:order,p_lines:[{lot_id:lot,quantity:2}],p_delivery_fee:2500,p_review_note:'Fictional acceptance review'};
    await deny('POST','/rest/v1/rpc/quote_order',quote,'customer');
    await rpc('pharmacy','quote_order',quote);
    check('server computes itemized total',(await listed('customer',order)).quote_paise===20950);
    let stock = (await ok('GET','/rest/v1/inventory_lots?id=eq.'+lot,undefined,sessions.pharmacy))[0];
    check('quote reserves stock',stock.on_hand===10 && stock.reserved===2);
    await transition('customer',order,'confirm'); await transition('pharmacy',order,'prepare'); await transition('pharmacy',order,'ready');
    const redacted = await listed('rider',order);
    check('rider dispatch view hides medical and recipient information',redacted.delivery_address==='' && redacted.recipient_phone==='' && !('prescription_path' in redacted) && !('items' in redacted));
    const race = await Promise.all(['rider','rider2'].map(async role=>({role,...await call('POST','/rest/v1/rpc/transition_order',{p_id:order,p_action:'accept'},sessions[role])})));
    const winners = race.filter(x=>x.status>=200 && x.status<300);
    check('concurrent rider acceptance has one winner',winners.length===1); const winner = winners[0].role;
    check('assigned rider receives delivery contact',(await listed(winner,order)).recipient_phone==='+919876543210');
    check('rider cannot bypass redacted RPC',(await ok('GET','/rest/v1/orders?id=eq.'+order,undefined,sessions[winner])).length===0);
    await transition(winner,order,'pickup'); await transition(winner,order,'deliver');
    const delivered = await listed('customer',order);
    check('COD delivered with cash collection',delivered.status==='delivered' && delivered.payment_status==='cash_collected');
    const riderView = await listed(winner,order);
    check('completed rider contact removed',riderView.delivery_address==='' && riderView.recipient_phone==='');
    stock = (await ok('GET','/rest/v1/inventory_lots?id=eq.'+lot,undefined,sessions.pharmacy))[0];
    check('delivery deducts stock exactly once',stock.on_hand===8 && stock.reserved===0);
    await deny('POST','/rest/v1/rpc/transition_order',{p_id:order,p_action:'deliver'},winner); check('duplicate delivery denied');
  } catch (error) { failure = String(error.message).slice(0,250); }
  finally {
    const cleanup = [];
    if (uploads.length) cleanup.push(['DELETE','/storage/v1/object/prescriptions',{prefixes:uploads}]);
    for (const id of orders) {
      for (const table of ['order_events','order_lots']) cleanup.push(['DELETE','/rest/v1/'+table+'?order_id=eq.'+id]);
      cleanup.push(['DELETE','/rest/v1/orders?id=eq.'+id]);
    }
    if (createdPharmacy) {
      for (const table of ['inventory_lots','pharmacy_members']) cleanup.push(['DELETE','/rest/v1/'+table+'?pharmacy_id=eq.'+pharmacy]);
      cleanup.push(['DELETE','/rest/v1/pharmacies?id=eq.'+pharmacy]);
    }
    for (const token of Object.values(sessions)) {
      try { await ok('POST','/auth/v1/logout?scope=global',undefined,token); } catch { cleanupErrors.push('session logout'); }
    }
    for (const id of Object.values(users)) cleanup.push(['DELETE','/auth/v1/admin/users/'+id]);
    for (const [method,path,body] of cleanup) {
      try { await ok(method,path,body,env.service); } catch { cleanupErrors.push(path); }
    }
  }
  return {project:PROJECT,run,passed,passCount:passed.length,failure,cleanupErrors,success:!failure && !cleanupErrors.length};
}
Deno.serve(async request => {
  const service = request.headers.get('x-acceptance-service-key') || request.headers.get('Authorization')?.replace(/^Bearer /,'');
  if (!service) return new Response('Unauthorized',{status:401});
  const authCheck = await fetch(`https://${PROJECT}.supabase.co/auth/v1/admin/users?page=1&per_page=1`,{headers:{apikey:service,Authorization:'Bearer '+service}});
  await authCheck.body?.cancel();
  if (!authCheck.ok) return new Response('Unauthorized',{status:401});
  if (Date.now()>EXPIRES) return new Response('Runner expired',{status:410});
  if (request.method!=='POST') return new Response('POST required',{status:405});
  const body = await request.json().catch(()=>null);
  if (body?.confirmProject!==PROJECT || body?.mockOnly!==true) return new Response('Explicit mock project confirmation required',{status:400});
  if (busy) return new Response('Test already running',{status:409});
  busy=true;
  try {
    const result = await acceptance({url:Deno.env.get('SUPABASE_URL'),anon:Deno.env.get('SUPABASE_ANON_KEY'),service});
    return Response.json(result,{status:result.success?200:500});
  } finally {busy=false;}
});

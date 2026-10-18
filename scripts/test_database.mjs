// In-process PostgreSQL check for hosts without Docker. CI also tests real Supabase.
import {PGlite} from '@electric-sql/pglite';
import {readFileSync,readdirSync} from 'node:fs';
const db=new PGlite();
await db.exec(`
create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
create schema auth; create schema storage;
create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}');
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema auth,storage to authenticated,anon,service_role;
grant execute on function auth.uid() to authenticated,anon,service_role;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
create function storage.foldername(name text) returns text[] language sql immutable as $$select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1]$$;
alter table storage.objects enable row level security;
grant select,insert,update,delete on storage.objects to authenticated;
`);
for(const file of readdirSync('supabase/migrations').sort()) {
  await db.exec(readFileSync(`supabase/migrations/${file}`,'utf8'));
  console.log(`Applied ${file}`);
}
async function runPsqlFile(file) {
  const vars={};let block=[];
  const substitute=text=>text.replace(/:'([a-z_]+)'/g,(_,key)=>{
    if(!(key in vars))throw Error(`Unknown test variable ${key}`);
    return `'${String(vars[key]).replaceAll("'","''")}'`;
  });
  for(const line of readFileSync(file,'utf8').split('\n')) {
    if(line.startsWith('\\echo'))continue;
    if(line.includes('\\gset')) {
      if(block.length)await db.exec(substitute(block.join('\n')));
      const result=await db.query(substitute(line.replace('\\gset','')));
      Object.assign(vars,result.rows[0]);block=[];
    } else block.push(line);
  }
  if(block.length)await db.exec(substitute(block.join('\n')));
  console.log(`Passed ${file}`);
}
try {
  await runPsqlFile('supabase/tests/workflow.sql');
  await runPsqlFile('supabase/tests/production.sql');
  await runPsqlFile('supabase/tests/upi.sql');
  await db.exec(readFileSync('supabase/seed.sql','utf8'));
  await db.exec(readFileSync('supabase/seed.sql','utf8'));
  console.log('Fictional seed applies and reruns successfully');
  await db.exec(readFileSync('supabase/sample_listings.sql','utf8'));
  await db.exec(readFileSync('supabase/sample_listings.sql','utf8'));
  await db.exec(`set role authenticated; select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false)`);
  const catalog = await db.query(`select * from public.pharmacy_catalog('21000000-0000-4000-8000-000000000001')`);
  if(catalog.rows.length!==6 || Object.keys(catalog.rows[0]).sort().join(',')!=='from_price_paise,medicine_name') throw Error('Catalog projection failed');
  const privateLots = await db.query(`select * from public.inventory_lots where pharmacy_id='21000000-0000-4000-8000-000000000001'`);
  if(privateLots.rows.length) throw Error('Customer can read private lots');
  await db.exec(`reset role; update public.pharmacies set active=false where id='21000000-0000-4000-8000-000000000001'; set role authenticated`);
  if((await db.query(`select * from public.pharmacy_catalog('21000000-0000-4000-8000-000000000001')`)).rows.length) throw Error('Inactive pharmacy listed');
  await db.exec(`reset role; set role anon`);
  let denied=false;
  try {await db.query(`select * from public.pharmacy_catalog('21000000-0000-4000-8000-000000000002')`);} catch {denied=true;}
  if(!denied) throw Error('Anonymous catalog access permitted');
  await db.exec('reset role');
  console.log('Catalog permissions, projection, inactive filtering and repeatable sample listings passed');

} finally {await db.close();}

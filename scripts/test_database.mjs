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
} finally {await db.close();}

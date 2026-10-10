import {writeFileSync} from 'node:fs';
const {SUPABASE_URL:url,SUPABASE_ANON_KEY:key,APP_URL:explicitApp,PAYMENTS_ENABLED:payments='false',DEMO_MODE:demo='true'}=process.env;
const host=process.env.VERCEL_ENV==='production'?process.env.VERCEL_PROJECT_PRODUCTION_URL:process.env.VERCEL_URL;
const app=explicitApp||(host?`https://${host}`:null);
if(!url||!key||!app) throw Error('Set SUPABASE_URL, SUPABASE_ANON_KEY and APP_URL');
for(const value of [url,app]) {
  const u=new URL(value);
  if(u.protocol!=='https:'||u.username||u.password||u.search||u.hash||u.pathname!=='/') throw Error('Production URLs must be HTTPS origins');
}
let publicKey=key.startsWith('sb_publishable_')&&key.length>25;
try {publicKey ||= JSON.parse(Buffer.from(key.split('.')[1]??'','base64url').toString()).role==='anon';} catch {}
if(!publicKey) throw Error('Client key must be publishable or anon, never a secret/service-role key');
if(!['true','false'].includes(payments)) throw Error('PAYMENTS_ENABLED must be true or false');
if(!['true','false'].includes(demo)) throw Error('DEMO_MODE must be true or false');
if(demo==='true'&&payments==='true') throw Error('Online payments cannot be enabled for a fictional demo');
if(payments==='true'&&(!process.env.RAZORPAY_KEY_ID||!process.env.RAZORPAY_KEY_SECRET||!process.env.RAZORPAY_WEBHOOK_SECRET||!process.env.SUPABASE_SERVICE_ROLE_KEY||!process.env.CRON_SECRET)) throw Error('Payment server settings missing');
writeFileSync('config/build.json',JSON.stringify({SUPABASE_URL:url,SUPABASE_ANON_KEY:key,APP_URL:app.replace(/\/$/,''),PAYMENTS_ENABLED:payments,DEMO_MODE:demo}));

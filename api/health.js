import {json} from '../server/http.js';
export default {async fetch() {
  const ready=!!process.env.SUPABASE_URL && !!process.env.SUPABASE_ANON_KEY;
  return json({service:'MediDeliver',configured:ready,paymentsEnabled:process.env.PAYMENTS_ENABLED==='true'},ready?200:503);
}};

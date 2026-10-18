import {HttpError} from './services.js';
import {hashToken, newToken} from './crypto.js';

export function upiConfig(env) {
  const mode = env.UPI_MODE ?? 'disabled';
  if (!['mock', 'manual'].includes(mode)) throw new HttpError(503, 'UPI is not enabled');
  if ((mode === 'manual' && env.DEMO_MODE !== 'false') ||
      (mode === 'mock' && env.DEMO_MODE !== 'true')) throw new HttpError(503, 'UPI mode does not match this deployment');
  for (const key of ['SUPABASE_URL', 'APP_URL']) {
    let u;
    try { u = new URL(env[key]); } catch { throw new HttpError(503, 'UPI configuration missing'); }
    if (u.protocol !== 'https:' || u.username || u.password || u.pathname !== '/' || u.hash || u.search)
      throw new HttpError(503, 'Invalid UPI configuration');
  }
  if (!env.SUPABASE_ANON_KEY || !env.SUPABASE_SERVICE_ROLE_KEY) throw new HttpError(503, 'UPI configuration missing');
  if (mode === 'manual' && (!/^[a-zA-Z0-9._-]{2,128}@[a-zA-Z0-9.-]{2,64}$/.test(env.UPI_PAYEE_VPA ?? '') ||
      !/^[a-zA-Z0-9 .&'-]{2,80}$/.test(env.UPI_PAYEE_NAME ?? ''))) throw new HttpError(503, 'Merchant UPI configuration missing');
  return {...env, UPI_MODE: mode};
}

// No SMS observer or browser callback can mark a payment as received.
export function upiService(s, env, clock = () => Date.now()) {
  async function checkout(token) {
    if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) throw new HttpError(401, 'Checkout expired; reopen from your order');
    const row = await s.rpc('upi_checkout', {p_hash: hashToken(token)});
    if (!row || row.mode !== env.UPI_MODE) throw new HttpError(401, 'Checkout expired; reopen from your order');
    return row;
  }
  return {
    async create(userId, orderId) {
      if (!/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(orderId ?? '')) throw new HttpError(400, 'Invalid order');
      const token = newToken();
      await s.rpc('upi_begin', {p_customer: userId, p_order: orderId, p_mode: env.UPI_MODE,
        p_vpa: env.UPI_MODE === 'mock' ? null : env.UPI_PAYEE_VPA,
        p_name: env.UPI_MODE === 'mock' ? 'MediDeliver simulation' : env.UPI_PAYEE_NAME, p_hash: hashToken(token)});
      return {url: `${env.APP_URL.replace(/\/$/, '')}/upi.html#${token}`};
    },
    async details(token) {
      const row = await checkout(token);
      const payable = row.status === 'pending' && row.order_status === 'quoted' && Date.parse(row.expires_at) > clock();
      const result = {...row, payable, intent: null};
      if (payable && row.mode === 'manual') {
        result.intent = 'upi://pay?' + new URLSearchParams({pa: row.vpa, pn: row.payee_name,
          tr: row.id, tn: `MediDeliver ${row.id}`, am: (row.amount_paise / 100).toFixed(2), cu: 'INR'});
      }
      return result;
    },
    async claim(token, utr) {
      await checkout(token);
      if (typeof utr !== 'string' || !/^\d{12}$/.test(utr)) throw new HttpError(400, 'Enter the 12-digit UPI reference');
      return s.rpc('upi_claim', {p_hash: hashToken(token), p_utr: utr});
    },
  };
}

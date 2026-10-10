export class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
export function config(env = process.env) {
  const keys = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY', 'APP_URL',
    'RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET', 'RAZORPAY_WEBHOOK_SECRET'];
  for (const key of keys) if (!env[key]) throw new HttpError(503, 'Service is not configured');
  for (const key of ['SUPABASE_URL', 'APP_URL']) {
    const url = new URL(env[key]);
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || url.pathname !== '/') {
      throw new HttpError(503, 'Service is not configured');
    }
  }
  return env;
}
export function services(env, fetcher = fetch) {
  async function request(url, options) {
    let response;
    try { response = await fetcher(url, {...options, signal: AbortSignal.timeout(15000)}); }
    catch { throw new HttpError(502, 'Provider request could not be confirmed'); }
    if (!response.ok) throw new HttpError(502, 'Provider request could not be confirmed');
    return response.status === 204 ? null : response.json();
  }
  return {
    rpc: (name, body) => request(`${env.SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/${name}`, {
      method: 'POST', headers: {'Content-Type': 'application/json', apikey: env.SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`}, body: JSON.stringify(body),
    }),
    user: async (header) => {
      if (!/^Bearer \S+$/.test(header ?? '')) throw new HttpError(401, 'Sign in required');
      const response = await fetcher(`${env.SUPABASE_URL.replace(/\/$/, '')}/auth/v1/user`, {
        headers: {apikey: env.SUPABASE_ANON_KEY, Authorization: header}, signal: AbortSignal.timeout(10000),
      });
      if (!response.ok) throw new HttpError(401, 'Sign in required');
      const user = await response.json();
      if (!user.id) throw new HttpError(401, 'Sign in required');
      return user;
    },
    razorpay: (path, body, extraHeaders = {}) => request(`https://api.razorpay.com/v1/${path}`, {
      method: body ? 'POST' : 'GET', headers: {'Content-Type': 'application/json',
        Authorization: `Basic ${Buffer.from(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`).toString('base64')}`,
        ...extraHeaders}, ...(body ? {body: JSON.stringify(body)} : {}),
    }),
  };
}

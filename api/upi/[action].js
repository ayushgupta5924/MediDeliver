import {services, HttpError} from '../../server/services.js';
import {upiConfig, upiService} from '../../server/upi.js';
import {readBody, json, errorResponse} from '../../server/http.js';
export default {async fetch(request) {
  try {
    const action = new URL(request.url).pathname.split('/').pop();
    if (!['create', 'checkout', 'claim'].includes(action)) throw new HttpError(404, 'Not found');
    const env = upiConfig(process.env);
    if (request.method !== 'POST') throw new HttpError(405, 'Use POST');
    const origin = request.headers.get('origin');
    if (origin && origin !== new URL(env.APP_URL).origin) throw new HttpError(403, 'Origin not permitted');
    let body;
    try { body = JSON.parse(await readBody(request)); } catch (e) {
      if (e instanceof HttpError) throw e;
      throw new HttpError(400, 'Invalid JSON');
    }
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new HttpError(400, 'Invalid JSON object');
    const s = services(env), upi = upiService(s, env);
    if (action === 'create') return json(await upi.create((await s.user(request.headers.get('authorization'))).id, body.order_id));
    return json(action === 'checkout' ? await upi.details(body.token) : await upi.claim(body.token, body.utr));
  } catch (e) { return errorResponse(e); }
}};

import { config, services, HttpError } from '../../server/services.js';
import { paymentService } from '../../server/payments.js';
import {readBody,json,errorResponse} from '../../server/http.js';
export default {async fetch(request) {
  try {
    const action = new URL(request.url).pathname.split('/').pop();
    if(['create','checkout'].includes(action) && process.env.PAYMENTS_ENABLED!=='true') throw new HttpError(503,'Online payments are not enabled');
    const env = config();
    const origin = request.headers.get('origin');
    if (origin && origin !== new URL(env.APP_URL).origin) throw new HttpError(403, 'Origin not permitted');
    if (request.method !== 'POST') throw new HttpError(405, 'Use POST');
    const s = services(env); const payments = paymentService(s, env);
    const raw = await readBody(request);
    let result;
    if (action === 'webhook') result = await payments.webhook(raw, request.headers.get('x-razorpay-signature'));
    else {
      let body;
      try { body = JSON.parse(raw); } catch { throw new HttpError(400, 'Invalid JSON'); }
      if (!body || typeof body !== 'object' || Array.isArray(body)) throw new HttpError(400,'Invalid JSON object');
      if (action === 'create') result = await payments.create((await s.user(request.headers.get('authorization'))).id, body.order_id);
      else if (action === 'checkout') result = await payments.details(body.token);
      else if (action === 'verify') result = await payments.verify(body);
      else throw new HttpError(404, 'Not found');
    }
    return json(result);
  } catch (error) {
    return errorResponse(error);
  }
}};

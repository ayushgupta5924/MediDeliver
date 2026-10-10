import {config,services,HttpError} from '../server/services.js';
import {paymentService} from '../server/payments.js';
import {json,errorResponse} from '../server/http.js';
export default {async fetch(request) {
  try {
    if(!process.env.CRON_SECRET || request.headers.get('authorization')!==`Bearer ${process.env.CRON_SECRET}`) throw new HttpError(401,'Not authorized');
    if(!['GET','POST'].includes(request.method)) throw new HttpError(405,'Method not permitted');
    const env=config(); const result=await paymentService(services(env),env).reconcile();
    return json(result,result.failed?503:200);
  } catch(error) {return errorResponse(error);}
}};

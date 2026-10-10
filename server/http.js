import { HttpError } from './services.js';
export async function readBody(request) {
  const reader = request.body?.getReader();
  if (!reader) return '';
  const parts = []; let length = 0;
  while (true) {
    const {done, value} = await reader.read();
    if (done) break;
    length += value.byteLength;
    if (length > 65536) { await reader.cancel(); throw new HttpError(413, 'Request too large'); }
    parts.push(Buffer.from(value));
  }
  return Buffer.concat(parts).toString('utf8');
}
export function json(body,status=200) {
  return Response.json(body,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
}
export function errorResponse(error) {
  return json({error:error instanceof HttpError?error.message:'Request could not be completed'},error instanceof HttpError?error.status:500);
}

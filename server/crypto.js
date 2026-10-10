import { createHmac, createHash, timingSafeEqual, randomBytes } from 'node:crypto';

export const hashToken = value => createHash('sha256').update(value).digest('hex');
export const newToken = () => randomBytes(32).toString('hex');
export function validSignature(body, signature, secret) {
  if (typeof signature !== 'string' || !/^[a-f0-9]{64}$/i.test(signature) || !secret) return false;
  const expected = createHmac('sha256', secret).update(body).digest();
  return timingSafeEqual(expected, Buffer.from(signature, 'hex'));
}
export function capturedPayment(payment, expected) {
  return payment?.status === 'captured' && payment.captured === true &&
    payment.order_id === expected.provider_order_id && payment.currency === 'INR' &&
    Number.isSafeInteger(payment.amount) && payment.amount === expected.amount_paise;
}

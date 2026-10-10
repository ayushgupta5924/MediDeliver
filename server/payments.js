import { capturedPayment, hashToken, newToken, validSignature } from './crypto.js';
import { HttpError } from './services.js';

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const providerId = /^(pay|order)_[a-zA-Z0-9]+$/;
export function paymentService(s, env) {
  async function checkout(token) {
    if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) throw new HttpError(401, 'Checkout expired');
    const row = await s.rpc('payment_checkout', {p_token_hash: hashToken(token)});
    if (!row) throw new HttpError(401, 'Checkout expired');
    return row;
  }
  async function apply(payment) {
    if (!/^order_[A-Za-z0-9]+$/.test(payment?.order_id ?? '') || !/^pay_[A-Za-z0-9]+$/.test(payment?.id ?? '')) throw new HttpError(400, 'Invalid payment');
    const row = await s.rpc('payment_by_provider', {p_provider_order_id: payment.order_id});
    if (!row) return {ignored: true};
    if (!capturedPayment(payment, row)) throw new HttpError(409, 'Payment not captured or amount mismatch');
    return s.rpc('payment_captured', {p_provider_order_id: payment.order_id,
      p_payment_id: payment.id, p_amount: payment.amount});
  }
  return {
    async create(userId, orderId) {
      if (!uuid.test(orderId ?? '')) throw new HttpError(400, 'Invalid order');
      const row = await s.rpc('payment_begin', {p_customer_id: userId, p_order_id: orderId});
      if (row.create_provider) {
        // No retry after an ambiguous network result: an operator reconciles by receipt.
        // This avoids generating another payable order after a lost provider response.
        const provider = await s.razorpay('orders', {amount: row.amount_paise, currency: 'INR', receipt: row.id});
        if (!providerId.test(provider?.id ?? '') || !provider.id.startsWith('order_') ||
            provider.amount !== row.amount_paise || provider.currency !== 'INR') {
          throw new HttpError(502, 'Provider order could not be confirmed');
        }
        await s.rpc('payment_attach', {p_id: row.id, p_provider_order_id: provider.id});
      } else if (!row.provider_order_id) {
        throw new HttpError(409, 'Checkout is being reconciled. Please contact support before retrying.');
      }
      const token = newToken();
      await s.rpc('payment_token', {p_customer_id: userId, p_id: row.id, p_token_hash: hashToken(token)});
      return {url: `${env.APP_URL.replace(/\/$/, '')}/checkout.html#${token}`};
    },
    async details(token) {
      const row = await checkout(token);
      return {key: env.RAZORPAY_KEY_ID, order_id: row.provider_order_id, amount: row.amount_paise,
        currency: 'INR', name: 'MediDeliver'};
    },
    async verify(body) {
      const row = await checkout(body.token);
      if (!providerId.test(body.razorpay_payment_id ?? '') || !body.razorpay_payment_id.startsWith('pay_') ||
          body.razorpay_order_id !== row.provider_order_id ||
          !validSignature(`${row.provider_order_id}|${body.razorpay_payment_id}`, body.razorpay_signature, env.RAZORPAY_KEY_SECRET)) {
        throw new HttpError(400, 'Invalid payment signature');
      }
      return apply(await s.razorpay(`payments/${body.razorpay_payment_id}`));
    },
    async webhook(raw, signature) {
      if (!validSignature(raw, signature, env.RAZORPAY_WEBHOOK_SECRET)) throw new HttpError(400, 'Invalid webhook signature');
      let event;
      try { event = JSON.parse(raw); } catch { throw new HttpError(400, 'Invalid webhook'); }
      if (event.event === 'payment.captured' || event.event === 'order.paid') {
        return apply(event.payload?.payment?.entity);
      }
      if (event.event === 'refund.processed') {
        const refund = event.payload?.refund?.entity;
        if (refund?.status !== 'processed' || !/^rfnd_[a-zA-Z0-9]+$/.test(refund.id ?? '') ||
            !/^pay_[a-zA-Z0-9]+$/.test(refund.payment_id ?? '') || !Number.isSafeInteger(refund.amount)) {
          throw new HttpError(400, 'Invalid refund event');
        }
        await s.rpc('payment_refunded', {p_payment_id: refund.payment_id, p_refund_id: refund.id, p_amount: refund.amount});
      }
      return {received: true};
    },
    async reconcile() {
      const rows = await s.rpc('payment_work', {});
      let processed = 0, failed = 0;
      for (const row of rows) {
        let rowFailed = false;
        try {
          if (row.status === 'refund_pending') {
            const refund = await s.razorpay(`payments/${row.provider_payment_id}/refund`, {
              amount: row.amount_paise, speed: 'normal', receipt: row.id,
            }, {'X-Refund-Idempotency': row.id});
            if (!/^rfnd_[A-Za-z0-9]+$/.test(refund.id ?? '') || refund.amount !== row.amount_paise || refund.payment_id !== row.provider_payment_id) {
              throw new HttpError(409, 'Refund mismatch');
            }
            const current = refund.status === 'processed' ? refund : await s.razorpay(`refunds/${refund.id}`);
            if (current.status === 'failed' || current.amount !== row.amount_paise || current.payment_id !== row.provider_payment_id) {
              throw new HttpError(409, 'Refund needs operator review');
            }
            if (current.status === 'processed') {
              await s.rpc('payment_refunded', {p_payment_id: row.provider_payment_id, p_refund_id: refund.id, p_amount: refund.amount});
            }
          } else if (row.provider_order_id) {
            const list = await s.razorpay(`orders/${row.provider_order_id}/payments`);
            for (const payment of list.items ?? []) if (payment.status === 'captured') await apply(payment);
          } else {
            // A create timeout may still have committed at Razorpay. Search by receipt;
            // never create a second provider order automatically.
            const list = await s.razorpay(`orders?receipt=${encodeURIComponent(row.id)}&count=100`);
            const matches = (list.items ?? []).filter(o => o.receipt === row.id && o.amount === row.amount_paise && o.currency === 'INR');
            if (matches.length !== 1) throw new HttpError(409, 'Manual reconciliation required');
            await s.rpc('payment_attach', {p_id: row.id, p_provider_order_id: matches[0].id});
          }
          processed++;
        } catch { failed++; rowFailed = true; }
        await s.rpc('payment_checked', {p_id: row.id, p_failed: rowFailed});
      }
      return {processed, failed};
    },
  };
}

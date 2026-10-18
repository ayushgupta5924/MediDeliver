/* Only an expiring checkout capability is stored here, never a login session. */
(() => {
  const el = id => document.getElementById(id);
  let token = location.hash.slice(1), timer;
  try {
    if (token) sessionStorage.setItem('md-upi', token);
    else token = sessionStorage.getItem('md-upi');
  } catch { /* Checkout still works if session storage is unavailable. */ }
  history.replaceState(null, '', '/upi.html');
  async function call(action, body) {
    const r = await fetch(`/api/upi/${action}`, {method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({token, ...body}), signal: AbortSignal.timeout(25000)});
    const result = await r.json();
    if (!r.ok) throw Error(result.error || 'Could not check payment');
    return result;
  }
  function hidePayment() {
    el('intent').hidden = true;
    el('qr').hidden = true;
    el('qr').removeAttribute('src');
    el('intent').removeAttribute('href');
  }
  async function refresh() {
    el('refresh').disabled = true;
    hidePayment();
    el('claim').hidden = true;
    clearInterval(timer);
    try {
      const d = await call('checkout', {});
      el('total').textContent = `Order total: ₹${(d.amount_paise / 100).toFixed(2)}`;
      el('reference').textContent = `Checkout reference: ${d.id}`;
      el('payee').textContent = d.mode === 'mock' ? 'SIMULATION — No money will be requested or transferred.' : `Merchant: ${d.payee_name} • UPI ID: ${d.vpa}`;
      const messages = {pending: 'Awaiting payment reference.', review: 'Reference received. Bank verification is pending; do not pay again.',
        verified: 'Payment verified. Return to your order.', refund_pending: 'A full refund needs operator processing. Contact support; do not pay again.', refunded: 'The operator has recorded your completed refund.'};
      el('status').textContent = messages[d.status] || 'Contact support for payment status.';
      el('guidance').textContent = d.mode === 'mock'
        ? 'Enter a fictional 12-digit reference to test review. An operator must approve the simulated credit before fulfillment.'
        : 'Check the merchant name and exact amount in your UPI app. Never share your UPI PIN. Returning from the app does not confirm payment. Only merchant bank verification releases the order.';
      el('claim').hidden = d.status !== 'pending';
      function tick() {
        const seconds = Math.max(0, Math.ceil((Date.parse(d.expires_at) - Date.now()) / 1000));
        el('expiry').textContent = d.payable && seconds > 0 ? `Payment window: ${seconds}s` : 'Do not send another payment. Submit an existing reference or contact support.';
        if (seconds <= 0) hidePayment();
      }
      if (d.intent && d.intent.startsWith('upi://pay?')) {
        const qr = qrcode(0, 'M');
        qr.addData(d.intent); qr.make();
        el('qr').src = qr.createDataURL(4, 16);
        el('qr').hidden = false;
        el('intent').href = d.intent;
        el('intent').hidden = false;
      }
      tick(); timer = setInterval(tick, 1000);
    } catch (e) { el('status').textContent = `${e.message}. If you have paid, do not pay again; reopen your order or contact support.`; }
    finally { el('refresh').disabled = false; }
  }
  el('claim').onsubmit = async event => {
    event.preventDefault(); el('submit').disabled = true;
    try { await call('claim', {utr: el('utr').value}); await refresh(); }
    catch (e) { el('status').textContent = e.message; }
    finally { el('submit').disabled = false; }
  };
  el('refresh').onclick = refresh;
  addEventListener('pagehide', () => clearInterval(timer));
  refresh();
})();

import test from 'node:test';
import assert from 'node:assert/strict';
import health from '../netlify/functions/health.mjs';
import upi from '../netlify/functions/upi.mjs';
import payments from '../netlify/functions/payments.mjs';
import reconcile from '../netlify/functions/reconcile.mjs';

test('Netlify adapters preserve API fail-closed responses', async () => {
  const saved = {...process.env};
  try {
    delete process.env.SUPABASE_URL;
    delete process.env.SUPABASE_ANON_KEY;
    delete process.env.CRON_SECRET;
    process.env.PAYMENTS_ENABLED = 'false';
    assert.equal((await health(new Request('https://example.netlify.app/api/health'))).status, 503);
    assert.equal((await upi(new Request('https://example.netlify.app/api/upi/verify'))).status, 404);
    assert.equal((await payments(new Request('https://example.netlify.app/api/payments/create', {method:'POST'}))).status, 503);
    assert.equal((await reconcile(new Request('https://example.netlify.app/api/reconcile'))).status, 401);
  } finally {
    for (const key of Object.keys(process.env)) if (!(key in saved)) delete process.env[key];
    Object.assign(process.env, saved);
  }
});

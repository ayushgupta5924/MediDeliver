# Deployment runbook

The COD mock-data release is deployed at https://medideliver-eight.vercel.app. It is a fictional pharmacy demonstration, not an approved real medicine fulfillment service. Read `docs/VALIDATION.md` for verified results and remaining live-launch gates. Online checkout remains disabled.

## Supabase upgrade

Target supplied by the owner: `https://mehtwvkvbjytnpjyzhxr.supabase.co`.

1. Use an authenticated staging project first. Take a database backup and test restoration. Review `supabase/preflight.sql` against the hosted schema; compare the definitions with the baseline migration. Do not apply the baseline over existing tables. On 10 October the baseline function definitions and policies were reviewed before applying the four incremental upgrades. No existing orders were present before seeding.
2. The original baseline must already be applied. Apply the four `20261010...` migrations, in filename order, using the Supabase migration workflow or an authenticated PostgreSQL session. Each file is transactional. Do not mark a migration applied unless its complete schema was reviewed and is already present.
3. Schedule a maintenance window and update clients together. Old clients cannot submit without delivery phone numbers or quote without itemized stock. Existing submitted requests can be reviewed with the new UI. Existing quoted/in-progress requests without inventory snapshots need operator review before advancing; do not synthesize prescription approval or stock history. Complete such orders before rollout, or resolve them through a documented operator process. Never discard existing orders merely to make migrations pass.
4. Provision real pharmacy identities, verified license references, pickup addresses, contact numbers and service areas. Only an authorized operator can do this. Set `verified_at` after verification. The owner explicitly requested fictional data for this hosted demo: it contains four sample orders, one fictional pharmacy and two inventory lots. These fixtures must never be represented as licensed providers or real prescriptions. Use a separate verified deployment for live operation.
5. Have approved pharmacy users enter actual batches, pack sizes, inclusive unit prices, stock and expiration dates in Inventory. Quotes reserve stock atomically. Cancellation/rejection releases stock; delivery deducts it; failed deliveries retain the reservation until confirmed pharmacy return. Do not edit lot identity or expiry to conceal expired stock. Capacity above the first 500 listed lots needs inventory pagination/search work.
6. Configure a verified SMTP sender in Supabase. The hosted project already has Gmail SMTP configured. An authorized real OTP send, verification, customer-profile read and session logout passed on 10 October. Review transactional-email deliverability and rate limits before public live operation. Configure both signup confirmation and magic-link templates to include `{{ .Token }}`; `supabase/templates/otp.html` is provided. The local TOML templates do not automatically change hosted email settings. Keep six-digit codes, 600-second expiry, conservative rate limits and the exact production site/redirect URLs.
7. Test distinct customer, pharmacist, rider and operator accounts, email delivery, private image uploads, short-lived signed URLs, and unauthorized access. Local SQL tests use Auth/Storage interfaces, not the hosted HTTP services.

The hosted incremental upgrades were applied transactionally through the authenticated SQL editor, including `202610100004_delivery_expiry.sql`. Supabase CLI migration history was not repaired. Before using `supabase db push`, reconcile the remote migration ledger against the verified schema; never replay the baseline over existing tables. No backup restoration exercise was performed.

## Vercel web deployment

Connect this repository and use the repository root. `vercel.json` builds with Flutter 3.44.2 and publishes only `build/web`; do not deploy root `index.html`. Node.js 22 is selected in `package.json`.

Set these Vercel environment variables for the intended environment:

| Variable | Value |
|---|---|
| `SUPABASE_URL` | The approved project URL |
| `SUPABASE_ANON_KEY` | Its public publishable or legacy anon key |
| `APP_URL` | The exact HTTPS production origin, no path |
| `PAYMENTS_ENABLED` | `false` for the COD launch |
| `DEMO_MODE` | `true` for the requested fictional demo; `false` only for an approved live operation |

Only these public configuration values enter Flutter's compiled bundle. A service-role or secret key is rejected as a client key. No credentials are included in the source package. Vercel account access is configured and CLI deployment succeeded. The project is `medideliver` in `ayush-guptas-projects-f33c79a0`. These variables are configured for preview and production, with demo mode on and payments off. GitHub App repository linking failed, so pushes do not currently auto-deploy; use an authenticated Vercel CLI deployment after passing CI.

For a staging preview use a separate Supabase project and a stable staging domain with matching `APP_URL`. Preserve Vercel deployment protection for staging. Check `/api/health`; it reports configuration presence, not full dependency health. Add an external uptime monitor for the site and a periodic controlled login/order check. Review Vercel errors and Supabase security/performance advisors; keep medical contents and credentials out of logs.

The application uses hash routing, so no SPA rewrite is needed. Checkout has its own page. Security headers and cache policy are configured. The bundled passkeys JS prevents transitive plugin registration from failing before the login screen appears; this does not enable passkey sign-in.

## Razorpay, after merchant onboarding

1. Complete merchant onboarding with Razorpay. Configure automatic payment capture. Test keys and an isolated staging project must be used for initial tests.
2. Add **server-only** Vercel variables `SUPABASE_SERVICE_ROLE_KEY`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, and a strong random `CRON_SECRET`. Keep them out of Flutter config, Git, chat, and client logs.
3. Register `https://<APP_URL host>/api/payments/webhook` with the matching webhook secret. Subscribe to `payment.captured`, `order.paid`, and `refund.processed`.
4. Test successful capture, declined/authorized-only payment, closed browser, invalid signatures, duplicate/out-of-order webhooks, lost create response, cancellation races, expiry races, refund processing and failed refunds. Verify totals and IDs in both dashboards. The local tests use mocked Razorpay responses; no merchant integration has been exercised.
5. Set GitHub Actions repository variable `APP_URL`, secret `CRON_SECRET`, and variable `PAYMENTS_ENABLED=true` to enable the 15-minute reconciliation workflow. Also set Vercel `PAYMENTS_ENABLED=true` and rebuild the app. GitHub schedules can be delayed; this is a recovery path, while signed webhooks provide the normal path. Monitor failed scheduled runs and `payments.needs_attention`.
6. A create timeout is deliberately not retried as a new Razorpay order. Reconciliation searches the unique local receipt and attaches the single matching provider order. Zero or multiple matches require operator review. Do not reset the payment row or create a second payable order blindly.
7. Refunds are full, normal-speed refunds with a stable idempotency key. A returned/failed delivery is cancelled only after an operator confirms pharmacy return. Partial refunds and unsolicited Razorpay dashboard refunds require operator reconciliation and are not modeled by this application. Never use dashboard refund operations without updating the corresponding operational record.
8. To stop new checkout, set Vercel `PAYMENTS_ENABLED=false` and rebuild. Keep webhook credentials and the reconciliation workflow active until every outstanding payment/refund is resolved. Existing webhooks and verification remain accepted after disabling new checkout.

## Launch acceptance and operations

- Pass all CI jobs, a release web build, and browser tests on narrow and desktop screens. Exercise upload/typed request → itemized quote → COD confirmation → preparation → exclusive rider assignment → pickup → delivered/cash collection, plus every rejection/cancellation/return path.
- Validate support contact coverage, real service areas and opening hours, dispensing eligibility, privacy notice/consent, retention/deletion policy, backup restoration and incident ownership with the operator. This repository cannot supply business approvals or a verified pharmacy license.
- Run expected-load and independent-connection race tests against staging. No production throughput or SLA is claimed.
- Live GPS/ETA, push notifications, durable offline drafts, large-catalog search/pagination and self-service staff onboarding remain separate integrations. Orders refresh every 30 seconds while foregrounded on the first page, on resume, and manually. Do not advertise live tracking or guaranteed delivery times.
- Android/iOS publication is separate: choose owned identifiers, configure signing, and run device/privacy tests. This change does not produce signed native releases.

If a release fails, disable new pharmacy intake (`active=false`) through a trusted operator and keep processing existing orders safely. Roll back frontend deployment only if compatible with the current schema; these changes intentionally tighten submission/quote requirements. Restore database backups only through a reviewed recovery procedure, never as a casual rollback of live orders/payments.

References: [Supabase production checklist](https://supabase.com/docs/guides/deployment/going-into-prod), [Razorpay orders lookup](https://razorpay.com/docs/api/orders/fetch-all/), [Vercel Node functions](https://vercel.com/docs/functions/runtimes/node-js).

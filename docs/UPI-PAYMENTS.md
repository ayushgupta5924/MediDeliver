# Direct UPI and COD

MediDeliver has an original direct-UPI checkout alongside the existing COD flow. It is **not an automated payment processor**. In manual mode an operations administrator verifies the merchant bank ledger before releasing an order. Refund recording does not send money. Razorpay remains independently disabled with `PAYMENTS_ENABLED=false`.

## Reference review

Reviewed [YouPI-PG architecture](https://github.com/gxurav1710/YouPI-PG/blob/main/ARCHITECTURE.md), its payment API entry point and `apps/payment-api/src/routes/payments.routes.js`. Adopted the concepts of integer paise, bounded checkout sessions, UPI intent/QR, idempotent state transitions and COD. No YouPI-PG source was copied or executed. Its SMS/email observation and amount-based attribution are not used as payment authority: signing an observer message does not prove a bank credit belongs to this order. WhatsApp/browser-observer infrastructure is unnecessary for MediDeliver's existing Supabase login.

The QR encoder is the MIT-licensed Kazuhiko Arase qrcode-generator, vendored in `web/vendor/qrcode.js` with its license (vendored Git blob `df13f829bf41f36b82f0ed85751ed3b4c39cfeb8`). It runs locally in the browser, without sending payment information to a QR-image service. All payment business logic is MediDeliver-specific.

## Configuration and rollout

1. Apply only `202610180001_direct_upi.sql` to a database already running the prior migrations. Back up first; do not replay the foundation migration against the hosted project.
2. For fictional testing, set `UPI_MODE=mock`, `DEMO_MODE=true`, `PAYMENTS_ENABLED=false` in Vercel. Retain the existing server-only Supabase service credential and public Supabase configuration. Rebuild the Flutter client so its flags match the server. Mock checkout has no payee address, payable QR or UPI link; customer claims still need administrator review.
3. `UPI_MODE=disabled` is the default and the emergency checkout kill switch. It does not prevent administrators from resolving existing receipts/refunds. COD remains usable for new orders. Never switch a pending online order to COD: cancel it, investigate any late credit, then create a fresh order.
4. Live operation requires `UPI_MODE=manual`, `DEMO_MODE=false`, a verified merchant `UPI_PAYEE_VPA` and `UPI_PAYEE_NAME`, an assigned operator with access to bank records, and a tested refund process. Clear fictional transactions before converting any environment to live use. Do not enable real payments against mock pharmacies or inventories. Conduct a controlled real-credit/refund acceptance test before customer launch.

No real merchant account or bank verification API has been configured by this change. For automatic confirmation, integrate an authenticated bank/provider transaction API with server-side order binding; do not add a callback that trusts a screenshot, customer UTR, SMS or email alone.

## Flow

After pharmacy review produces a server-priced quote, the customer chooses COD or UPI. COD keeps its existing acceptance, preparation, assignment, cash-collection and delivery transitions.

UPI creates one immutable payment record per order under an order row lock. The server snapshots the amount, payee and mode and returns a random capability in the checkout URL fragment. Only a SHA-256 hash is stored. Access expires after 15 minutes; reopening rotates access but never extends the five-minute payment window. Expiry hides the payment URI/QR. A previously displayed UPI URI cannot be revoked at the bank, so late receipts must still be reconciled.

The customer can submit one 12-digit reference for review. A submission never marks an order paid. In Operations, the administrator sees the environment, merchant, creation time and unverified claim, then independently matches the receiving account, payer, date, reference and exact amount in the bank ledger. Enter the verified credit UTR, exact rupee amount and an evidence note (20–500 characters, no credentials). Incorrect/ambiguous claims require investigation; never approve solely because the amount matches. The administrator may record the actual bank UTR instead of an incorrect customer claim.

Verified UTRs are unique across orders within each mode. Repeating the same approval is idempotent. A verified eligible order becomes prepaid and enters the existing fulfillment flow; riders must not collect cash. A credit received after cancellation/rejection or stock expiry becomes `refund_pending`, without reviving fulfillment. Operations records a full refund only after verifying the bank refund, using its unique reference and exact amount. Unresolved credits remain visible as pending on the order; use support to investigate rather than repeatedly paying.

## Security boundaries and residual risk

- Authenticated checkout creation checks order ownership and ignores browser amounts/payees.
- Payment tables have RLS; customers, pharmacy staff and riders cannot approve payments. Security-definer RPC grants are explicit. Service credentials never enter Flutter defines or checkout URLs.
- Order/payment locking prevents COD switching, cross-provider checkout and conflicting confirmations. Audit events record state changes; verified/refund records retain operator, timestamp and evidence.
- No UPI `verify`, `success` or observer webhook endpoint exists. App-return events have no authority.
- Checkout uses same-origin bounded POST requests, no-store responses, escaped text rendering, a restrictive CSP and locally hosted QR code generation.
- This is a manual trust boundary: a compromised or dishonest administrator can falsely attest to a bank credit. Protect operator accounts with MFA, restrict role grants, monitor the immutable application audit, and reconcile bank records daily. Database/service administrators remain trusted. An external security assessment is still needed before a real launch; these tests are not a guarantee of zero vulnerabilities.

## Validation

`npm test` covers configuration, tokens, exact amounts, expiry, mode isolation, invalid claims, missing callback endpoints and QR generation, plus existing Razorpay tests. `node scripts/test_database.mjs` runs the existing COD/payment suites and `supabase/tests/upi.sql`: authorization, RLS, token rotation, amount checks, UTR replay, COD/provider switching, cancellation, late credits, refunds and UPI delivery/stock consumption. CI also runs that SQL against real Supabase.

`node scripts/test_upi_browser.mjs` tests isolated API fixtures at 390px and 1280px: no-money mock checkout, pending review, live-mode QR rendering, escaped merchant text and expiry. This does not test a real bank transfer. Flutter action tests cover hiding COD after UPI selection and limiting review controls to administrators. Hosted migration/deployment and live-bank acceptance must be recorded separately; local tests do not prove those steps happened.

### Local validation on 2026-10-18

- 22 Node tests passed.
- All migrations and three PostgreSQL/PGlite suites passed, including UPI fulfillment and the existing COD workflow.
- Isolated Chromium checkout scenarios passed at 390px and 1280px.
- Dart static analysis of `lib` and `test` passed with no issues; modified Dart sources were formatted.
- Flutter checks run in GitHub Actions. Local static analysis passed; the sandbox blocks the Flutter test runner localhost socket. A workspace SDK copy is used for the local release build. Treat the final GitHub Actions run as the release gate.
- No hosted migration, Vercel environment change, live payment or refund was performed. Default UPI is disabled until the migration and matching mode configuration are deployed.

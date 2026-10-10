# Validation status — 10 October 2026

## Passed locally

- Twelve Node.js tests: signature verification over raw bytes, amount/currency/order/capture checks, duplicate webhook routing, ambiguous provider creation handling, opaque checkout tokens, server verification, refund retry keys, per-row recovery errors, request-size limits, disabled checkout and public-only release configuration.
- All migrations apply to in-process PostgreSQL (PGlite).
- Existing workflow and authorization SQL assertions pass against the expanded schema.
- Production SQL assertions pass for itemized quote requirements, stock reservation/release, expired stock denial, client payment forgery denial, captured-payment idempotency, prepaid delivery without cash collection, prepaid cancellation/refunds, payment audit events and late capture after cancellation or expiry.
- Fictional seed data applies and can be rerun without duplicating orders or fulfillment.
- Dart files parse and format using a WASM port of `dart_style`. This is **not** Flutter static analysis or compilation.
- Supabase Auth health responds HTTP 200 with certificate validation using public DNS resolution. The system Windows resolver fails for the project host. A read-only REST query confirms the new verification column has not been deployed.

## Required and not yet verified

- Flutter analyze, Flutter unit/widget tests and release web build. The installed Dart 3.12.2 process fails before execution with `Failed to canonicalize path ... OS error (5)` under this Windows sandbox, including a minimal standalone Dart file. SDK/network permission grants did not resolve this OS restriction. Use `scripts/validate.ps1` in a normal development shell or run GitHub Actions.
- Real Supabase stack tests and independent PostgreSQL connections. Native PostgreSQL could start here, but local client connections timed out. PGlite runs actual SQL/functions/RLS inside one process and does not establish race behavior or Auth/Storage HTTP behavior. CI retains the real Supabase stack and concurrency test.
- Hosted schema equivalence, migrations, live OTP/SMTP, Storage access, separate-role browser workflow, backup/restore, load tests and native signed builds.
- Razorpay sandbox checkout/webhooks/refunds; the owner has not created a merchant account and asked to prioritize COD. Payments default off.
- Vercel deployment and remote CI. GitHub connector reports pull-only permission, Git push cannot authenticate, and no authenticated Vercel/Supabase administrator browser session is connected. No PR, hosted migration or deployment was created.
- Vercel CLI account checks were also blocked by Windows `EPERM` errors while creating its configuration/cache directories. No credentials or account changes were made.

This status deliberately does not label the release production-ready. See the deployment runbook for the exact remaining acceptance gates.

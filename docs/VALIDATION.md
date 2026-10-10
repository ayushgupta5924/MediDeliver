# Validation status — 10 October 2026

## Passed

- GitHub Actions: Flutter 3.44.2 formatting, static analysis, 15 unit/widget tests and release web compilation.
- Fourteen Node tests for server payment guards, signatures, capture validation, recovery and public-only build configuration. Razorpay provider calls remain mocked.
- All five migrations and rerunnable fictional seed pass in PostgreSQL via PGlite.
- GitHub Actions real Supabase stack: workflow/RLS assertions, independent-connection concurrency tests, production payment/inventory assertions, and expired-stock denial at assignment and delivery.
- Vercel production deployment: Flutter analyze/test/build successful; public root and health endpoint return HTTP 200. Health reports payments disabled; checkout creation returns HTTP 503.
- Hosted Supabase baseline functions/policies reviewed, then four incremental migrations applied through authenticated SQL editor. Aggregate verification: four fictional orders, one active fictional pharmacy, two inventory lots and nine RLS-enabled public tables.
- Existing Gmail SMTP and OTP templates inspected. One owner-approved email was delivered and its code verified (HTTP 200). Customer profile access succeeded; the test session was signed out (HTTP 204). No session tokens were saved. Site URL matches the deployment.

## Browser verification

The deployed smoke workflow checks desktop (1280 px) and narrow (390 px) COD demo interactions, API health and disabled prepaid checkout. See the Deployed COD browser checks workflow for its latest outcome. Screenshots are attached to the workflow run. Flutter role switches expose checkbox semantics; the harness uses those accessible roles.

## Remaining live-launch gates

- The deployed no-login walkthrough is browser-local fictional data. Its browser checks do not establish an authenticated end-to-end hosted order/upload workflow across four real users.
- Validate real staff accounts, private prescription uploads and signed URLs through the hosted UI before accepting real requests. Real pharmacy identity, license verification, service coverage, dispensing procedures, privacy/retention policy and support ownership require an actual operator.
- Backup restoration, expected-load testing and native signed Android/iOS releases have not been completed.
- Supabase upgrades were applied manually; reconcile migration history before later CLI pushes.
- PR #2 merged as `1b7860f`. Vercel GitHub repository connection is now configured with `main` as the production branch. Verify the follow-up commit deployment before claiming the automatic build passed.
- The local Windows resolver cannot resolve the new deployment/Supabase hosts. Certificate-valid public DNS probes and GitHub-hosted tests work; no system DNS settings were changed.
- Razorpay remains disabled at the owner's request. Merchant onboarding and sandbox checkout/webhook/refund verification are deferred.

This is a deployed COD demo, not certification for real pharmacy operations.

## Authenticated HTTP acceptance harness

`scripts/test_hosted.py` creates six isolated users and tests Auth, separate role access, private PNG upload, disallowed MIME/size/path, signed image access and expiry, idempotent requests, itemized quotes, inventory reservation, concurrent rider assignment, COD delivery and recipient redaction. All assertions use user JWTs; the service key is confined to fixture setup and UUID-scoped cleanup. Existing seed data is preserved. The database CI job runs this suite against its local Supabase HTTP stack.

For a hosted run, set `HOSTED_TEST_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` securely in the process environment, then run `python scripts/test_hosted.py`. Never commit or print the service key. Hosted execution still requires authorized CLI/admin credentials; a prepared script is not evidence that the hosted tests passed.

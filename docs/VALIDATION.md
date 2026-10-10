# Validation status — 10 October 2026

## Passed

- GitHub Actions: Flutter 3.44.2 formatting, static analysis, 15 unit/widget tests and release web compilation.
- Fourteen Node tests for server payment guards, signatures, capture validation, recovery and public-only build configuration. Razorpay provider calls remain mocked.
- All five migrations and rerunnable fictional seed pass in PostgreSQL via PGlite.
- GitHub Actions real Supabase stack: workflow/RLS assertions, independent-connection concurrency tests, production payment/inventory assertions, and expired-stock denial at assignment and delivery.
- Vercel production deployment: Flutter analyze/test/build successful; public root and health endpoint return HTTP 200. Health reports payments disabled; checkout creation returns HTTP 503.
- Hosted Supabase baseline functions/policies reviewed, then four incremental migrations applied through authenticated SQL editor. Aggregate verification: four fictional orders, one active fictional pharmacy, two inventory lots and nine RLS-enabled public tables.
- Existing Gmail SMTP and OTP templates inspected. One owner-approved email was delivered and its code verified (HTTP 200). Customer profile access succeeded; the test session was signed out (HTTP 204). No session tokens were saved. Site URL matches the deployment.
- Hosted HTTP acceptance passed all 28 checks on `mehtwvkvbjytnpjyzhxr`, run `a387cbff-b43b-4fc5-a891-4eacf6dbe73e`. Six independent authenticated users exercised uploads, privacy, signed-link expiry, order idempotency, quoting, stock reservation, concurrent rider assignment and COD delivery. Cleanup reported no errors.
- Independent SQL verification after cleanup: four original orders, one active pharmacy, two inventory lots, zero disposable users, zero disposable pharmacies and zero stored prescriptions. The temporary runner was replaced with an HTTP 410 response and independently probed. Its service credential was cleared from the dashboard form; no secrets were saved to this repository.
- PRs #2 and #3 merged. Automatic Vercel production deployment from `daa79d15aa447c215186a62760faa5d3d18d634f` reached READY; main CI run `38067102033` and production browser workflow `38067425411` succeeded.

## Authenticated browser acceptance

The full requested hosted UI flow passed with three real OTP logins: synthetic prescription upload/preview, itemized pharmacy quote, customer COD confirmation, preparation, rider assignment/pickup/delivery and cash collection. Stock changed from 10 to 8 with zero reserved. Test users and all fixtures were removed, preserving the original seed. No application defect was reproduced in this flow. See [the detailed acceptance record](HOSTED-UI-ACCEPTANCE.md).

## Browser verification

The deployed smoke workflow checks desktop (1280 px) and narrow (390 px) COD demo interactions, API health and disabled prepaid checkout. See the Deployed COD browser checks workflow for its latest outcome. Screenshots are attached to the workflow run. Flutter role switches expose checkbox semantics; the harness uses those accessible roles.

## Remaining live-launch gates

- The deployed no-login walkthrough is browser-local fictional data. Hosted role/upload checks passed through real Auth, PostgREST and Storage HTTP endpoints; the separate authenticated Flutter browser walkthrough has now also passed (see HOSTED-UI-ACCEPTANCE.md).
- Validate real staff accounts, private prescription uploads and signed URLs through the hosted UI before accepting real requests. Real pharmacy identity, license verification, service coverage, dispensing procedures, privacy/retention policy and support ownership require an actual operator.
- Backup restoration, expected-load testing and native signed Android/iOS releases have not been completed.
- Supabase upgrades were applied manually; reconcile migration history before later CLI pushes.
- The owner repaired Windows DNS with administrator approval. Normal system resolution and HTTPS now work for the app and Supabase; the hosted browser walkthrough ran on this computer.
- Razorpay remains disabled at the owner's request. Merchant onboarding and sandbox checkout/webhook/refund verification are deferred.

This is a deployed COD demo, not certification for real pharmacy operations.

## Authenticated HTTP acceptance harness

`scripts/test_hosted.py` creates six isolated users and tests Auth, separate role access, private PNG upload, disallowed MIME/size/path, signed image access and expiry, idempotent requests, itemized quotes, inventory reservation, concurrent rider assignment, COD delivery and recipient redaction. All assertions use user JWTs; the service key is confined to fixture setup and UUID-scoped cleanup. Existing seed data is preserved. The database CI job runs this suite against its local Supabase HTTP stack.

For a hosted run, set `HOSTED_TEST_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` securely in the process environment, then run `python scripts/test_hosted.py`. Never commit or print the service key.

The completed hosted run used `scripts/hosted_acceptance_function.ts` manually deployed through the owner's authenticated Supabase dashboard. The dashboard legacy service credential differed from the runtime's injected credential, so authorization was verified by a successful admin API call against the fixed project instead of string equality. Anonymous authorization was independently rejected with HTTP 401. The runner is time-limited, requires explicit mock-project confirmation, has UUID-scoped cleanup, is never deployed automatically, and the live function is now disabled (HTTP 410). The source is retained for audit; it is not the currently deployed function body.

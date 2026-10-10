# MediDeliver

Flutter + Supabase medicine-request and cash-on-delivery pilot. Customers request pharmacy review, an approved pharmacy quotes the total, customers confirm, and approved riders fulfill the delivery. No online payment capture or automatic prescription approval is enabled.

The current release candidate adds itemized pharmacy quotes, batch/expiry inventory and reservations, delivery/pickup contacts, Vercel hosting configuration, and a feature-gated Razorpay server integration. **It is not yet deployed or validated for production.** Start with [validation status](docs/VALIDATION.md) and the [deployment runbook](docs/DEPLOYMENT.md). COD is the immediate launch priority; `PAYMENTS_ENABLED=false` until merchant onboarding and integration tests are complete.

## Requirements and local setup

- Flutter 3.44.2 / Dart 3.12.2 (CI versions), PostgreSQL client, Supabase CLI and Docker for the complete local backend.
- Run `flutter pub get`.
- Run `supabase start` to provision the local stack and apply migrations. The baseline migration is for an empty application schema. Review existing tables/triggers/policies before deploying to any hosted project; an empty orders table does not necessarily mean an empty schema.
- Copy `config/development.example.json` to `config/development.json` and fill in the URL and local anon/publishable key printed by `supabase status`. Never put a service-role key in Flutter configuration.
- Run `flutter run --dart-define-from-file=config/development.json`.
- For Android emulator use the host address `10.0.2.2` instead of `127.0.0.1`. Hosted builds require HTTPS.
- Email OTP templates must contain `{{ .Token }}` so the user receives the six-digit code. Local email is available in the Supabase local mail viewer. Configure a verified email provider and auth rate limits before a hosted pilot.

## Accounts and access

Every signup is a customer, regardless of supplied user metadata. Staff accounts sign in normally first, then a trusted operator grants the role through the database:

```sql
-- Replace the IDs with accounts/pharmacies you have verified.
update public.profiles set role = 'pharmacy_owner' where id = '<verified-user-id>';
insert into public.pharmacy_members(pharmacy_id,user_id) values ('<pharmacy-id>','<verified-user-id>');
update public.profiles set role = 'delivery_partner', service_postal_codes = array['382010'] where id = '<verified-rider-id>';
update public.profiles set role = 'admin' where id = '<verified-operator-id>';
```

Sign out/in after changing roles. Only trusted database administration may change roles, memberships, service areas or pharmacy activation. Clients cannot write profiles or order rows directly. Staff UI guards are convenience; database grants, RLS and transactional RPCs enforce authorization.

## Workflow

`submitted -> quoted -> confirmed -> preparing -> ready -> assigned -> picked_up -> delivered`

- A pharmacy quote records the reviewer and decision, exact medicine/pack, batch, expiry, quantity, inclusive unit prices and delivery fee. The database calculates integer-paise totals and reserves stock atomically. Customer confirmation selects COD or, when configured, verified Razorpay checkout.
- Customers can cancel until preparation starts; pharmacy staff can reject before preparation with a reason.
- Riders only see available deliveries in their service postal codes. Medical items and prescriptions are omitted from rider responses. Exact delivery addresses appear only after assignment.
- Acceptance locks the order row; only one rider can win. Pickup and delivery require the assigned rider. Delivery explicitly confirms cash collection.
- Failed deliveries record a reason. An operator can redispatch only after confirming return to the pharmacy.
- Events record the actor and each status transition. Paginated lists return at most 25 records. The first page refreshes every 30 seconds in the foreground and on app resume; pull-to-refresh and manual refresh are available on every page.
- Request IDs make retries of an unchanged submission idempotent. The client retains the key while that draft is open. Following an app restart or editing a failed draft, check order history before submitting again; durable offline drafts are not yet implemented.
- Prescription uploads are private, limited to JPEG/PNG and 5 MB, immutable to clients, and viewed through 60-second signed URLs. Users must not include medical data in application logs.
- Verified pharmacies require a license reference, pickup address and contact phone. Requests require a delivery phone in international format. Riders receive that phone only while assigned to an active/failed delivery; medical items and quote lines remain redacted.
- Online payment amounts come from the stored quote. Only server-side functions can confirm capture or refunds; signed webhook duplicates are idempotent. Late captures after cancellation or inventory expiry queue a full refund. Payments remain disabled by default.

## Fictional demonstration data

Seeding is disabled by default. On LOCAL/STAGING ONLY, run:

```sh
psql -v ON_ERROR_STOP=1 "$TEST_DATABASE_URL" -f supabase/seed.sql
```

The seed creates explicitly fictional customer/pharmacy/rider/operator records and sample medicine requests using `example.invalid` addresses. It does not send email or create working passwords. For interactive testing, create your own local email-OTP accounts and assign their roles as above. Do not copy these fixtures into a live deployment.

## Validation

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
psql -X -v ON_ERROR_STOP=1 "$TEST_DATABASE_URL" -f supabase/tests/workflow.sql
python scripts/test_concurrency.py
psql -X -v ON_ERROR_STOP=1 "$TEST_DATABASE_URL" -f supabase/tests/production.sql
npm ci
npm test
node scripts/test_database.mjs
flutter build web --release --dart-define-from-file=config/production.json
```

Database tests target a disposable database. They verify profile escalation denial, customer/pharmacy isolation, prescription storage policies, input validation, the complete COD lifecycle, audit events, idempotent creation and competing riders. The concurrency test uses separate database connections. CI starts the complete Supabase stack. Local PostgreSQL-only harness results do not verify Auth delivery or the Storage HTTP service.

For the release build, copy `config/production.example.json` to the ignored `config/production.json` and supply the approved HTTPS public settings. A release configured with an HTTP development endpoint will refuse to initialize. Vercel builds generate this configuration from environment variables instead.

## Mobile release

Android production builds require a private upload keystore and `android/key.properties` (see the example). Release tasks fail if signing is unconfigured instead of signing with a debug key. Set your final Android application ID and Apple bundle ID before publishing; the scaffold identifier is not a chosen production identity. Configure Apple signing in Xcode. Camera/photo usage descriptions and Android network permission are present. iOS/Android device testing is still required.

## Deployment and remaining integrations

Publish the Flutter `build/web` output for a web deployment, not the repository root. Root `index.html` is a pilot information page; the pre-existing unrelated tarot page is preserved under `archive/`.

Before a real launch, configure and validate:

- Hosted Supabase migrations, OTP email delivery, private Storage access and backups/restore.
- Real pharmacy verification and medicine eligibility procedures. Stock/batch/expiry and itemized quotes are implemented; real inventory and dispensing decisions must be supplied by the approved pharmacy.
- Razorpay merchant onboarding, keys, signed webhooks and reconciliation configuration plus sandbox tests before enabling the included prepaid integration.
- Push notifications, live location/ETA, staffed customer support and uptime monitoring. Foreground order polling is implemented; background push and live GPS are not.
- Service-area operating rules, privacy/retention process and the applicable dispensing requirements for the actual operating jurisdiction.
- Load tests using expected order volume and observed query plans. No throughput capacity is claimed by the included functional tests.

These require configured external services and operating decisions. Do not represent this pilot as production-ready healthcare fulfillment.

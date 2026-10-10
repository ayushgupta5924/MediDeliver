# Hosted browser acceptance — 10 October 2026

Result: the requested login → prescription upload → pharmacy review → COD delivery flow passed in the Codex in-app browser against the hosted Supabase backend. No application defect was reproduced in this tested flow, so no runtime code change was needed.

Tested production source: `8ddf7bc300f0eeec3c78899636903faf078aa7f7`.
Vercel deployment: `dpl_C1aUtE8Zt9CNX1Uhv8AKdNuij8JC`.

## Method

Three owner-approved disposable Gmail aliases received real OTP emails. The owner supplied each code and each role signed in through the unmodified application UI. Customer, pharmacy and rider sessions used three distinct production alias origins, all verified to point to the same deployment, to keep origin-scoped sessions independent. No tokens were injected and no authentication bypass was added.

An isolated fictional pharmacy and stock batch were provisioned through the authenticated Supabase dashboard. Staff permissions were granted only after owner approval. The customer uploaded a PNG visibly labeled synthetic and not a valid prescription. No real medicines, money or delivery were involved. Existing demo fixtures were not used for the order.

## Verified through the UI

- Empty email validation; real OTP verification for all three roles; customer session restoration after reload.
- Required delivery fields and disabled submission until the form was complete.
- PNG selection through the actual Gallery file picker, private hosted upload, and order creation.
- Customer and authorized pharmacy image previews rendered the uploaded synthetic image.
- Pharmacy saw only its assigned test pharmacy's order; an incomplete quote was rejected.
- Itemized quote: 2 × ₹92.25 plus ₹25 delivery = ₹209.50. Inventory showed stock 10, reserved 2.
- Customer explicitly confirmed cash on delivery. No prepaid option was displayed.
- Pharmacy progressed confirmed → preparing → ready.
- Rider dispatch hid recipient/medical details before assignment. Only the isolated test order was accepted; the original seeded dispatch order was left untouched.
- Rider assignment, pickup and explicit ₹209.50 cash-collection confirmation succeeded.
- Customer, pharmacy and rider views showed delivered / cash collected. Completed rider view removed recipient details and delivery controls.
- All three users signed out successfully.

Independent SQL assertion confirmed delivered + cash_collected, quote 20950 paise, stock 8 and reserved 0.

## Cleanup

The owner approved deletion of the disposable users, order, image, pharmacy and stock. The Storage UI removed the image and its generated empty-folder placeholder. UUID-scoped transactional SQL removed only the test order/event/lot records, test pharmacy/membership/stock and the three approved alias accounts.

Original seed counts were preserved: 4 orders, 1 active pharmacy, 2 inventory lots. The temporary HTTP acceptance runner from the earlier test remains disabled. Mock mode remains enabled and Razorpay remains disabled.

## Scope

This verifies the requested authenticated browser happy path plus the validation and privacy checks above. It does not claim every cancellation/return/error path, device camera behavior, native mobile releases, load capacity, or readiness for real pharmacy operations.

# Backend Integration Contract

This Flutter workspace contains the client only; the backend route source is
not checked out here. Paths marked **confirm/add** are client assumptions and
must be implemented or adjusted in `Mvec_backend/src/routes/` before live use.

## Existing Client Calls

The app currently calls these APIs. Verify their authorization, response
envelopes, validation, and status transitions against the backend:

- `GET /affiliates/verification`
- `POST /affiliates/verification` with `{ "documents": [{"type": "IDENTITY", "url": "https://..."}] }`
- `GET /admin/settings`
- `PATCH /admin/settings` with platform settings fields from `PlatformSettings.toJson()`
- `PATCH /affiliates/:id/verify` with `{ "decision": "VERIFIED" | "REJECTED" }`
- `PATCH /affiliates/:id/status` with `{ "status": "ACTIVE" | "SUSPENDED" | "BLOCKED" | "UNDER_REVIEW" }`
- `PATCH /admin/vendors/:id/status` and `PATCH /admin/suppliers/:id/status` with the same account status values

The first five routes above are **confirm/add** unless present in the backend.
The vendor and supplier status routes already have client service methods; the
UI now exposes additional status values, which the backend must validate.

## Request and Response Expectations

- All admin routes require an authenticated `super_admin` token and must also
  enforce role checks on the server.
- Settings GET/PATCH should return `{ "settings": { ...fields } }` or a bare
  settings object. The client currently supplies defaults for omitted fields.
- Verification submission accepts URLs for documents already uploaded through
  an approved secure upload flow. This app does not upload files; do not accept
  arbitrary public URLs as trusted identity evidence.
- Verification responses should include `status`, `submittedAt`, `reviewedAt`,
  `notes`, and `documents`. Affiliate records should expose both `status` and
  `verificationStatus`.
- Status mutations should return the updated party record wrapped as
  `{ "affiliate": ... }`, `{ "vendor": ... }`, or `{ "supplier": ... }`.
- Payment settlement summaries require an order response with an explicit
  settlement status, e.g. `settlement.status` or `settlementStatus`. If absent,
  the client displays totals as unavailable rather than inventing values.
- Vendor-level analytics are not implemented by the current client. Add a
  paged, date-filterable reporting endpoint and a typed model before presenting
  vendor rankings as live data.

## Demo Mode

`--dart-define=DEMO_MODE=true` selects local affiliate fixtures and an
in-memory platform-settings store. These changes are intentionally not durable
and must never be treated as production data. In live mode, unavailable
affiliate endpoints surface as errors rather than silently switching to mock
data.
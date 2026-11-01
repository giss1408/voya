# Voya admin app: tenants, subscriptions, permissions, cleanup

Date: 2026-11-01. Status: awaiting review.

## Goal

Platform admins need one place to manage operator companies (tenants):
grant or revoke access through manually tracked subscriptions, edit what each
staff role may do per tenant, and clean up old data. Today the manager app mixes
platform-admin features with operator-staff features and roles are hard-coded.

## Decisions (agreed)

| Topic | Decision |
|-------|----------|
| Clean-up meaning | Data clean-up: archive, purge old data, delete tenant |
| Permissions | Four existing roles, permissions editable per tenant (not per user) |
| Subscriptions | Manual: admin sets plan and end date, records payments by hand. No online billing now |
| Admin UI | New Flutter app `admin_app` using shared `voya_ui` |
| Enforcement | Central, in the backend. Apps only hide what the backend would refuse |

## Non-goals

Online billing or payment-provider integration; per-user permission overrides;
changing rider booking flows; roles beyond `dispatcher`, `finance`, `agent`, `admin`.

## Data model (new tables; Alembic migration)

- `plans`: `id`, `name` (unique), `max_vehicles` (nullable = unlimited), `max_staff` (nullable), `price_label` (free text), `is_active`.
- `subscriptions`: `id`, `operator_id` (unique FK), `plan_id`, `status` in {`active`,`suspended`,`archived`}, `starts_on`, `ends_on` (date), `note`. **Effective state** is computed, never stored: `archived` -> Archived; `suspended` -> Suspended; `ends_on < today` -> Expired; else Active (shown as "Expiring" when under 14 days remain).
- `payments_received`: `id`, `operator_id`, `amount` (integer FCFA), `received_on`, `note`, `recorded_by`.
- `role_permissions`: `operator_id`, `role`, `permission` (composite key). Absent row = not granted.
- `audit_log`: `id`, `at`, `actor_id`, `operator_id` (nullable), `action`, `detail` (JSON). Append-only.
- `staff_users.is_disabled` boolean (new column).

Migration seeds: a `Standard` plan (unlimited), an `active` subscription per existing
operator ending one year from migration date, and default `role_permissions` per operator.
Alembic is introduced with this change (replaces `create_all` for schema changes;
`create_all` stays only for fresh dev SQLite).

## Permissions

Keys (initial set, mapped from today's endpoints):

`trips.view`, `trips.create`, `routes.manage`, `vehicles.manage`, `manifest.view`,
`bookings.create_agent` (cash/agent booking), `ledger.view`, `tickets.verify`, `staff.manage`.

Defaults reproduce current behaviour: `admin` all keys; `dispatcher` trips, routes,
vehicles, manifest, tickets.verify; `finance` trips.view, manifest.view, ledger.view;
`agent` trips.view, bookings.create_agent, ledger.view, tickets.verify.
Platform admins (role `admin`, no operator) bypass permission checks but still cannot act on a tenant's behalf except via the admin API below.
Tenant `admin` role can never lose `staff.manage` (prevents lock-out).

Backend: `require_permission(key)` replaces `require_roles(...)` on operator-staff endpoints.
It loads the staff user's tenant permissions for their role.

## Subscription enforcement

`get_current_staff` (shared by all staff routes) rejects with **403** and
`{"code": "subscription_inactive", "message": "Subscription expired on 12 Nov. Contact Voya."}`
when the user's tenant is Suspended, Expired or Archived. Platform admins are exempt.
Disabled users get 401. Rider-facing endpoints stay open, but trips of Suspended,
Expired or Archived tenants are excluded from rider search, and existing tickets still verify.
Plan limits: creating a vehicle or staff user beyond `max_vehicles`/`max_staff` returns
409 `{"code": "plan_limit", ...}`.

## Admin API (platform admin only, prefix `/admin`)

- Tenants: `GET /admin/tenants` (filter by effective state, search), `GET /admin/tenants/{id}`.
- Subscription: `PUT /admin/tenants/{id}/subscription` (plan, ends_on, note), `POST .../suspend`, `POST .../reactivate`, `POST .../payments`, `GET .../payments`.
- Permissions: `GET`/`PUT /admin/tenants/{id}/permissions` (full matrix), `POST .../permissions/reset`.
- Staff: `GET /admin/tenants/{id}/staff`, `POST /admin/staff/{id}/disable|enable`.
- Plans: `GET/POST /admin/plans`, `PUT /admin/plans/{id}`.
- Audit: `GET /admin/audit` (filter by tenant, actor, date).
- Cleanup: see below.
- Existing `POST /operators` and `/operators/{id}/status` stay; the KYC verify action is used by the admin app.

Every mutating admin call writes an `audit_log` row in the same transaction.
`GET /auth/me` additionally returns `permissions: [..]` and `subscription: {state, ends_on}`.

## Clean-up (Tenant detail > Cleanup tab)

1. **Archive** (`POST .../archive`, reversible via `.../unarchive`): sets `archived`, hides from rider search, keeps all data.
2. **Purge old data** (`POST .../purge/preview` then `POST .../purge`): body `older_than_days` (minimum 90). Targets only trips whose status is completed or cancelled and whose departure is older than the cut-off, with their seats, seat holds and tickets. Purge skips any trip that still has a booking or payment newer than 90 days, and never touches bookings or payments of non-completed trips. Bookings and payments of purged trips are deleted together with the trip so no orphan references remain. The preview returns counts; the purge request must echo the preview's counts or it is refused.
3. **Expired seat holds**: a scheduled job (every 15 min, in-process) deletes holds past expiry for all tenants. No admin action.
4. **Delete tenant permanently** (`DELETE /admin/tenants/{id}`): requires status archived, no booking or payment in the last 90 days, and the request body `confirm_name` equal to the tenant name. Deletes all tenant data. Not reversible. The audit row is kept.

## admin_app (Flutter)

Platform admins only: login rejects non-platform-admins with a clear message. Uses `voya_ui`; two-column layout above 840dp.

- **Tenants**: list with effective-state badge (icon + label), plan, end date; search and state filter.
- **Tenant detail** tabs: Subscription (plan, extend end date, record payment, suspend or reactivate, payment history), Permissions (roles x permissions toggles, reset to defaults), Staff (list, disable or enable), Cleanup (archive, purge with preview, delete with type-the-name).
- **Plans**: list, create, edit.
- **Audit log**: filterable list.
- Four states on every async view; errors via a `userMessage` mapping including `subscription_inactive`-style codes.

## manager_app changes

- Remove platform-admin-only UI (all-operators view, Approve KYC). Operators see only their own tenant.
- Read `permissions` from `/auth/me`; hide actions the user lacks. The backend remains authoritative.
- Handle `subscription_inactive` with a full-screen "Access paused" message (reason, end date, contact line), not a snackbar.

## Testing

Backend (pytest, SQLite): effective-state computation; suspended, expired and archived tenants blocked while platform admin is not; permission allow and deny per role incl. tenant-admin lock-out guard; tenant isolation (tenant A admin cannot read or edit tenant B, nor reach `/admin`); plan limits; every purge safety rule (age floor, protected trips, preview-count echo); delete preconditions and name confirmation; audit row for each mutation; migration seeds existing operators.
Apps: widget tests for tenants list states, permission toggles, type-the-name delete, access-paused screen, and no overflow at 320dp.

## Deployment

Alembic migration runs on deploy (`startCommand` prefixed with `alembic upgrade head`). Roll out `integration` first, verify, then `prod`.

## Open items to confirm during planning

Scheduler choice for hold cleanup (in-process task is assumed); 14-day "expiring" threshold and 90-day purge floor are defaults, adjustable constants.

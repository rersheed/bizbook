# BizBook

Simple small-business **sales & expense** tracker for owners and staff.

**Live (GitHub Pages):** https://rersheed.github.io/bizbook/

## Accounts

Sign up with email and password (Supabase Auth). After signup, create your business — you become the owner. Owners add staff with an email and password from the Staff screen. Default currency is NGN.

There is no demo login. The login page links the Android APK.

## Roles

- **Owner** — create business, dashboard (sales/expenses/net), products CRUD, staff invite/disable, reports, business profile.
- **Staff** — record sale / expense, view own today totals and recent activity, use products in sales.

## V1 scope

Splash → Login/Register → Create Business (owner) → Home | Sales | Expenses | Products | More  
Record sale (product cart or quick amount), sales history + detail (`recorded_by`), record expense, reports (Today/Week/Month/Custom + staff filter), sync status.

**Not in V1:** inventory, loans, suppliers, AR/AP, GL, payroll, multi-branch.

## Stack

- Flutter 3.35 + Provider
- `supabase_flutter` (Auth + data when wired)
- Offline-first `AppStore` + `shared_preferences` outbox (`sync_queue` UX). Drift deferred for web simplicity.
- Brand greens: primary `#0F7A4B`, secondary `#22C55E`, accent `#A7F3D0`, highlight `#F59E0B`

## Supabase

Project URL: `https://ixjfpizmrsqebfqebsvx.supabase.co`  
Config: `lib/core/supabase_config.dart` (defaults + `--dart-define`).

Migration (applied by parent via MCP; mirrored in repo):

```
supabase/migrations/001_bizbook_v1.sql
```

Tables: `profiles`, `businesses`, `business_members`, `products`, `sales`, `sale_items`, `expenses`, `expense_categories`, `audit_logs`. RLS is membership-scoped (`002_membership_rls.sql`): anon has no access. Owners manage staff, products, and all sales/expenses. Staff record sales and expenses and can read their business.

## Run locally

```bash
export PATH="/opt/flutter/bin:$PATH"
cd bizbook
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://ixjfpizmrsqebfqebsvx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-jwt>
```

## Deploy (GitHub Pages from `/docs`)

```bash
flutter build web --release --base-href /bizbook/ \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
rm -rf docs && cp -a build/web docs
git add docs && git commit -m "Update Pages build" && git push
```

Pages source: branch `main` → folder `/docs`.

## APK

Android SDK is not installed on the build box used for this release. Skip APK here; build elsewhere with:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

## License

Private use for Haruna Saidu / rersheed.

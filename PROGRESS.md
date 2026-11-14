# Hoorain Control Room phases 2-6

## Preparation
- [x] Read the Phase 1 shell, shared widgets, route guard, constants, and existing order and bill screens.
- [x] Re-open the HTML reference and record its applicable visual patterns.
- [x] Confirmed no design/logo assets are available; implementation must not depend on image assets.
- [x] Create and maintain this phase checklist.

## Phase 2 — Categories and Products
- [x] Add backwards-compatible models and service-backed data access.
- [x] Add one shared pricing function and focused tests.
- [x] Implement categories and product management flows with CRUD, validation, empty/error/loading states.
- [x] Add featured and hidden product pages.
- [x] Run `flutter analyze`; no new diagnostics from the phase, baseline diagnostics remain.

## Phase 3 — Offers
- [x] Add offers model/service/controller/binding and page.
- [x] Add offer validation, below-cost warnings, preview and pricing integration.
- [x] Run `flutter analyze`; no new diagnostics from the phase, baseline diagnostics remain.

## Phase 4 — Riders
- [x] Add rider/invite/salary models and service-backed controller.
- [x] Implement invitation, salary, advance, payment, and rider list flows.
- [x] Add and test the pure net-pay calculation.
- [x] Run `flutter analyze`; no new diagnostics from the phase, baseline diagnostics remain.

## Phase 5 — Orders, Billing and Printing
- [x] Preserve and extend existing order-detail and bill-viewer behavior.
- [x] Add counter billing with sale-time cost snapshots and stock validation.
- [ ] Printing settings and printer integrations deferred; printer dependencies and screens removed until Wi-Fi printer support is selected.
- [x] Run `flutter analyze`; no new diagnostics from this phase.

## Phase 6 — Item profit, Dashboard, Reports, Inventory
- [x] Implement item-profit views using sale-time cost snapshots and shared pricing.
- [x] Implement dashboard KPI cards and sales/profit charts.
- [x] Implement reports by day/category/product and CSV export.
- [x] Implement stock-in, stock updates, and movement-history pagination.
- [x] Add focused profit tests and run `flutter analyze` / `flutter test`.

## Notes
- No local design assets are referenced; uploaded product images remain user-supplied.
- Firestore list reads are bounded to 30 and reports, profit analysis, and movement history page more on demand.
- Dashboard KPI/chart calculations use the loaded bounded order/bill windows; very high-volume days may require a backend aggregate.
- Legacy sale lines without `costAtSale` deserialize to zero cost; historical profit needs a trusted backfill to be accurate.
- Optional offer push notifications remain disabled; dispatch should be done by a trusted server sender, not embedded client credentials.
- `flutter analyze` reports existing legacy diagnostics; no analyzer errors remain after the UI/model cleanup.
- `flutter test` passes. `flutter build web --no-tree-shake-icons` succeeds; the default web build currently hits Flutter's icon-subsetter invalid-codepoint error.
- The previous `MIGRATION_PLAN.md` is an audit artifact and remains unchanged.
- Work completed through Phase 6. Printing is intentionally deferred; reports export as CSV without printer/PDF dependencies.

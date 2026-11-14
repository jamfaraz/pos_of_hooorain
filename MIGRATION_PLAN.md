# Hoorain Control Room migration plan

## 1) Audit summary

The current project already contains a working admin app foundation, but it is structured around a legacy storefront/admin model rather than the Hoorain Control Room schema in the HTML reference. The codebase has a valid Phase 1 shell, routes, and several CRUD screens (products, categories, banners, orders, notifications), but it still reads/writes a mix of old Firestore names (`admin`, `users`, `Notifications`, `category`/`subcategory`, `price`, etc.) and a legacy screen structure. The project must be migrated to single-admin, no-staff, rider-first operations while preserving backward compatibility.

## 2) Existing -> action

| Existing item | Action | Reason |
| --- | --- | --- |
| `lib/main.dart` | KEEP / REFACTOR | Entry point is valid; Firebase app startup and GetX bootstrapping remain correct but need new route setup and theme wiring. |
| `lib/utils/app_routes.dart` | REFACTOR | Current routes are placeholder-heavy and still use a legacy admin layout; they need the new Hoorain Control Room routes and bindings. |
| `lib/utils/auth_gate.dart` | KEEP / REFACTOR | Good pattern for admin gate; must be migrated to the `admins` collection and strict single-admin access check. |
| `lib/utils/admin_route_guard.dart` | KEEP / REFACTOR | Guard logic is relevant but must validate admin status against the new schema. |
| `lib/widgets/app_shell.dart` | KEEP / RESTYLE | Shell is already the right shape (rail + top bar + search), but it must match the Hoorain design and the new module list. |
| `lib/widgets/*` (shared UI) | KEEP / RESTYLE | Several widgets exist and should be reused or adapted; phase 1 is a good baseline. |
| `lib/screens/auth/login_screen.dart` | RESTYLE | Current login is a generic sign-in screen; must become the Hoorain Control Room branded login screen with logo and app shell flow. |
| `lib/screens/main_screen/main_screen.dart` | REFACTOR | Dashboard exists but it is an older admin panel layout with custom widgets; it must become the new dashboard with KPI cards and charts. |
| `lib/screens/category/*` | REFACTOR / MERGE | Category screens already exist but need the new card grid, drawer UX, and product/category migration logic. |
| `lib/screens/products/product_list_screen.dart` | REFACTOR / MERGE | Product table and add/edit flows exist but do not match the new schema or missing design. |
| `lib/screens/products/edit_product_screen.dart` | REFACTOR | Product editing flow exists but the data model and field names are legacy. |
| `lib/screens/products/featured_products_screen.dart` | RESTYLE / MIGRATE | Feature page exists but must match the new required feature/hidden product structure and route flow. |
| `lib/screens/products/hidden_products_screen.dart` | RESTYLE / MIGRATE | Same as above. |
| `lib/screens/orders/order_screen.dart` | MIGRATE | Existing order list is useful, but must be aligned with the new billing/order schema and print actions. |
| `lib/screens/orders/order_detail_screen.dart` | MIGRATE | Heavy existing functionality must be preserved while updating layout and fields to the new order schema. |
| `lib/screens/orders/bill_viewer_screen.dart` | MIGRATE | Requires print and view flow compatibility while using new pricing model and `costAtSale` fields. |
| `lib/screens/users/users_screen.dart` | MERGE / REFACTOR | These screens are customers in practice; they should merge into the new Customers module rather than a generic user list. |
| `lib/screens/users/user_detail_screen.dart` | MERGE / REFACTOR | Customer order/balance history belongs to the Customers module, not user management. |
| `lib/screens/banners/banners_screen.dart` | KEEP / REFACTOR | Banner logic already exists; must match marketing module requirements and new schema. |
| `lib/screens/notification/*` | REFACTOR / DELETE | Notification logic exists but is legacy and should be replaced with the new marketing notifications + FCM flow. |
| `lib/models/product_model.dart` | REFACTOR | Legacy `Product` model is incompatible with the new schema (names, pricing fields, images array, bulk tiers, featured/visible flags). |
| `lib/models/category_model.dart` | REFACTOR | Current category fields are not aligned with the new category schema and color/subcategory handling. |
| `lib/models/order_model.dart` | REFACTOR | Legacy order model is a storefront order model and does not include `customerId`, `customerType`, `items[].costAtSale`, or the new statuses. |
| `lib/models/user_model.dart` | REFACTOR / MERGE | This is a general customer model, not admin/staff; keep the customer logic but align it with `customers` and remove all role/staff semantics. |
| `lib/models/banner_model.dart` | KEEP / REFACTOR | Banner data is relevant to marketing. It must be mapped to the new marketing schema. |
| `lib/controllers/fetch_product_controller.dart` | REFACTOR | This is the biggest legacy CRUD controller and should be split into proper service-backed GetX controllers. |
| `lib/controllers/product_controller.dart` | REFACTOR | Current product mutation logic is useful but needs schema translation and deletion safety rules. |
| `lib/controllers/order_controller.dart` | REFACTOR | This controller handles orders and update flows; must be rebuilt around the new order fields and rider assignment logic. |
| `lib/controllers/dashboard_count_controller.dart` | REFACTOR | Good first pass for counts, but not aligned with the Hoorain KPI cards or new collections. |
| `lib/controllers/user_controller.dart` | REFACTOR / MERGE | Useful for customer lookup, but this collection is `customers` now, no role logic. |
| `lib/controllers/profile_controller.dart` | REFACTOR | Keep only admin profile and signed-out token cleanup for the `admins` collection. |
| `lib/controllers/login_controller.dart` | REFACTOR | Must target single-admin access and the `admins` collection. |
| `lib/controllers/banner_controller.dart` | REFACTOR | Should be ported to the new banner/marketing flow. |
| `lib/controllers/data_controller.dart` | DELETE | This is legacy data/feed logic not needed in the Hoorain Control Room. |
| `lib/controllers/notifications.dart` | REFACTOR | Notification code is useful for FCM but needs to be re-scoped to the new notifications/offers marketing flow. |
| `lib/controllers/sales_controller.dart` | KEEP / REFACTOR | Sales analytics may survive, but it must be replaced by the new reports/data model and pricing helpers. |
| `lib/controllers/add_category_controller.dart` | REFACTOR | Useful category CRUD logic but data and UI must align with the new schema. |
| `lib/controllers/edit_category_controller.dart` | REFACTOR | Same as above. |
| `lib/utils/assets.dart` | KEEP | Asset references may be used for logos/icons and should be reconciled with the `assets/logo` pack. |
| `lib/screens/splash.dart` | KEEP / RESTYLE | Splash already in place; must incorporate the new brand and login route. |
| `lib/screens/common/control_room_placeholder.dart` | DELETE / REPLACE | Placeholder screens should be replaced by the actual module screens. |

## 3) Required items from section 4 that are missing

| Module | Missing required items |
| --- | --- |
| Auth + shell | `LoginBinding`, `AuthGuard`, updated `AppShell`, logo/brand assets, notification bell, theme toggle, focused global search, route entries for full Hoorain nav. |
| Dashboard | `DashboardController`, `DashboardBinding`, KPI service, revenue/profit charts, recent orders, low-stock widget, top offers summary. |
| Categories | `CategoryController`, `CategoryBinding`, `CategoryService`, add/edit drawer, product-grid selection flow, product-count logic, delete-block validation. |
| Products | `ProductService`, `ProductController`, `ProductBinding`, multi-image uploader, bulk pricing tiers, featured/hidden filters, add/edit drawer, rating/stock logic. |
| Featured + Hidden | Separate route pages and controllers for featured and hidden products are not fully implemented as Hoorain modules. |
| Offers | `OfferModel`, `OfferService`, `OfferController`, `OfferBinding`, table, preview cards, product picker, validation, notification toggle. |
| Riders | `RiderModel`, `RiderService`, `RiderController`, `RiderBinding`, rider KPI row, invite flow, salary history and payment logic. |
| Orders + Billing | Existing support is present but not complete for new order schema; required: filters/search, rider assignment, `costAtSale`, print, billing view, status flow. |
| Customers | `CustomerModel`, `CustomerService`, `CustomerController`, `CustomerBinding`, list/search/drawer, history and balance functions. |
| Inventory | `InventoryService`, `InventoryController`, `InventoryBinding`, stock table, movement history, add-stock drawer. |
| Item Profit | `ItemProfitController`, `ItemProfitService`, `ItemProfitBinding`, product picker, period tabs, profit/loss cards, small chart. |
| Expenses | `ExpenseModel`, `ExpenseService`, `ExpenseController`, `ExpenseBinding`, add-expense drawer, salary entry mapping. |
| Reports | `ReportService`, `ReportController`, `ReportBinding`, report screen, PDF export helpers, product/category sales views. |
| Marketing | `BannerController`/service already exist but not fully aligned; `NotificationController`, `MarketingBinding`, banner list + send-notification screen still require migration. |
| Settings | `SettingsModel`, `SettingsService`, `SettingsController`, `SettingsBinding`, data migration screen, printing service interface, profile/delivery area/support config. |
| Data migration | `DataMigrationService` and `DataMigrationController` are completely missing; required screen and batch-safe migrations are not present. |

## 4) Firestore field differences and migration mapping

| Current collection / field | New schema / action | Mapping plan |
| --- | --- | --- |
| `admin` doc `{ uid }` | `admins` | Keep current admin document IDs as the same `uid` and write the new `admins` collection with a compatible `uid` field. Ignore role-based fields; use single-admin check. |
| `users` | `customers` | Map `fullName` → `name`, `phoneNumber` → `phone`, `email` → keep if relevant but not required, `profileStatus`/`isVerified` → `type` only when customer type is known, no role fields, retain `createdAt` as `createdAt`. |
| `products` legacy fields: `category`, `subcategory`, `price`, `price`, `mrp`, `rating`, `isFeatured`, `isHide`, `imageUrl`, `videoUrl`, `bulkPricing`, `totalQuantity` | New product schema | Map `category` to `categoryId` when category ID is known; otherwise keep legacy category name in a helper and let the migration resolve it. Map `price` to `homePrice` if `homePrice` is missing; map `shopPrice` from `price` or legacy `shopPrice`; `isFeatured` → `featured`; `isHide` → `active = !isHide`; `totalQuantity` → `stock`; `imageUrl` → `images[0]`; `bulkPricing` → `tiers[{ qty, homePrice, shopPrice }]`; `rating` → `ratingAvg`, and `ratingCount` defaults to 0. |
| `categories` legacy fields: `name`, `imageUrl`, `subcategories`, `isVisible` | New schema: `name`, `imageUrl`, `color`, `subcategories[]`, `sortOrder` | Map `isVisible` to `active` if needed; `color` defaults to a category color palette; `sortOrder` defaults to array index. Preserve existing subcategories and custom names. |
| `orders` legacy: `userId`, `userName`, `userPhone`, `items[]`, `subtotal`, `deliveryFee`, `tax`, `serviceFee`, `total`, `status`, `orderDate` | New orders/bills schema | Map `userId` to `customerId`, `userName`/`userPhone` to customer lookup values, `deliveryFee` stays under `delivery`, `status` stays as is, `orderDate` → `createdAt`, and add `costAtSale` to every item during each sale. Use `customerType` from `type` or infer from the customer document. |
| `Notifications` (capitalized) | `notifications` | Write `title`, `body`, `audience`, `sentAt` fields; keep existing notification records and migrate in place. |
| `banners`/`category`-scoped banner docs | `banners` | Map each banner document to the new collection shape: `title`, `imageUrl`, `targetCategoryId`, `active`, `sortOrder`. |
| `orders[].items[].imageUrl` | `items[].name`, `costAtSale` | Preserve image URL only as legacy metadata; new required item schema includes product name, qty, unit price, costAtSale, and no dependency on image at item level. |

## 5) Dead code, unused packages, duplicates, and staff/role removal

| Area | Findings |
| --- | --- |
| Firestore collection drift | `admin` vs `admins`; `users` vs `customers`; `Notifications` vs `notifications`; `category`/`subcategory` fields vs the `categoryId` + `subcategories` schema all need normalization. |
| Legacy screen duplication | `add_product`, `edit_product`, `featured_products`, `hidden_products`, `categories_list`, `product_list`, `sales_screen`, and several `users_*` screens are overlapping implementations; they must be consolidated into the new module plan. |
| Role/staff handling | No explicit staff/role model is currently present, which is good, but the project still uses generic user/admin semantics. All route checks and user metadata must be restricted to the `admins` collection and the `customers` collection only. |
| Unused or risk-prone packages | Review and prune after the migration: `flutter_screenutil` is explicitly disallowed for the new Hoorain shell, `iconsax`, `gal`, `googleapis_auth`, and `photo_view` are not required by the stated design and should be removed unless directly used in a migrated module. |
| Legacy data-controller logic | `lib/controllers/data_controller.dart` is a generic chat/notification helper and should be removed from the new app; it does not belong in the Control Room stack. |
| Placeholder screens | `lib/screens/common/control_room_placeholder.dart` is a temporary stub and must be replaced by real modules. |
| Legacy naming noise | Files and routes named `customer`, `user`, `notification`, and generic `sales` are likely to be retained only as UI wrappers; they should be merged into `customers`, `marketing`, and `reports` modules. |

## 6) Assumptions for the migration

- Firestore already contains real store data; the migration must be additive and backward compatible, never destructive.
- Existing admin logins are single-target admin logins; no multi-role/staff hierarchy is required.
- Product legacy documents may have a single `price` field and a single `imageUrl`; the migration will populate both home and shop price values and an `images` array safely.
- Category IDs may be stored as custom document IDs or names; the migration should prefer category document IDs when resolvable and fall back to the name otherwise.
- This is a web + desktop admin panel; no mobile-specific UI or asset-driven design is required for the control room beyond print and web/desktop compatibility.

## 7) Immediate next actions

1. Create the compatibility model layer (`models`, `services`) to accept both old and new document shapes.
2. Implement the pricing utility and all migration-safe field validators.
3. Port the shell and shared widgets to the Hoorain brand design.
4. Rebuild the product/category flows around the new schema.
5. Add riders, billing, customers, inventory, item-profit, marketing, settings, and migration screens using the same compatibility layer.
6. Run `flutter analyze` after each step and resolve issues before continuing.

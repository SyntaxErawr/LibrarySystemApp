# Final mobile testing — Stage 7

Review date: 2026-10-23 (Asia/Manila). Flutter 3.47.7 stable, Dart 3.13.5, Windows 11. This report distinguishes mocked regression results from native and live acceptance. Stages 1–6 were reported manually accepted by the user; this session does not independently certify those earlier live results.

## Architecture and implemented modules

One Flutter frontend uses Provider for authentication, dashboard, catalog, and borrowing state. Dio connects to https://librarysystem-k4fp.onrender.com/api with 30-second connection and 90-second receive timeouts. Authentication verifies /auth/me, restricts the shell to active students, and stores only the JWT through flutter_secure_storage. Login, registration, dashboard, read-only profile, searchable/paginated catalog and details, borrowing requests/cancellation, current loans, pending requests, and history use the existing backend. Home | Books | My Books | Profile remains the single navigation shell. No lib/widgets directory exists; reusable book/request/borrowing widgets live beside their screens.

The existing Express API remains the authorization, ownership, inventory, and borrowing-rule boundary; MongoDB is shared with the React website. There is no second backend, local inventory authority, or fake production data. No production credentials were used, no production writes were run, and no backend/React/hosting/database configuration was edited. No deployment, push, APK distribution, identity change, or signing change was performed.

## API contract review

Read-only inspected backend auth/book/borrowing routes and controllers, User/Book/Borrowing models, auth middleware, server CORS/error handling, shared registration/book validation and borrowing date helpers. The React api.js, BookBrowser, BorrowingBrowser, and student catalog/My Books wrappers were also inspected.

| Method/path | Purpose and verified behavior |
| --- | --- |
| GET /health | Public connection diagnostic, {status, database} |
| POST /auth/login | email/password -> {token,user}; app also verifies /me before accepting |
| POST /auth/register | Student registration fields, no privileged attributes; 201 {message} |
| GET /auth/me | Authoritative current identity, role, active state |
| POST /auth/logout | Increments tokenVersion, revoking ALL previously issued account sessions |
| GET /books | search title/author/ISBN, exact category, availability, page/limit; {books,total,page,pages,categories} |
| GET /books/:id | {book}; students cannot see archived books |
| GET /borrowings/summary | Student-scoped active/pending/overdue counts, recent/upcoming |
| GET /borrowings/my | Own paginated records; active, pending, history, open and other verified filters |
| POST /borrowings/requests | {book}; student derived from JWT; active book, available copies, no duplicate open record, fewer than three combined pending/active items |
| PATCH /borrowings/:id/cancel | Only the student's owned pending request; no inventory change |
| GET /borrowings/requests/status | Verified optional endpoint, not needed by Flutter's open-record eligibility check |

Backend staff approval/issue/reject/return/inventory routes are not called by Flutter. Pending requests do not reserve stock. Approval issues the book as borrowed, with no separate approved status. Valid model statuses are pending/borrowed/returned/rejected/cancelled; controller compatibility includes overdue, and displayStatus/daysRemaining are computed by the server using Asia/Manila. Legacy dueAt is the fallback for dueDate. Flutter shows those server values and formats recorded instants in UTC+08:00. It does not calculate inventory or fabricate dates.

## Findings and scoped fixes

| Severity | Finding | Resolution / evidence |
| --- | --- | --- |
| Medium | Session expiry replaced the shell but left its Navigator confirmation dialog visible over Login | AuthGate dismisses overlay routes after losing the session; simulated JWT-timer expiry test verifies dialog and authenticated content disappear without a write |
| Medium | Book-details PopScope remained registered while its tab was hidden in IndexedStack, consuming Back on Profile/My Books | Catalog receives its active-tab state; hidden details no longer block Back; regression checks route disposition and Back-to-catalog |
| Medium | A post-write dashboard/catalog refresh could reuse a read started before the write and retain old stock/counts | Borrowing refresh coordinator forces new reads; generation checks prevent older dashboard/catalog completions overwriting fresh results; concurrency tests cover both |
| Medium | Android application left Auto Backup enabled for encrypted session preferences | Set android:allowBackup=false per secure-storage guidance; native restore behavior remains an acceptance item |
| Medium | /me access denial (403, including backend CORS rejection) erased saved valid tokens despite not proving revocation | Only 401 or rejected/malformed authoritative identity discards the session; 403 restore stays on Login retaining the token; 403 profile refresh retains previously verified identity. Backend still enforces access. Tests cover both |
| Low | Multiple detail refresh triggers could create overlapping requests and stale completion ordering | Deduplicate in-flight detail reads; lifecycle test verifies one request and safe completion after disposal |
| Low | HTTP 404/422/502 and timeouts could be described as an unreachable server; 403 exposed browser configuration jargon to mobile users | Safe status-specific messages and explicit slow-server feedback; 400/401/409/429 public validation messages remain bounded; tests cover requested statuses and three timeout types |
| Low | Unused direct shared_preferences dependency | Removed after source-use search; dependencies resolved, generated plugin registrations refreshed. Cupertino icons were retained after a trial removal exposed a framework adaptive-font warning; no major upgrades |
| Low | Native Back from registration left white status-bar icons against the cream Login background | Login explicitly sets dark status-bar icons; widget regression and emulator screenshot verification |
| Resolved build setup issue | Initial Android SDK provisioning errors | Serial retry allowed Gradle to complete required NDK/build-tools/CMake provisioning under already accepted component licenses; no manual license acceptance, signing change, SDK-version override, or unrelated tool installation |

No confirmed backend authorization bypass, password persistence, token/header logging, client-side stock mutation, non-idempotent automatic retry, or staff mobile action was found in the reviewed code. This is a scoped code/configuration review with regression tests, not a penetration test or proof that all vulnerabilities are absent.

## Security and platform storage review

- Student parser requires lowercase student role and isActive=true; Admin/Librarian/inactive/malformed identities are rejected before opening the shell. /me is required on restore and login and rechecked on resume/profile refresh.
- JWT stays private to AuthProvider and is attached through the shared authenticated GET/write guard. In-flight responses from a changed session are rejected. 401 clears local storage/state; ordinary network/server/access-denial failures do not invalidate a verified token. Passwords live only in form memory/request bodies, are not trimmed or persisted, and are not logged.
- Local JWT decoding only schedules UI expiry; backend issuer/audience, signature, tokenVersion, active role and ownership checks remain authoritative. Tests simulate timer expiry, revocation, stale requests, role changes, and restoration failures using fake tokens.
- Logout still calls the existing global revocation endpoint, clears local state even on failure, and reports uncertain remote revocation. Profile already tells users that logout ends web sessions.
- Native Android storage uses the installed plugin's RSA OAEP/AES-GCM defaults backed by Android KeyStore. Web storage uses browser WebCrypto and origin-bound localStorage by default, rather than Android KeyStore or HttpOnly cookies. HTTPS/localhost is required; same-origin scripts remain within the web threat boundary. Browser/native storage restoration was not claimed tested by mocked storage tests. See the [plugin documentation](https://pub.dev/packages/flutter_secure_storage).
- Android INTERNET permission is in the MAIN manifest, so debug and release both declare network access. Debug/profile manifests add only the same development permission. No location, camera, contacts, storage, or biometric permission was added. TLS verification and browser security remain enabled. Both final merged manifests declare INTERNET and allowBackup=false, with minSdk=24 and targetSdk=36; AndroidX also contributes its signature-protected dynamic-receiver permission. Native authenticated HTTPS connectivity still requires intentional account acceptance.
- Android minimum is inherited from the installed Flutter SDK: API 24. This exceeds secure storage's API 23 minimum. Java source/target is 17, installed JDK is 21, AGP is 9.1.0 and Gradle is 9.3.1. API 35 emulator availability is verified. Minimum-API and physical-device runs are not tested.
- Release retains the existing debug signing configuration and com.example.librarysystemapp identity. This is suitable only for internal test builds, not a production distribution claim. Production identity/signing decisions remain outside this task.
- Auto Backup was disabled; manufacturer-specific device-transfer/restore behavior still needs device acceptance rather than an assumption that every transfer mechanism is excluded.

## Dependencies and advisories

flutter pub get succeeded after removing the unused shared_preferences dependency. Kept Dio 5.11.1, flutter_secure_storage 11.2.0, Provider 6.1.5+1 and intl 0.20.3 constraints. No unnecessary major upgrade was attempted. pub outdated initially reported newer compatible transitive packages plus a major Cupertino icon upgrade; optional upgrades were not needed for the confirmed bugs. Analyzer found no deprecated-API warnings in the final code.

The [Dio method-injection advisory](https://github.com/cfug/dio/security/advisories/GHSA-9324-jv53-9cc8) affects versions before 5.0.0; the installed 5.11.1 is outside that range. The [HTTP/2 redirect advisory](https://github.com/cfug/dio/security/advisories/GHSA-cr65-55v9-xhvv) affects dio_http2_adapter through 2.7.1; that optional adapter is absent from this dependency graph. The [secure-storage maintainer advisory page](https://github.com/juliansteenbakker/flutter_secure_storage/security/advisories) had no published advisories when checked. This targeted check does not certify every transitive dependency or undisclosed issue.

## Automated results

| Check | Result |
| --- | --- |
| flutter pub get | Passed |
| flutter analyze | Passed: no issues |
| flutter test | Passed: 105 tests, zero failures (83 existing + 22 added) |
| flutter build web | Passed, including Wasm dry run |
| flutter build apk --debug | Passed: build/app/outputs/flutter-apk/app-debug.apk |
| flutter build apk --release | Passed: build/app/outputs/flutter-apk/app-release.apk; existing debug test key |
| Emulator startup | Pixel_3a_API_35 booted; adb detected emulator-5554 |
| Native smoke / full acceptance | Final debug and release APKs installed and cold-launched to Login on API 35 emulator; debug validation/keyboard/registration/Back checks observed; authenticated acceptance remains pending |
| Live authenticated web/mobile scenarios A–E | Not tested in this session; no production credentials or mutations |

Coverage includes authentication validation/restoration/role rejection, protected reads/writes, secure-storage doubles, session expiry, logout, active/pending/history records, all supported statuses, missing/legacy fields, Manila dates, server overdue counts, catalog filters, archived visibility, stock parsing, request/cancel confirmation and progress, double-tap locks, duplicate/three-item/out-of-stock conflicts, stale responses, post-write count/stock reads, pagination contracts, empty/error states, keyboard/320px phone layouts, lifecycle/disposal, and tab/Back navigation. Business-rule failures are simulated, not executed against MongoDB. Security/access constraints are also verified by read-only backend inspection.

An intermediate analyzer/test run caught a nullable-status pattern compile error introduced while improving HTTP messages; it was corrected before the clean final 105-test run. Initial Android SDK setup attempts failed; they are not counted as passed builds. No unresolved Dart analyzer or automated regression failure remains.

## Exact source/configuration files changed in Stage 7

- lib/main.dart
- lib/providers/auth_provider.dart
- lib/providers/book_provider.dart
- lib/providers/dashboard_provider.dart
- lib/services/auth_service.dart
- lib/screens/auth/login_screen.dart
- lib/screens/student_shell.dart
- lib/screens/books/book_catalog_screen.dart
- lib/screens/books/book_details_screen.dart
- android/app/src/main/AndroidManifest.xml
- pubspec.yaml
- pubspec.lock (dependency resolution)
- test/final_regression_test.dart (created)
- FINAL_MOBILE_TESTING.md (created)

Flutter also regenerated plugin/tool metadata, including android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java, macos/Flutter/GeneratedPluginRegistrant.swift, .flutter-plugins-dependencies, and local build/package metadata. android/local.properties may be refreshed by Flutter with local SDK/build values; no package IDs, release signing, backend, or React source were edited. stage7-*.log files retain verification output; earlier SDK failures are preserved in stage7-android-*-first.log. Emulator startup output is in the workspace parent emulator-stage7*.log files.

## Manual Android checklist

1. Both Android builds now pass. For another workstation, verify required SDK/NDK/build-tools/CMake components with flutter doctor -v and review any outstanding SDK licenses yourself. Keep project versions, package ID, and signing unchanged. A release build still uses the existing test key.
2. Start the existing emulator or connect a physical phone. Run flutter devices, then flutter run -d <device-id>. Verify cold start, process kill/relaunch, rotation, background/resume, keyboard Next/Done, small screen, large text, safe areas and scrolling without overflow. Check TalkBack labels, dialog focus, readable due dates, disabled actions, and accessible touch targets.
3. Sign in intentionally with an existing active Student account. Verify account details and optional-field fallbacks, current Home counts/recent activity and profile refresh. Verify Admin/Librarian rejection. Register only if a real new account is intended.
4. Browse/search title/author/ISBN, change category/availability, load more, open details, press Android Back, switch to Profile while details are open, and press Back again. Confirm no hidden screen consumes the wrong action. Refresh catalog/details after staff inventory changes.
5. Open Request Book and Cancel Request confirmations. Verify Cancel/Back dismisses without writes, busy actions cannot double-submit, expiry removes the dialog and shell, and failures explain whether an action needs refreshing. Check duplicates, the combined three-item limit, no-stock conflicts and stale cancellation states using intentional test records.
6. Verify native secure session restoration, server-revoked token handling, expiry while open, resume validation, local logout and web-wide revocation. Test offline/cold-start timeout recovery without deleting a valid saved token. Verify backup/restore or device transfer never silently trusts restored account data without /me.
7. Install/run an approved internal release build and repeat HTTPS/network and storage checks; debug success alone cannot prove release connectivity. No APK is automatically distributed by this task.

## Reproducible web/mobile integration scenarios

Use existing authorized student/staff accounts and an agreed real test book. These are intentional manual database mutations; no automated production mutation was performed. Record IDs, before/after counts, observed stock, client versions and timestamps in Manila. Refresh each client explicitly; Flutter does not claim push synchronization.

| Scenario | Steps | Expected observation |
| --- | --- | --- |
| A: Flutter request -> website | Student opens available book, confirms Request Book; staff opens website Pending Requests and refreshes | Same student/book request is Pending on both; Flutter pending summary updates; availableCopies unchanged |
| B: Website approval -> Flutter | Staff approves/issues that pending request on website; student refreshes Currently Borrowed and Home, then catalog/details | Same record becomes Borrowed (or server Overdue as appropriate); backend issue/due dates appear; pending count falls, active rises; stock matches website |
| C: Flutter cancel -> website | Create an intentional pending request; student confirms Cancel Request; staff refreshes website request list | Same record becomes Cancelled/history; pending count falls; stock unchanged; later cancellation conflicts refresh safely |
| D: Website return -> Flutter | Staff returns an issued loan through website; student refreshes Currently Borrowed, Borrowing History, Home and catalog | Record leaves active, appears Returned with recorded return date; active count and server stock match website |
| E: Website inventory -> Flutter | Staff intentionally updates an active book through existing website rules; student refreshes catalog and details | Exact saved title/category/stock data appears; an archived book disappears for students; old pending requests never locally decrement stock |

Observed native smoke checks in this session: API 35 emulator startup/adb detection, final debug and release APK installation/cold launch to Login, empty-form validation, registration navigation, keyboard resizing and Back navigation. The final debug status-bar correction was visually confirmed. These used no credentials and submitted no valid form. The five cross-client scenarios, real account testing, native secure storage persistence, physical devices, authenticated release runtime, and full screen-reader acceptance are NOT independently observed here.

## Final build/runtime outcome and readiness

The app is ready for final student mobile acceptance testing. Automated regression and build gates pass. It is not certified for production distribution: authenticated cross-client scenarios A–E, native token persistence/revocation with real accounts, physical/minimum-API devices, release HTTPS connectivity, backup/transfer, and full accessibility acceptance remain to be performed. The existing release test-key signing and example application identity have been preserved.

Final command completion: all requested build commands exited 0. Final web build completed with the Wasm dry run; debug APK build completed in 14.3s and release Gradle build in 45.2s. Initial SDK setup failures were resolved by the serial retry; remaining SDK CLI XML/duplicate platform-tools warnings were nonfatal. Required Android components were provisioned automatically by the build tooling; no unrelated tools or manual license changes were made.

Native evidence: [Login](stage7-android-login.png), [empty-form validation](stage7-android-validation.png), [registration](stage7-android-register.png), [keyboard](stage7-android-keyboard.png), [corrected status bar after Back](stage7-android-back-fixed.png), and [final release startup](stage7-android-release-startup.png). These screenshots contain empty forms, not account credentials. The emulator started for this review was shut down after smoke testing. No physical device was used. The local APKs were not distributed.
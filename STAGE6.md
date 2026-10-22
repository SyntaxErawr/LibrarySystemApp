# Stage 6: Student Borrowing Requests and My Books

Implemented and verified against the local existing backend contract. Live account and native-device acceptance remain manual. No Express, React, infrastructure, or production database changes were made. Automated tests use mocked HTTP and storage only.

## Verified API contract

Read-only inspection: server/routes/borrowingRoutes.js, controllers/borrowingController.js, models/Borrowing.js, models/Book.js, middleware/authMiddleware.js, and shared/borrowingDates.mjs in LibrarySystemFinals/LibrarySystem. Existing Flutter authentication, catalog, dashboard summary/date handling, theme, and shell were inspected before integration.

All paths use the existing API base URL and Bearer session.

| Operation | Contract |
| --- | --- |
| Request | POST /borrowings/requests, body {book: bookId}; 201 {borrowing, message} |
| Own records | GET /borrowings/my?status=...&page=1&limit=20; {borrowings, total, page, pages} |
| Cancel | PATCH /borrowings/:id/cancel, empty body; 200 {message} |
| Dashboard | GET /borrowings/summary; existing activeCount, pendingCount, overdueCount, recent, upcoming |
| Optional catalog status | GET /borrowings/requests/status?books=commaSeparatedIds; {requests}; verified but not needed because the app loads the student's complete open records for both duplicates and combined-limit checks |

Own-record filters: empty, active, borrowed, overdue, returned, pending, rejected, cancelled, history, open. The backend also accepts search (up to 120 characters, student name/School ID or book title/ISBN). Pages 1..100000; limit 1..100. Results sort by createdAt descending then ID descending. Flutter uses active/pending/history sections and the open filter for eligibility, with 20-row pages and Load more.

Student authorization is enforced by the backend. The /my list scopes records to the authenticated user; request creation derives the student from the session; cancellation checks ownership and pending status. The app never sends a student ID or uses staff list/approval/issue/return routes.

Request validation: valid book ID, active student, fewer than three combined pending requests and active loans, no open record for the same book, active book, availableCopies greater than zero. Pending requests do not reserve or decrease stock. Approval and issuing are staff operations. Approval changes the request into borrowed; there is no separate approved status.

Stored model statuses: pending, rejected, cancelled, borrowed, returned. The controller also supports legacy overdue records and returns displayStatus and daysRemaining. Date/status calculations use Asia/Manila: a loan becomes overdue after its due calendar day, not during that day. Returned records are not overdue. dueAt is the legacy fallback for dueDate. Flutter displays server-computed status/day counts rather than recalculating from the device clock; displayed dates use UTC+08:00, consistent with the existing dashboard.

Relevant errors: 400 invalid ID/book/student; 401 missing/expired/inactive/revoked session; 403 wrong role; 404 missing or unowned cancellation request; 409 combined limit, duplicate open record, no stock, or request no longer pending. Server public 400/401/409/429 messages are preserved by existing authentication error handling. Cancellation 404 has a request-specific refresh message. Other failures use safe generic messages.

## Files created or modified

Created:
- lib/models/borrowing.dart
- lib/services/borrowing_service.dart
- lib/providers/borrowing_provider.dart
- lib/screens/books/request_book_action.dart
- test/borrowing_test.dart
- test/borrowing_widget_test.dart
- STAGE6.md

Implemented the previously empty borrowing screen files:
- lib/screens/borrowings/my_books_screen.dart
- lib/screens/borrowings/borrow_requests_screen.dart

Modified:
- lib/services/api_service.dart: token-scoped PATCH helper.
- lib/services/auth_service.dart: authenticated POST/PATCH using existing error handling, without automatic retries.
- lib/providers/auth_provider.dart: shared authenticated read/write session guard; JWT remains private.
- lib/screens/student_shell.dart: one borrowing provider, lazy My Books screen, refresh coordination; existing four destinations preserved.
- lib/screens/books/book_details_screen.dart: Request Book component.
- lib/screens/books/book_catalog_screen.dart: system Back returns from details to catalog.
- test/student_screens_test.dart: replace the former My Books placeholder assertion with the new section selector.

## Implemented behavior

Book details check current open records before allowing requests. Unknown eligibility disables submission and offers Refresh borrowing status. Duplicate open records and the combined three-item limit explain why the action is blocked. Missing stock or no available copies disables requesting. Confirmation precedes submission; loading and an account-wide mutation lock prevent double submission. Success/error feedback remains visible after fresh detail loading.

My Books has Currently Borrowed, Pending Requests, and Borrowing History sections. Cards display populated title/author, actual status, recorded request/borrow/due/return dates, server days remaining/overdue, and rejection reasons. Missing legacy values show explicit fallbacks. Only pending records offer cancellation, with confirmation, progress, and server-side stale-state handling. Lists support refresh, pagination, loading, empty states, and errors with Retry.

Every mutation is attempted once. After success or failure, open eligibility and the selected section are fetched again because a timed-out write could have committed. Dashboard summary and catalog are refreshed through the existing providers. Successful requests also reload book details. Stock is always read from the server. List generations suppress stale section responses; repeated in-flight reads are deduplicated. Logout/session expiry disposes the authenticated shell and its borrowing state.

## Verification

On 2026-10-23 (Asia/Manila):
- flutter pub get: succeeded.
- flutter analyze: no issues.
- flutter test: all 83 tests passed.
- flutter build web: succeeded, including the Wasm compatibility dry run.

New tests cover all supported statuses, legacy and missing fields, Manila date boundary formatting, server-provided overdue/day counts, exact own-list and write contracts, non-pending cancellation rejection, duplicate and combined-limit eligibility, in-flight mutation exclusion, stock/limit/duplicate/conflict messages without retries, POST/PATCH Bearer authentication and 401 credential clearing, request/cancel dialogs, pending/history navigation, dashboard refresh requests, unavailable stock, stale cancellation conflicts, empty state, and 320px phone layouts. Existing authentication/dashboard/catalog tests remain passing. Backend business logic is verified by inspection and simulated responses, not by mutating live records.

## Supported scope and limits

No backend capability required for this stage is missing. There is no push or real-time synchronization; refresh retrieves staff actions made on the website. Students cannot approve, issue, reject, or return books through this mobile UI. No new borrowing rules or automatic write retries were introduced. Production deployment parity and real authenticated interoperability have not been tested without user credentials.

## Manual acceptance

Run flutter run -d chrome --web-port=7357 with a full restart, or use flutter run -d <device-id> on Android.

1. Sign in with an existing student account. Open Books, select a book with available copies, and confirm its stock matches the website.
2. Select Request Book. Check that dismissing confirmation creates nothing. Confirm only if you intend to create a real pending request. Verify success, pending state, unchanged stock, and the dashboard pending count.
3. Open My Books, choose Pending Requests, and verify dates/status. Confirm the same request appears on the website. Reopen its details and verify the duplicate explanation.
4. Cancel a pending request intentionally; verify confirmation, updated dashboard count, its Cancelled history entry, and unchanged stock on both clients.
5. Where suitable accounts already have three open items, verify the combined limit explanation. Check unavailable books cannot be requested. Concurrent changes should show backend conflict feedback and allow refreshing.
6. Have staff use the existing website approval/issue/return/reject flows as appropriate for intentional manual test records. Refresh My Books, Home, and the catalog/details. Check active loans, due dates, returned/rejected history, rejection reason, and server stock match the website. Native dates must remain Manila dates even if the device timezone differs.
7. Check offline errors and Retry, pending-request cancellation races, session expiry, logout, system Back from details, and navigation to all four destinations. Recheck login/register/profile and search/filter functionality. Test keyboard and larger text on a phone.

Manual actions above can change real records; automated verification did not. No deployment or Git push was performed.

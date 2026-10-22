# Stage 4: student dashboard and profile

## Verified backend APIs

Read-only inspection covered auth and user routes/controllers, JWT middleware,
borrowing routes/controllers/model, and `shared/borrowingDates.mjs` in
`C:/Users/Home/Desktop/LibrarySystemFinals/LibrarySystem`.

| Endpoint | Use and verified response |
| --- | --- |
| GET `/api/auth/me` | Existing authenticated profile refresh; `{user}` with `_id`, name, email, role, isActive, studentId, course, yearLevel |
| GET `/api/borrowings/summary` | Dashboard: `{activeCount, pendingCount, overdueCount, recent, upcoming}`; recent contains at most five populated borrowing records |
| GET `/api/borrowings/my` | Verified own-record paginated endpoint `{borrowings,total,page,pages}`; not needed or called in this stage |
| POST `/api/auth/logout` | Existing logout and token revocation, unchanged |

Both GET endpoints use JWT Bearer authentication and the existing API configuration.
For a student, the summary queries always include `student: req.user._id`.
The `/my` route also forces own-record scoping. No supplied student ID or
staff-only list endpoint is used by the dashboard.

Active totals include overdue loans. Pending totals count pending requests.
Overdue totals come directly from the backend: active/unreturned loans whose
`dueDate` (or legacy `dueAt`) precedes the start of today in Asia/Manila.
Flutter does not recalculate these rules. Recent statuses use the backend's
`displayStatus`, not the stored status or the device clock. Missing/invalid
counts show Unavailable rather than zero; an empty recent array has an empty state.

Backend dates are MongoDB ISO timestamps. Relevant status dates are displayed
in Manila time, falling back to the explicitly labeled record creation date.
Missing titles, statuses, and dates have honest unavailable/not-recorded labels.
Recent records are returned by creation order; this is not a full audit history.

## Implementation

Home shows the student's name, branding, three summary cards, recent activity,
quick actions, a manual refresh button, and pull-to-refresh. It has loading,
empty, partial/unavailable, error, and clearly labeled stale-data states.
Temporary failures preserve the last successful summary so they do not turn
valid counts into misleading zeroes. Concurrent dashboard refreshes share one
request; switching tabs does not refetch the summary or profile.

Profile displays full name, email, School ID, program, year, account role, and
active status from the verified student model. Missing/blank optional fields
show Not provided. Button and pull-to-refresh reuse AuthProvider.refreshStudent.
Logout uses the existing provider; its cross-web-session behavior is unchanged.

One StudentShell owns Home/Books/My Books/Profile navigation, with quick actions
selecting the same tabs. Books and My Books are explicitly unavailable placeholders.
The shell and its dashboard state are removed when the session ends. Protected
reads preserve existing 401 handling and reject responses arriving after logout.
Async dashboard completions do not notify disposed providers.

Authentication forms, login, registration, session restoration, backend business
rules, and secure storage were preserved. No backend/database writes, production
deployments, or Git pushes were performed. Tests use fake HTTP and token storage.

## Files

Created:

- `lib/models/dashboard_summary.dart`
- `lib/services/dashboard_service.dart`
- `lib/providers/dashboard_provider.dart`
- `lib/screens/student_shell.dart`
- `test/dashboard_test.dart`
- `test/student_screens_test.dart`
- `STAGE4.md`

Updated:

- `lib/main.dart`: signed-in shell instead of the temporary dashboard
- `lib/models/student.dart`: retain verified role and active flag
- `lib/providers/auth_provider.dart`: token-private protected GET with session-expiry handling
- `lib/services/auth_service.dart`: reuse existing safe exception handling for protected GET
- `lib/config/app_theme.dart`: shared Stage 4 palette constants
- `lib/screens/dashboard/dashboard_screen.dart`: real dashboard
- `lib/screens/profile/profile_screen.dart`: view-only profile
- `test/auth_test.dart`: extend the shared fake backend with summary responses
- `test/auth_widget_test.dart`: existing logout test now navigates to Profile

## Capability limits and manual acceptance

Final automated checks passed:

- `flutter pub get`: dependencies resolved
- `flutter analyze --no-pub`: no issues found
- `flutter test --no-pub`: all 61 tests passed
- `flutter build web`: succeeded, including the Wasm compatibility dry run

Coverage includes server-derived counts/statuses, missing and empty responses,
loading/errors/retry, duplicate-request prevention, disposal/logout races,
profile fields and refresh, shared navigation, student-only access, Profile
logout, and 320-pixel phone layouts with increased text size, alongside all
existing Stage 3 authentication and health tests.

No authorized student self-edit endpoint exists: `/api/users` routes require
Admin/Librarian authorization. Profile editing is intentionally absent. All
required Stage 4 counts and current profile fields have supported endpoints.
No production credentials were used to fetch private account/borrowing data;
source contracts and test doubles underpin automated verification. Manually
check the deployed endpoint with your accepted student account.

From the Flutter project directory, restart the app:

```powershell
flutter run -d chrome --web-port=7357
```

1. Sign in with an existing student account. Compare Home counts and recent
   records with that student's web account; active includes overdue.
2. Refresh Home using its button or pull-to-refresh. Temporarily disconnect the
   network and retry; expect an error and previously loaded activity, then
   restore connectivity and refresh successfully.
3. Open Profile and verify all seven fields. Refresh to retrieve current account
   information. Legacy missing fields should read Not provided.
4. Switch tabs and use all quick actions. Books and My Books must say they are
   unavailable; navigation must preserve the signed-in student session.
5. Test a narrow phone viewport and increased text size. Scroll to reach content
   and profile actions without horizontal overflow.
6. Log out from Profile and confirm Login returns. Reload to confirm the local
   session was cleared. Existing Admin/Librarian accounts must remain rejected.

For Android, use `flutter devices`, then `flutter run -d <device-id>`. Automated
tests do not create or modify real accounts or borrowing records.

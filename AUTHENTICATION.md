# Stage 3: student authentication

## Verified backend contract

Read-only inspection of `LibrarySystemFinals/LibrarySystem/server` covered
`routes/authRoutes.js`, `controllers/authController.js`, `models/User.js`,
`middleware/authMiddleware.js`, `utils/accountInput.js`, `server.js`, and
`../shared/validation.mjs`. Backend files and production infrastructure were not modified.

All paths below use the existing `ApiConfig.baseUrl`:

| Request | Body / response |
| --- | --- |
| POST `/auth/login` | `email`, `password`; returns `{token, user}` |
| POST `/auth/register` | `name`, `studentId`, `email`, `course`, `otherProgram` when course is `Other`, `yearLevel`, `password`, `confirmPassword`; returns 201 `{message}` |
| GET `/auth/me` | Bearer token; returns `{user}` |
| POST `/auth/logout` | Bearer token; increments tokenVersion and invalidates all account sessions |

Users contain `_id`, `name`, `email`, lowercase `role`, `isActive`, and student
fields. Legacy student accounts may lack school/program/year details; they remain
valid and display “Not provided”. Backend JWTs last two hours. Their existing
issuer/audience and authentication/authorization rules are unchanged.

Passwords require eight Unicode code points, ASCII uppercase/lowercase/digit,
a character outside Unicode letters/numbers/whitespace, and at most 72 UTF-8
bytes. Passwords are never trimmed or persisted. Login intentionally does not
enforce new-account complexity on existing passwords. Name is limited to 100
UTF-16 units, School ID to 50, email to 254, and Other program to 100. Programs
are BSIT/BSCS/BSBA/BSHM/Other; years are 1st–4th Year. These match shared validation.

## Implementation and session behavior

- `main.dart` uses Provider and an authentication gate instead of the diagnostic screen.
- `services/api_service.dart` retains health checks/timeouts and adds token-scoped GET/POST helpers.
- `services/auth_service.dart` implements the verified endpoints and safe failure mapping, with no automatic POST retries.
- `services/token_store.dart` stores only JWTs using flutter_secure_storage.
- `models/student.dart` accepts only active lowercase student accounts.
- `providers/auth_provider.dart` owns restoration, loading/errors, student state, secure storage, logout, and expiry.
- `utils/auth_validation.dart` mirrors shared registration validation.
- `screens/auth/login_screen.dart` and `register_screen.dart` provide scrollable phone forms, password visibility, validation, and registration feedback.
- `screens/dashboard/dashboard_screen.dart` shows account details, refresh, and logout only.
- `test/auth_test.dart` and `test/auth_widget_test.dart` use fake HTTP/storage, not real accounts.

Login checks the backend user role and then `/me` before storing a token or
opening the dashboard. Nonstudents are rejected and local credentials removed.
Restoration requires a fresh `/me` response. Authentication is rechecked on app
resume and account refresh; 401, rejected roles, and invalid user data remove
local sessions. JWT expiry schedules sign-out while the app remains open; local
JWT decoding is used only for the timer, never for trusting account data.
Transient restore failures keep the saved token for a later restart but show Login.

Logout calls the existing endpoint and always clears local state/storage. If the
request fails, the user is told that remote revocation was not confirmed. A
successful logout also invalidates web sessions, matching existing backend behavior.
Backend route authorization remains the security boundary; no privileged routes,
role assignments, or authentication rules were changed.

## Verification and manual acceptance

`flutter pub get` succeeded. Tests cover health, login responses, role rejection,
Bearer requests, secure storage behavior, restoration, invalid sessions, logout,
registration validation, duplicate field errors, and phone layouts with a keyboard.
Authentication requests in tests use doubles and never modify MongoDB records.
Final results: `flutter analyze` found no issues, all 44 tests passed, and
`flutter build web` succeeded (including its Wasm compatibility dry run).

On 2026-10-23 (Asia/Manila), live health returned 200 with the expected JSON and
`Access-Control-Allow-Origin: http://localhost:7357`. Auth login preflight returned
204 and allowed `content-type,authorization`. No Render change is currently needed.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port=7357
```

Use a full restart of the previous diagnostic app. Sign in with an existing student
web account; confirm the welcome screen and account data. Reload to check secure
session restoration. Use an existing Admin/Librarian account to confirm rejection.
Register manually only if you intend to create a real account; registration returns
to Login. Check incorrect credentials, duplicate email/School ID, and logout.
Android can be checked with `flutter devices` and `flutter run -d <device-id>`.

Actual credential-based production login and native device secure storage remain
manual acceptance checks; no real user credentials were supplied or used. No
book, borrowing, profile modules, backend deployment, or Git push was performed.

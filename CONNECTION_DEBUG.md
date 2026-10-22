# Backend connection diagnosis

Stage 3 update (2026-10-23): the deployed backend now returns GET 200 and auth
OPTIONS 204 for `http://localhost:7357`, with the correct allow-origin and
content-type/authorization headers. The earlier rejection below is historical.
The diagnostic screen has been replaced by authentication; the health service
and its tests remain available. See `AUTHENTICATION.md` for the current flow.

On 2026-10-23 (Asia/Manila), the deployed health endpoint returned HTTP 200
with `{"status":"ok","database":"connected"}` without an Origin header.
GET and OPTIONS using `http://localhost:7357` returned HTTP 403 with
`{"message":"Origin is not allowed."}`. The running Flutter process targets
web, with Flutter-launched Chrome at `http://localhost:60012`.

The API base URL, `/health` path, JSON checks, and 30-second connection /
90-second receive timeouts were already correct. There is one API configuration.
No DNS, TLS, cold-start, 404, 500, or 503 failure was observed in the live probes.
Browser CORS failures can hide the server status from Dio; use DevTools Network
and Console alongside the safe debug logs. A timeout alone cannot prove a cold start.

## Required backend change (not applied)

Backend source is not in this workspace. In the existing Express origin
allowlist, retain all existing Vercel origins and add exactly
`http://localhost:7357` for a stable local Flutter port. To keep the currently
running session instead, also allow `http://localhost:60012`.
Origins have no path or trailing slash; `127.0.0.1` is a separate origin.

Use the existing backend configuration variable if it supplies the allowlist;
its name cannot be determined from this Flutter-only workspace. Otherwise update
the existing CORS middleware. Mount it before API routes and authentication, so
allowed OPTIONS requests complete without authentication. With the Express `cors`
package, application-level `app.use(cors(existingOptions))` handles preflight;
preserve existing methods, headers, credentials, authorization, and native
requests without Origin. Do not add wildcard access or a second conflicting
CORS middleware. The current origin rejection middleware must also use the
updated list. A backend redeploy is needed after an approved code/config change.

## Reproduce and verify

From this directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port=7357
```

Stop the existing Flutter run before starting the fixed-port session. After the
backend allowlist update, click **Test Connection** and expect **Backend Connected
Successfully!**. Debug output includes the platform and browser origin. No
automatic retries were added.

```powershell
curl.exe -i --max-time 120 https://librarysystem-k4fp.onrender.com/api/health
curl.exe -i --max-time 120 -H "Origin: http://localhost:7357" https://librarysystem-k4fp.onrender.com/api/health
curl.exe -i --max-time 120 -X OPTIONS -H "Origin: http://localhost:7357" -H "Access-Control-Request-Method: GET" https://librarysystem-k4fp.onrender.com/api/health
```

Expect GET 200 with the healthy JSON and, for browser requests,
`Access-Control-Allow-Origin: http://localhost:7357`. Expect OPTIONS 200/204 with
that same allowed origin and GET in the allowed methods. curl does not enforce
CORS; the final browser test is required. The simple current GET may not need
preflight, but OPTIONS must work for requests that do.

Android release builds now declare INTERNET permission in the main manifest;
debug/profile already declared it. No Android device is currently detected.
Windows desktop is not listed by `flutter devices`. The existing macOS sandbox
entitlements also lack network client access; macOS is not the active target and
was not changed. If targeting macOS later, add
`com.apple.security.network.client` to both Runner entitlements.

Validation: `flutter pub get` succeeded, `flutter analyze` found no issues, and
all 12 health-check tests passed (healthy, unhealthy/malformed JSON, HTTP failures,
and network/timeouts). Tests use a fake Dio adapter, not production requests.
The obsolete counter widget test referenced nonexistent `MyApp` and was replaced.
Layout, theme, backend, database, and authentication were not changed.

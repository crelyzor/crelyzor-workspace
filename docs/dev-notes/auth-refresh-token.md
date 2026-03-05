# Auth — Refresh Token — Dev Notes

## What was built
Backend refresh token issuance + rotation, and frontend Axios interceptor to auto-refresh on 401.

## Patterns used
- Refresh token issued on login, stored in DB (`RefreshToken` model).
- Token rotation on each refresh — old token is revoked, new one issued.
- `POST /auth/logout` invalidates refresh token in DB.

## Frontend interceptor pattern
- Axios response interceptor catches 401.
- Calls `POST /auth/refresh` automatically.
- Retries the original failed request with the new access token.
- On refresh failure (expired/invalid refresh token): clear auth state (`useAuthStore`) and redirect to `/signin`.
- Single retry only — do not loop.

## Gotchas
- Interceptor must handle the case where the refresh call itself returns 401 — otherwise you get infinite retry loops. Check if the failed request was itself the refresh endpoint before retrying.
- Access token is short-lived (15min). Refresh token is long-lived (30 days).

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A digital **tontine** (rotating savings group) platform for Senegal, with mobile-money payments (Wave / Orange Money), OTP phone auth, and an anonymous emergency-aid feature ("Sutura"). The codebase, routes, and DB fields are in **French** — keep new code consistent (e.g. `nom`, `telephone`, `cotisation`, `tirage`, `montant`).

Domain glossary:
- **Tontine** — a savings group; members contribute on a schedule and take turns receiving the pot.
- **Cotisation** — a member contribution/payment (via Wave or Orange Money).
- **Tirage** — the draw that decides which member receives the pot this round (`tour`).
- **Sutura** — an emergency-aid request voted on by members; the requester (`demandeur_id`) is **never exposed** by the API (anonymity is a hard requirement).
- Roles: `admin` (creates tontines, invites, runs draws) and `membre`.

## Repository layout — read this first

This repo bundles **four** directories, two of which are duplicates/scaffolds. Only two are live:

| Path | Status | What it is |
|------|--------|------------|
| `lib/` + `pubspec.yaml` (repo root) | **LIVE** | The real Flutter client (mobile + web), package name `tontine`. |
| `tontine_api/` | **LIVE** | The runnable Laravel **12** backend (Passport OAuth2). |
| `laravel/` | duplicate | Source-only snapshot of the backend's custom code (`app/`, `database/`, `routes/` only). Files are identical to `tontine_api/`. **Don't edit here** — change `tontine_api/` instead. |
| `tontine_app/` | scaffold | Empty default Flutter project (stub `main.dart` only). Not used. |

Note: `GUIDE_INSTALLATION.md` refers to `flutter/` and `laravel/` dirs and "Laravel 11" — those names/versions are aspirational. The actual layout is the table above; `tontine_api/composer.json` pins Laravel `^12.0`.

## Commands

### Flutter client (run from repo root)
```bash
flutter pub get
flutter run -d chrome            # web; or `flutter run` for a device
flutter analyze                  # lint (flutter_lints)
flutter test                     # all tests
flutter test test/widget_test.dart   # a single test file
```

### Laravel backend — Docker (no local PHP needed)
```bash
cd tontine_api
docker compose up --build        # installs deps, migrates, configures Passport, serves :8000
```
The entrypoint (`docker-entrypoint.sh`) runs composer install + `key:generate` + `migrate` + Passport key/personal-client setup idempotently, then `php artisan serve` on `0.0.0.0:8000`. SQLite only — no DB/Redis container (matches `.env.example`). `vendor` lives in a named volume; the SQLite file persists at `database/database.sqlite` on the host.

### Laravel backend — local PHP (run from `tontine_api/`)
```bash
composer install
cp .env.example .env && php artisan key:generate
php artisan migrate              # sqlite by default (database/database.sqlite)
php artisan passport:install     # required: issues OAuth2 keys/clients
php artisan serve                # http://127.0.0.1:8000

composer dev                     # serve + queue + pail logs + vite, all at once
php artisan queue:work           # payments & notifications are queued jobs
composer test                    # or: php artisan test
php artisan test --filter=SomeTest   # a single test
./vendor/bin/pint                # PHP formatter/linter
```

## Architecture

**Client → API contract.** The Flutter app talks to the backend only through `lib/services/api_service.dart`. The base URL is **hardcoded** at `lib/services/api_service.dart:5` (currently a LAN IP) — change it there to point at your backend. A Dio interceptor attaches `Authorization: Bearer <token>` on every request, reading the token from `flutter_secure_storage` (key `auth_token`).

**Auth flow (OTP, two steps).** `POST /auth/send-otp` then `POST /auth/verify-otp`. On verify the API returns `{ token, user }`; the token is persisted via `ApiService.saveToken`. In the Flutter layer this is mediated by `AuthProvider` (`lib/providers/auth_provider.dart`), which drives an `AuthStatus { unknown, authenticated, unauthenticated }` state machine. `lib/main.dart`'s `_AppShell` watches that status to switch between the splash, `LoginScreen`, and the main bottom-nav shell. On `verify-otp`, sending `prenom`+`nom` means **register**; omitting them means **login**.

**Flutter state & structure.** State management is `provider` (`ChangeNotifier`). Screens live under `lib/screens/<feature>/`, shared widgets in `lib/widgets/`, JSON models in `lib/models/models.dart` (hand-written `fromJson`, lenient with null-coalescing defaults), theme/colors in `lib/theme/app_theme.dart`. There is a single root provider (`AuthProvider`); other screens call `ApiService` directly.

**Backend structure.** Thin controllers in `tontine_api/app/Http/Controllers/` (one per domain: Auth, Tontine, Cotisation, Sutura, Dashboard, Notification), with cross-cutting logic in `app/Services/` (`OtpService`, `PaiementService`, `NotificationService`). All routes are defined in `tontine_api/routes/api.php`. Public routes: `auth/*` and the payment webhook `POST /cotisations/webhook` (called by Wave/Orange Money, no auth). Everything else is behind `auth:api` (Passport bearer). Controllers return `response()->json([...])`, typically with a French `message` key; role checks use `$request->user()->isAdmin` / `->role`.

**Payments.** A cotisation is *initiated* (`/cotisations/initier`) → user pays via Wave/Orange Money → the provider hits the webhook → status moves `en_attente` → `confirme`/`echoue`. Webhook signature verification and provider keys live in `PaiementService` and `.env`.

**Schema.** Custom migrations are `tontine_api/database/migrations/2024_01_01_000001_create_users_table.php` and `..._000002_create_core_tables.php` (the rest are framework/Passport tables). Full ER diagram is in `GUIDE_INSTALLATION.md` §5. Models use soft deletes.

## Gotchas

- **`laravel/` is a dead copy.** Edits there have no effect on the running app. Backend changes go in `tontine_api/`.
- **Some client routes don't match the API.** e.g. `ApiService.joinTontine` posts to `/tontines/join-invite`, but the route is `/auth/join-invite`; and `routes/api.php` declares register as `/auth/register` *inside* the `auth` prefix, yielding `/api/auth/auth/register`. Verify the actual path in `routes/api.php` before wiring up a screen.
- Two `pubspec.yaml` files exist (root `sdk: >=3.0.0`, `tontine_app/` `sdk: ^3.10.7`) — the root one is the app you build.
- Backend defaults to **SQLite**; the install guide assumes MySQL+Redis for production. Match `.env` to your target.

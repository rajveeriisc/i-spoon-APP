# Contributing to SmartSpoon

This guide helps new contributors ramp up quickly.

## Project structure

- smartspoon/ – Flutter app
  - lib/ui/theme/ – app themes
  - lib/ui/widgets/ – reusable widgets (e.g., NetworkAvatar)
  - lib/pages/ – screen pages
  - lib/services/ – API and platform services
  - lib/state/ – providers and app state
- ispoon-backend/ – Node/Express API (PostgreSQL)
  - src/modules/*/routes.js – mounted in app.js
  - src/controllers/ – route handlers
  - src/models/ – DB access (SQL)
  - src/middleware/ – auth, validation
  - src/utils/ – helpers
  - uploads/ – local avatar storage (dev)

## Conventions

- Keep UI logic lean; extract reusable components to lib/ui/widgets.
- Network calls go in lib/services. Use AuthService for auth/user.
- Update global user state via UserProvider.setFromMap after profile changes.
- For avatars, prefer relative url from API; prefix with AuthService.baseUrl on client.

## Backend

- Use modules/*/routes.js only; older src/routes/* files are deprecated.
- Add validation middleware for any new endpoints.
- Handle errors with the global error handler; return JSON { message }.

## Running locally

- Backend: cd ispoon-backend && npm i && npm start (requires DATABASE_URL, JWT_SECRET).
- App: cd smartspoon && flutter pub get && flutter run.

## Pull Requests

- Keep edits focused and small.
- Include a short description of the changes and testing steps.


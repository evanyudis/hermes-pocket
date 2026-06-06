# Development auth/session notes

This app is currently used as a single-developer development build.

## Current behavior
- Remember the backend URL between installs/builds.
- Keep the auth session available for convenience during development.
- Avoid re-entering URL/password on every reinstall.

## Important for public release
If this app is published publicly, re-check this behavior:
- do **not** rely on developer-only auth persistence assumptions
- require explicit user-entered backend URL
- require explicit login/password flow as appropriate
- do not auto-bypass/trust development TLS/cert settings

## Why this exists
This is only a development convenience so local iteration is faster. It should be reviewed before shipping to other users.

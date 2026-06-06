# Hermes Pocket

Native iOS Swift client for Hermes Web UI.

## Goal

Build an iPhone app that connects directly to an existing remote Hermes Web UI backend through a tunnel and password auth, with no local Hermes agent install required on device.

## MVP

- Password login to Hermes Web UI
- Persist auth session/cookies
- List sessions
- Create session
- Load session transcript
- Send message
- Stream assistant reply
- Support multiple conversations

## Reference backend

Backend contract reference analyzed:
- https://github.com/nesquena/hermes-webui

Note:
- Hermes Pocket does not require forking or modifying the backend for MVP
- app targets an existing deployed Hermes Web UI instance via URL + password

Project docs added in this repo:
- `docs/HERMES_WEBUI_API_CONTRACT.md`
- `docs/IMPLEMENTATION_PLAN.md`
- `docs/API_CLIENT_DESIGN.md`
- `docs/UI_UX_DIRECTION.md`

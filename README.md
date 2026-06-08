# Hermes Pocket

Native iOS Swift client for [Hermes Web UI](https://github.com/nesquena/hermes-webui).

Hermes Pocket connects to a remote Hermes Web UI backend over SSH tunnel with password auth. No Hermes agent install required on the iPhone — just a running backend somewhere you can reach.

---

## Table of contents

- [Quick overview](#quick-overview)
- [Prerequisites](#prerequisites)
- [Step 1 — Install Hermes Web UI on your server](#step-1--install-hermes-web-ui-on-your-server)
- [Step 2 — Set a password](#step-2--set-a-password)
- [Step 3 — Start the server](#step-3--start-the-server)
- [Step 4 — Create an SSH tunnel from your Mac](#step-4--create-an-ssh-tunnel-from-your-mac)
- [Step 5 — Open the Web UI and verify](#step-5--open-the-web-ui-and-verify)
- [Step 6 — Connect Hermes Pocket](#step-6--connect-hermes-pocket)
- [Architecture diagram](#architecture-diagram)
- [Useful commands reference](#useful-commands-reference)
- [Troubleshooting](#troubleshooting)
- [AI agent setup prompt](#ai-agent-setup-prompt)

---

## Quick overview

```
┌──────────────┐       SSH tunnel        ┌──────────────────────┐
│  Your Mac    │ ◄──────────────────────► │  Remote Server       │
│  localhost:  │   -L 8787:127.0.0.1:8787 │  hermes-webui:8787   │
│    8787      │                          │  hermes-agent        │
└──────┬───────┘                          └──────────────────────┘
       │
       │  URLSession (cookie auth)
       ▼
┌──────────────┐
│ Hermes Pocket│  iPhone app
│  (SwiftUI)   │
└──────────────┘
```

---

## Prerequisites

On your **remote server** (VPS, homelab machine, always-on Mac, etc.):

- Python 3.11 or later
- git
- An API key for at least one LLM provider (OpenAI, Anthropic, Google, etc.)

On your **local Mac** (where you run Xcode):

- SSH access to the server
- Xcode 15+ with Hermes Pocket cloned

---

## Step 1 — Install Hermes Web UI on your server

SSH into your server:

```bash
ssh user@your-server-ip
```

Clone and bootstrap:

```bash
git clone https://github.com/nesquena/hermes-webui.git ~/hermes-webui
cd ~/hermes-webui
python3 bootstrap.py
```

The bootstrap script will:

1. Detect or install Hermes Agent
2. Set up a Python virtual environment
3. Start the web server
4. Open a first-run onboarding wizard in your browser (or print the URL if headless)

Follow the onboarding wizard to configure your LLM provider and API key.

> **Headless server?** The wizard prints instructions. You can also configure
> the provider manually via the Hermes CLI:
>
> ```bash
> cd ~/hermes-webui
> source venv/bin/activate
> hermes model           # pick a provider
> hermes auth            # enter your API key
> ```

---

## Step 2 — Set a password

Password auth is off by default. Enable it before exposing the UI through a tunnel.

**Option A — during bootstrap** (recommended):

```bash
HERMES_WEBUI_PASSWORD=your-strong-password python3 bootstrap.py
```

**Option B — via environment variable when starting**:

```bash
export HERMES_WEBUI_PASSWORD=your-strong-password
```

**Option C — via the Settings panel** in the running Web UI:

Open Settings → System → set a password.

> Pick a strong password. The tunnel itself is encrypted by SSH, but the
> password protects the Web UI at the application level.

---

## Step 3 — Start the server

If you didn't already start it via bootstrap, use the daemon wrapper:

```bash
cd ~/hermes-webui

# Start in background
HERMES_WEBUI_PASSWORD=your-strong-password ./ctl.sh start

# Check it's alive
./ctl.sh status
```

Or run it in the foreground (useful for debugging):

```bash
cd ~/hermes-webui
HERMES_WEBUI_PASSWORD=your-strong-password ./start.sh
```

The server listens on `127.0.0.1:8787` by default — only accessible from the
server itself, which is exactly what we want (the SSH tunnel handles the rest).

Verify it's up:

```bash
curl -s http://127.0.0.1:8787/health
```

You should see a JSON response with `"ok": true` or similar.

---

## Step 4 — Create an SSH tunnel from your Mac

On your **local Mac** (not the server), open a terminal and run:

```bash
ssh -N -L 8787:127.0.0.1:8787 user@your-server-ip
```

This:

- `-N` — no remote command, just forwarding
- `-L 8787:127.0.0.1:8787` — binds local port 8787 to the server's port 8787

Leave this terminal open. The tunnel stays alive while the SSH session is active.

**Optional: keep it alive automatically** — add to your SSH config (`~/.ssh/config`):

```
Host your-server
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

---

## Step 5 — Open the Web UI and verify

Open your browser on your Mac:

```
http://localhost:8787
```

You should see the Hermes Web UI login page. Enter the password you set in Step 2.

Once logged in, you can:

- Start a new conversation
- Test that the agent responds (confirms provider is configured correctly)
- Browse sessions, workspace, settings — everything works through the tunnel

---

## Step 6 — Connect Hermes Pocket

1. Open Hermes Pocket on your iPhone
2. Enter the tunnel URL: `http://localhost:8787`

   > **Wait — the iPhone can't reach localhost on your Mac directly.**
   > You have two options:
   >
   > **Option A — Tailscale (recommended for iPhone access):**
   >
   > Install [Tailscale](https://tailscale.com/download) on both your server
   > and your iPhone. Then skip the SSH tunnel and point the server at all
   > interfaces:
   >
   > ```bash
   > # On the server:
   > HERMES_WEBUI_HOST=0.0.0.0 HERMES_WEBUI_PASSWORD=your-strong-password ./ctl.sh start
   > ```
   >
   > Find your server's Tailscale IP:
   > ```bash
   > tailscale ip -4
   > ```
   >
   > In Hermes Pocket, enter: `http://<tailscale-ip>:8787`
   >
   > Traffic is encrypted end-to-end by WireGuard. No port forwarding needed.
   >
   > **Option B — SSH tunnel to a Mac, then share via Tailscale/LAN:**
   >
   > If your Mac is always on, run the SSH tunnel on the Mac, then use
   > Tailscale or your LAN IP to reach the Mac's localhost:8787 from the iPhone.

3. Enter your password when prompted
4. You're in — sessions load, you can chat, create new conversations

---

## Architecture diagram

```
                    ┌─────────────────────────────────────────┐
                    │          Remote Server                  │
                    │                                         │
                    │   ┌──────────────┐   ┌──────────────┐  │
                    │   │ hermes-agent │◄──│ hermes-webui │  │
                    │   │  (Python)    │   │  :8787       │  │
                    │   └──────────────┘   └──────┬───────┘  │
                    │                             │          │
                    │                    127.0.0.1:8787       │
                    └─────────────────────────────┼──────────┘
                                                  │
                              ┌────────────────────┤
                              │                    │
                         SSH tunnel          Tailscale
                              │                    │
                    ┌─────────▼─────────┐  ┌──────▼──────────┐
                    │   Your Mac        │  │  iPhone          │
                    │   localhost:8787  │  │  tailscale:8787  │
                    │                   │  │                  │
                    │  Hermes Pocket    │  │  Hermes Pocket   │
                    │  (Xcode simulator)│  │  (on device)     │
                    └───────────────────┘  └─────────────────┘
```

---

## Useful commands reference

### Server management

```bash
cd ~/hermes-webui

# Start (background daemon)
HERMES_WEBUI_PASSWORD=your-strong-password ./ctl.sh start

# Check status
./ctl.sh status

# View logs
./ctl.sh logs --lines 50

# Restart
./ctl.sh restart

# Stop
./ctl.sh stop
```

### SSH tunnel

```bash
# Create tunnel (run on your Mac)
ssh -N -L 8787:127.0.0.1:8787 user@your-server-ip

# Test tunnel is working (on your Mac, in another terminal)
curl http://localhost:8787/health
```

### Tailscale setup

```bash
# On server — install tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Find server's tailscale IP
tailscale ip -4

# Start WebUI bound to all interfaces
cd ~/hermes-webui
HERMES_WEBUI_HOST=0.0.0.0 HERMES_WEBUI_PASSWORD=your-strong-password ./ctl.sh start
```

### Health check

```bash
curl -s http://127.0.0.1:8787/health | python3 -m json.tool
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `bootstrap.py` can't find Python | Install Python 3.11+: `brew install python@3.12` (macOS) or `apt install python3.12` (Ubuntu) |
| Server starts but chat doesn't work | Run `hermes model` and `hermes auth` in the venv to configure your provider |
| SSH tunnel connects but browser shows nothing | Make sure the tunnel command is running and the server is up (`curl localhost:8787/health`) |
| iPhone can't reach the server | Use Tailscale instead of SSH tunnel — see Step 6 Option A |
| Password rejected on login | Check you're using the right password; reset via `HERMES_WEBUI_PASSWORD=new ./ctl.sh restart` |
| Tunnel drops frequently | Add `ServerAliveInterval 60` to `~/.ssh/config` for your server |
| `429 Too many attempts` | Wait 60 seconds, the rate limiter resets automatically |
| Port 8787 already in use | Change port: `HERMES_WEBUI_PORT=8788 ./ctl.sh start` (remember to update the tunnel command too) |

---

## AI agent setup prompt

If you're an AI agent (Claude, GPT, Codex, etc.) and someone sent you this
repo link, copy and paste the prompt below to set up the backend. This is
everything you need to get Hermes Web UI running and accessible.

````markdown
## Master setup prompt for Hermes Web UI (backend for Hermes Pocket)

You are helping set up the backend for Hermes Pocket, an iOS Swift client
that connects to Hermes Web UI. Your job is to get Hermes Web UI running on
this machine, set a password, and make it accessible via SSH tunnel or
Tailscale.

### What you need to do

1. **Install Hermes Web UI** (if not already installed):

   ```bash
   # Check if already installed
   if [ -d ~/hermes-webui ]; then
     echo "Hermes WebUI already installed at ~/hermes-webui"
   else
     git clone https://github.com/nesquena/hermes-webui.git ~/hermes-webui
   fi

   cd ~/hermes-webui

   # Run bootstrap (installs hermes-agent if missing, sets up venv, starts server)
   python3 bootstrap.py
   ```

2. **Configure LLM provider** (if not already done):

   ```bash
   cd ~/hermes-webui
   source venv/bin/activate
   hermes model     # pick a provider (OpenAI, Anthropic, Google, etc.)
   hermes auth      # enter your API key
   ```

3. **Set a password and start the server**:

   ```bash
   cd ~/hermes-webui
   HERMES_WEBUI_PASSWORD=your-strong-password ./ctl.sh start
   ./ctl.sh status   # confirm it's running
   curl -s http://127.0.0.1:8787/health   # confirm health check passes
   ```

4. **Tell the user how to connect**:

   The server is running on `127.0.0.1:8787` (localhost only).

   **For Mac access (SSH tunnel):**
   The user should run this on their Mac:
   ```
   ssh -N -L 8787:127.0.0.1:8787 user@this-server-ip
   ```
   Then open `http://localhost:8787` in their browser.

   **For iPhone access (Tailscale — recommended):**
   ```bash
   # Install Tailscale on the server
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up

   # Restart WebUI bound to all interfaces
   HERMES_WEBUI_HOST=0.0.0.0 HERMES_WEBUI_PASSWORD=your-strong-password ./ctl.sh restart

   # Show the Tailscale IP
   tailscale ip -4
   ```
   The user installs Tailscale on their iPhone and opens
   `http://<tailscale-ip>:8787`.

5. **Do NOT**:
   - Print API keys, passwords, or .env contents
   - Delete or overwrite `~/.hermes` without explicit approval
   - Expose port 8787 on a public interface without password auth
   - Run destructive commands without asking first

### Architecture context

- Hermes Web UI is a Python + vanilla JS web app (no build step)
- It wraps Hermes Agent, which handles LLM inference, tool use, and memory
- Auth is cookie-based (`hermes_session`), set by `POST /api/auth/login`
- Chat streams via SSE: `POST /api/chat/start` → `GET /api/chat/stream`
- The iOS app (Hermes Pocket) consumes these endpoints natively — no webview
- The server binds to `127.0.0.1:8787` by default (SSH tunnel or Tailscale needed for remote access)
- Password is set via `HERMES_WEBUI_PASSWORD` env var or the Settings panel

### Health check command

```bash
curl -s http://127.0.0.1:8787/health | python3 -m json.tool
```

### Useful management commands

```bash
cd ~/hermes-webui
./ctl.sh start              # start daemon
./ctl.sh status             # check PID, uptime, port
./ctl.sh logs --lines 50    # tail logs
./ctl.sh restart            # restart
./ctl.sh stop               # stop
```

### If the user asks about the iOS app

Hermes Pocket is a native SwiftUI app. Key files:
- `HermesPocket/` — app source
- `docs/HERMES_WEBUI_API_CONTRACT.md` — full API contract the app consumes
- `docs/IMPLEMENTATION_PLAN.md` — architecture and milestone plan
- `docs/API_CLIENT_DESIGN.md` — networking layer design
- `docs/UI_UX_DIRECTION.md` — screen designs and navigation

The app connects to the Web UI URL, authenticates with password, and uses
cookie-based sessions. It does NOT fork or modify the backend.
````

---

## Project docs

| Document | What it covers |
|---|---|
| `docs/HERMES_WEBUI_API_CONTRACT.md` | Full API contract the iOS app consumes |
| `docs/IMPLEMENTATION_PLAN.md` | Architecture, milestones, and data model |
| `docs/API_CLIENT_DESIGN.md` | URLSession networking layer design |
| `docs/UI_UX_DIRECTION.md` | Screen flow and visual direction |
| `docs/DEV_AUTH_CONTEXT.md` | Auth implementation details |

---

## License

MIT

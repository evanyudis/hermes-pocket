# Hermes Pocket UI / UX Direction

References:
- Apple: SwiftUI apps
- Apple: Adopting Liquid Glass
- Apple: UIKit and AppKit apps

## Decision

Hermes Pocket uses **SwiftUI-first** UI architecture.

Meaning:
- start with pure SwiftUI app structure
- use standard Apple navigation, forms, lists, toolbars, sheets, and controls
- avoid custom visual system early
- let latest iOS SDK provide default platform styling, including Liquid Glass updates where applicable
- customize only after core chat flows feel correct

This matches Apple guidance:
- SwiftUI is best choice for new apps
- standard system components automatically adopt latest platform appearance
- custom backgrounds/effects in navigation and control layers should be reduced

---

## Product principles

1. **Native first**
   - should feel like iPhone app, not wrapped web UI
   - prefer platform conventions over recreating web layout

2. **Content first**
   - chat content is primary
   - controls support content, not compete with it

3. **System first**
   - use standard SwiftUI containers and controls before custom ones
   - inherit Liquid Glass and platform updates automatically

4. **State clarity**
   - connection, auth, loading, streaming, reconnect, and error states must be obvious

5. **One-hand usability**
   - optimize for iPhone portrait use
   - keep primary actions reachable and predictable

---

## Apple guidance applied

## From SwiftUI apps

Use:
- `@main App`
- `WindowGroup`
- `NavigationStack`
- declarative view composition
- data-driven UI updates
- state wrappers and environment-based app state

Implication for Hermes Pocket:
- app state drives route and UI
- session/chat/auth state updates should redraw UI, not manually patch views
- chat flow should be modeled as observable state transitions

## From Adopting Liquid Glass

Use:
- standard bars
- standard sheets
- standard toolbars
- standard controls
- minimal custom control backgrounds

Avoid early:
- custom nav bar backgrounds
- fake glass effects everywhere
- dense layered chrome around composer and top bars

Implication for Hermes Pocket:
- keep navigation bars, sheets, and toolbars mostly system-default
- do not over-theme session list and composer initially
- if custom glass is used later, apply only to high-value surfaces

## From UIKit and AppKit apps

Takeaway is mostly boundary-setting:
- Hermes Pocket should not fall back to UIKit-first architecture unless SwiftUI hits a real limitation
- UIKit interop stays exception-only

Allowed later if needed:
- keyboard/input edge cases
- advanced text rendering
- specialized share/export hooks
- low-level platform integrations

Default remains SwiftUI.

---

## App information architecture

## Primary screens

1. Connection
2. Login
3. Sessions
4. Chat
5. Settings

## Navigation model

Recommended:
- `NavigationStack` root
- simple route-driven transitions
- no tab bar in MVP

Reason:
- app is task-focused
- tab bar adds chrome without helping first-use flow

---

## Screen-by-screen direction

## 1. Connection screen

Purpose:
- enter backend URL
- establish starting point with minimal friction

Use:
- `Form`
- URL `TextField`
- one primary `Continue` button

UX rules:
- keep page sparse
- validate URL lightly
- no advanced options on first pass

## 2. Login screen

Purpose:
- password entry
- clear auth failure handling

Use:
- `Form`
- `SecureField`
- primary sign-in button
- inline error text

UX rules:
- show connected host clearly
- no unnecessary branding clutter
- support paste-friendly password entry

## 3. Session list screen

Purpose:
- conversation launcher
- new chat entry point
- recovery point after reconnect

Use:
- `List`
- native navigation title
- top-right compose button
- optional `.searchable` later

UX rules:
- title first
- timestamp/meta secondary
- running session state visible but subtle
- swipe actions later, not first

## 4. Chat screen

Purpose:
- read transcript
- send messages
- watch streaming reply

Use:
- scrollable message list
- bottom composer
- standard toolbar/back affordance
- standard button styling first

UX rules:
- transcript must dominate screen
- streaming state should be visible without noisy animation
- composer should stay simple and stable
- stop/send should be one obvious primary action slot

## 5. Settings screen

Purpose:
- server info
- logout
- later app preferences

Use:
- `Form`
- grouped sections

UX rules:
- keep MVP settings tiny
- avoid dumping backend internals here

---

## Component choices

## Use by default

- `NavigationStack`
- `List`
- `Form`
- `Section`
- `ToolbarItem`
- `Button`
- `TextField`
- `SecureField`
- `ProgressView`
- `ContentUnavailableView`
- `Alert`
- `ConfirmationDialog`
- `Sheet`

## Avoid for now

- custom nav bars
- custom segmented navigation shell
- bespoke floating glass panels
- heavy gradients/background textures
- fully custom text editor styling before behavior is stable

---

## Visual style direction

Phase 1:
- mostly system default
- rely on iOS typography, spacing, grouped forms, toolbar appearance
- almost no branding beyond app name

Phase 2:
- refine message bubbles
- refine session row density
- refine streaming indicators
- refine iconography and accent usage

Phase 3:
- selective material/glass polish only where it improves hierarchy

---

## Chat-specific UX rules

1. User should always know:
   - connected or not
   - logged in or not
   - streaming or idle
   - failed or retryable

2. Streaming should feel calm:
   - no aggressive token animation
   - subtle incremental updates
   - stable scroll behavior

3. Multi-session should feel lightweight:
   - switching sessions must be fast
   - active stream recovery should feel automatic

4. Errors should be local and clear:
   - auth errors near login
   - connection errors near connection flow
   - send/stream errors inside chat context

---

## Customization backlog after MVP

Later candidates:
- custom message bubble system
- markdown-rich transcript rendering polish
- attachment chips
- improved session search UX
- branded icon/accent system
- selective Liquid Glass treatment for composer or overlays

Not now:
- custom design system package
- bespoke navigation chrome
- over-styled backgrounds

---

## Practical build order

1. make all screens work with pure system SwiftUI
2. wire real backend states
3. test on iPhone-sized simulator
4. test dynamic type, dark mode, reduced transparency, reduced motion
5. only then begin visual tweaking

---

## Bottom line

Hermes Pocket should begin as a **clean native SwiftUI app** that naturally inherits Apple’s current platform design language.

Default system UI first.
Behavior correctness second.
Selective polish third.

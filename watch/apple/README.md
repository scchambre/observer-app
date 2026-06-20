# Ultimate Observer — Apple Watch app

A standalone watchOS companion to the web app:

- **Score** — `＋` button per team; tapping one starts the next point's clock.
- **Between-points STOPWATCH** — counts **up** (elapsed since the goal) with your **80s pull / 60s readiness** deadline shown beneath, derived from which end the pull comes from. Haptic buzzes at **20s** and **10s** before your deadline, and a strong buzz **over**. End-aware, including the **2nd-half reversal**.
- **Halftime COUNTDOWN** — `Half` button runs a 5-min countdown (buzz at 1-min and time-up) and marks 2nd half.
- **Timeout** — `Timeout` button runs a 70s countdown.
- **Gender ratio** — current ABBA ratio with **1st / 2nd of the pair** (e.g. `4M 2nd`).

Plus **Start pt**, **Undo**, and a **Setup** screen (team names, end labels, who pulls first + from which end, point-1 ratio, your end, "role looks wrong" flip).

It's a **standalone** watch app — no phone pairing or connectivity needed on the field. Each observer runs their own. State is saved on the watch and survives relaunch.

---

## What you need first

You currently have only the **Command Line Tools**, not full Xcode. To build a watchOS app you need full Xcode:

0. Install **Xcode** from the Mac App Store (free, ~7+ GB). Open it once and let it install additional components. If prompted, install the **watchOS platform support** (Xcode → Settings → Components).
   - Add your Apple ID under **Xcode → Settings → Accounts** (a free Apple ID is fine for installing to your own watch).

You can verify Xcode is active afterward with: `sudo xcode-select -s /Applications/Xcode.app` then `xcodebuild -version`.

---

## Build it (≈10 minutes)

1. **New project:** Xcode → **File → New → Project** → top tab **watchOS** → **App** → **Next**.
2. **Options:**
   - Product Name: `ObserverWatch`
   - Team: your Apple ID
   - Organization Identifier: anything, e.g. `com.yourname`
   - Interface: **SwiftUI**, Language: **Swift**
   - Leave the extra checkboxes (Tests, Notification Scene, Complication) **off**.
   - **Next** → choose a folder → **Create**. This makes a *watch-only* app (no iOS app needed).
3. **Drop in the code:** the new project has two Swift files in the navigator — `ObserverWatchApp.swift` and `ContentView.swift`. Open each and **replace its entire contents** with the matching file from this folder (`watch/apple/`). Don't add or remove files; just paste over the two that Xcode generated.
4. **Deployment target:** select the project → the app target → **General → Minimum Deployments** → watchOS **10.0** or later (the default is usually fine).
5. **Run it:**
   - *Easiest first:* pick a **watchOS Simulator** as the run destination and press **⌘R** — no signing or device needed. You'll see the app and can click through it.
   - *On your real watch:* set the run destination to your Apple Watch (it must be paired to your iPhone and on the same Wi-Fi as the Mac). In the target's **Signing & Capabilities**, pick your Team. Press **⌘R**. The first install may ask you to trust the developer certificate on the watch/iPhone (**Settings → General → VPN & Device Management**).

### Free Apple ID caveat
With a free Apple ID, the app is signed for **7 days** — after that it won't launch until you re-run it from Xcode (which re-signs it). A paid Apple Developer account ($99/yr) removes the expiry and enables TestFlight if your co-observer wants it too.

---

## Using it

- **Setup first** (gear icon, bottom-right): set team names, name the two ends, pick **You're at** (your end), **Pulls first** (the team starting on D) and **Pull from** (their end), and the **Point 1 ratio**. This is the same info the web app needs to know whether your clock is 80s or 60s each point.
- Tap a team's **`＋`** when they score → the next clock starts automatically with the right role.
- Tap **Pull released** when the pull goes off → clock freezes, marked on-time/late.
- If the displayed role ever looks wrong vs. the field, Setup → **Role looks wrong — flip**.

## Known limitation (foreground timing)
The 0.25s timer and its haptics run while the app is **in the foreground** (wrist raised / screen on). If the watch sleeps mid-window, the timer pauses; raising your wrist resumes it and the displayed elapsed time stays correct (it's computed from the stored start time), but a haptic that would have fired while the screen was off may be missed. To minimise this:
- Enable **Always-On Display** (Watch app on iPhone → Display & Brightness).
- Set the watch to stay on this app: **Settings → General → Return to Clock →** scroll to *ObserverWatch* → **Custom → Return to App: While Active** (wording varies by watchOS).

A future version can use an extended-runtime session for rock-solid background haptics if you find the foreground behaviour limiting — tell me and I'll add it.

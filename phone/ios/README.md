# iPhone companion app — Phase 1 (WebView)

This is the **iOS app** half of the `ObserverWatch` project (the "Watch App with New
Companion iOS App" you created). Phase 1 just shows the full web app on the phone in a
`WKWebView`, so you get every feature (sheet, log, ECG schedule) on the big screen.

> Phase 2 will bundle the web app for **offline** use and add the **watch ⇄ phone sync**.
> For now it loads the live site, so the phone needs internet for this first test.

## Do this in Xcode

You have two groups in the Project navigator:
- **ObserverWatch** — the **iOS app** (this one)
- **ObserverWatch Watch App** — the watch app (leave it as Xcode's default for now; we do
  the watch in Phase 2)

Steps:
1. In the **ObserverWatch** (iOS) group, open its `ContentView.swift` and **replace the
   entire contents** with [`ContentView.swift`](./ContentView.swift) from this folder.
2. Leave the iOS app's app-entry file (`ObserverWatchApp.swift`) **as generated** — it
   already does `WindowGroup { ContentView() }`, which is all we need.
3. At the top of Xcode, pick the **ObserverWatch** scheme (the iOS app, *not* the Watch App)
   and choose an **iPhone Simulator** or your iPhone.
4. Press **▶ Run**.

You should see the East Coast Games 2026 observer app fill the screen. Tap through Timer /
Setup / Log / Sheet — it's the real web app.

## Tweaks
- **Which page opens:** change `START_URL` at the top of `ContentView.swift` (generic app vs.
  the `/ECG-2026/` page).
- If you see a blank white screen, it's almost always (a) no internet on the device/sim, or
  (b) App Transport Security — but the site is HTTPS so ATS allows it by default. Send me any
  Xcode console output and I'll sort it.

## What's next (Phase 2)
- Bundle the web app inside the app so it works with no signal.
- Add a JS↔native bridge + WatchConnectivity so the watch and phone share one game state
  (score/time edited on either device, synced both ways).

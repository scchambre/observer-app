import SwiftUI
import WebKit

// =====================================================================
//  Ultimate Observer — iPhone companion (Phase 1)
//  Shows the full web app in a WKWebView. This is the companion iOS app
//  of the watch project; in Phase 2 it gains the watch<->phone sync
//  bridge and an offline-bundled copy of the web app.
// =====================================================================

// Which page to open. The generic app:
//   https://scchambre.github.io/observer-app/
// or the East Coast Games 2026 page (pre-loaded schedule):
//   https://scchambre.github.io/observer-app/ECG-2026/
private let START_URL = URL(string: "https://scchambre.github.io/observer-app/ECG-2026/")!

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // Persistent store so the web app's localStorage (game state) survives relaunch.
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.bounces = false
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        WebView(url: START_URL)
            .ignoresSafeArea(edges: .bottom)   // let the web app's tab bar reach the bottom
    }
}

#Preview {
    ContentView()
}

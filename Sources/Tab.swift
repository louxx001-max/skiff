import SwiftUI
import WebKit

final class Tab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate {
    let id = UUID()
    let webView: WKWebView
    @Published var title = ""
    @Published var url: URL?
    @Published var progress = 0.0
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var snapshot: UIImage?
    private var observers: [NSKeyValueObservation] = []

    init(url: URL? = nil) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // Without the Safari token some sites serve a stripped-down page.
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        observers = [
            webView.observe(\.title) { [weak self] wv, _ in self?.title = wv.title ?? "" },
            webView.observe(\.url) { [weak self] wv, _ in if let u = wv.url { self?.url = u } },
            webView.observe(\.estimatedProgress) { [weak self] wv, _ in self?.progress = wv.estimatedProgress },
            webView.observe(\.isLoading) { [weak self] wv, _ in self?.isLoading = wv.isLoading },
            webView.observe(\.canGoBack) { [weak self] wv, _ in self?.canGoBack = wv.canGoBack },
            webView.observe(\.canGoForward) { [weak self] wv, _ in self?.canGoForward = wv.canGoForward },
        ]
        if let url { load(url) }
    }

    func load(_ url: URL) {
        self.url = url
        webView.load(URLRequest(url: url))
    }

    func captureSnapshot() {
        guard url != nil else { snapshot = nil; return }
        webView.takeSnapshot(with: nil) { [weak self] image, _ in self?.snapshot = image }
    }

    // target="_blank" links open in the same tab.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil { webView.load(action.request) }
        return nil
    }
}

final class TabStore: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var currentID = UUID()
    private let key = "openTabs"

    init() {
        let saved = (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(URL.init(string:))
        saved.forEach { tabs.append(Tab(url: $0)) }
        if tabs.isEmpty { tabs.append(Tab()) }
        currentID = tabs.last!.id
    }

    var current: Tab { tabs.first { $0.id == currentID } ?? tabs[0] }

    func newTab(_ url: URL? = nil) {
        let tab = Tab(url: url)
        tabs.append(tab)
        currentID = tab.id
    }

    func close(_ tab: Tab) {
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty { newTab() } else if currentID == tab.id { currentID = tabs.last!.id }
    }

    func save() {
        UserDefaults.standard.set(tabs.compactMap { $0.url?.absoluteString }, forKey: key)
    }
}

extension URL {
    static func from(input: String) -> URL {
        if input.contains("://"), let u = URL(string: input) { return u }
        if !input.contains(" "), input.contains("."), let u = URL(string: "https://" + input) { return u }
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: input)]
        return c.url!
    }
}

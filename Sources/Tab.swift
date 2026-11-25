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
    /// The site's <meta name="theme-color">, used to tint the status-bar strip like Safari.
    @Published var themeColor: UIColor?
    /// Last pop-up or redirect the blocker stopped; shown as a banner the user can override.
    @Published var blocked: URL?
    private var pending: URL?
    private var rulesReady = false
    private var shown = false
    private var bypassNext = false
    private var observers: [NSKeyValueObservation] = []

    init(url: URL? = nil, ruleList: WKContentRuleList? = nil, deferLoad: Bool = false) {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        // Without the Safari token some sites serve a stripped-down page.
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        if let ruleList { config.userContentController.add(ruleList) }
        rulesReady = ruleList != nil
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
            webView.observe(\.themeColor) { [weak self] wv, _ in self?.themeColor = wv.themeColor },
        ]
        if let url {
            if deferLoad { self.url = url; pending = url } else { load(url) }
        }
    }

    /// Adds the ad-block rules once they're compiled.
    func attach(_ ruleList: WKContentRuleList?) {
        if let ruleList { webView.configuration.userContentController.add(ruleList) }
        rulesReady = true
        loadPendingIfReady()
    }

    /// Called when the tab is on screen; restored tabs only load once they're looked at.
    func show() {
        shown = true
        loadPendingIfReady()
    }

    private func loadPendingIfReady() {
        if shown, rulesReady, let p = pending { load(p) }
    }

    func load(_ url: URL) {
        pending = nil
        bypassNext = true
        self.url = url
        webView.load(URLRequest(url: url))
    }

    func openBlocked() {
        guard let target = blocked else { return }
        blocked = nil
        if ["http", "https"].contains(target.scheme) { load(target) } else { UIApplication.shared.open(target) }
    }

    func captureSnapshot() {
        guard url != nil else { snapshot = nil; return }
        webView.takeSnapshot(with: nil) { [weak self] image, _ in self?.snapshot = image }
    }

    // MARK: Pop-up and redirect blocking

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let target = action.request.url, action.targetFrame?.isMainFrame ?? true else {
            return decisionHandler(.allow)
        }
        if bypassNext {
            bypassNext = false
            return decisionHandler(.allow)
        }
        let web = ["http", "https", "about", "blob", "data"].contains(target.scheme ?? "")
        if !web {
            // App-store / intent links: follow only when the user tapped them.
            if action.navigationType == .linkActivated { UIApplication.shared.open(target) } else { blocked = target }
            return decisionHandler(.cancel)
        }
        // A script sending a finished page to another site without a link tap is the
        // classic ad hijack. Server redirects and redirects during page load still pass.
        if action.navigationType == .other, !webView.isLoading,
           let current = webView.url, Self.site(current) != Self.site(target) {
            blocked = target
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    // target="_blank" links open in the same tab; script-opened windows are blocked.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.navigationType == .linkActivated {
            load(action.request.url ?? URL(string: "about:blank")!)
        } else {
            blocked = action.request.url
        }
        return nil
    }

    /// Rough registrable domain: news.google.com → google.com, www.bbc.co.uk → bbc.co.uk.
    static func site(_ url: URL) -> String {
        let parts = (url.host ?? "").split(separator: ".")
        let countryPair = parts.count >= 3 && parts[parts.count - 2].count <= 3 && parts.last!.count == 2
        return parts.suffix(countryPair ? 3 : 2).joined(separator: ".")
    }
}

enum AdBlock {
    /// Compiles Sources/blocklist.json once per build; later launches reuse WebKit's cached copy.
    static func load(_ done: @escaping (WKContentRuleList?) -> Void) {
        guard let store = WKContentRuleListStore.default() else { return done(nil) }
        let key = "ads-" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0")
        store.lookUpContentRuleList(forIdentifier: key) { cached, _ in
            if let cached { return done(cached) }
            guard let file = Bundle.main.url(forResource: "blocklist", withExtension: "json"),
                  let json = try? String(contentsOf: file) else { return done(nil) }
            store.compileContentRuleList(forIdentifier: key, encodedContentRuleList: json) { list, error in
                if let error { print("blocklist:", error) }
                done(list)
            }
        }
    }
}

final class TabStore: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var currentID = UUID()
    private var ruleList: WKContentRuleList?
    private var rulesReady = false
    private let key = "openTabs"

    init() {
        let saved = (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(URL.init(string:))
        tabs = saved.map { Tab(url: $0, deferLoad: true) }
        if tabs.isEmpty { tabs.append(Tab()) }
        currentID = tabs.last!.id
        AdBlock.load { [weak self] list in
            guard let self else { return }
            self.ruleList = list
            self.rulesReady = true
            self.tabs.forEach { $0.attach(list) }
        }
    }

    var current: Tab { tabs.first { $0.id == currentID } ?? tabs[0] }

    func newTab(_ url: URL? = nil) {
        // Tabs made before the rules finish compiling get them in AdBlock.load's callback.
        let tab = Tab(url: url, ruleList: ruleList, deferLoad: !rulesReady)
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

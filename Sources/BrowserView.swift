import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BrowserView: View {
    @ObservedObject var tab: Tab
    @EnvironmentObject private var store: TabStore
    @State private var address = ""
    @State private var showTabs = false
    @FocusState private var editing: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if tab.url == nil { StartPage { tab.load($0) } }
                WebView(webView: tab.webView)
                    .opacity(tab.url == nil ? 0 : 1)
                    .ignoresSafeArea(.container, edges: .top)
                if tab.isLoading {
                    ProgressView(value: tab.progress).progressViewStyle(.linear)
                }
            }
            .overlay(alignment: .bottom) { blockedBanner }
            bottomBar
        }
        .onAppear {
            address = tab.url?.host ?? ""
            if tab.url == nil { editing = true }
        }
        .onChange(of: editing) { address = $0 ? (tab.url?.absoluteString ?? "") : (tab.url?.host ?? "") }
        .onChange(of: tab.url) { if !editing { address = $0?.host ?? "" } }
        .sheet(isPresented: $showTabs) { TabsView() }
    }

    @ViewBuilder private var blockedBanner: some View {
        if let target = tab.blocked {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
                Text("Blocked \(target.host ?? "pop-up")")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button("Open") { tab.openBlocked() }.font(.subheadline.bold())
                Button { tab.blocked = nil } label: { Image(systemName: "xmark") }
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: target) {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if tab.blocked == target { withAnimation { tab.blocked = nil } }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or enter address", text: $address)
                    .keyboardType(.webSearch)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .multilineTextAlignment(editing ? .leading : .center)
                    .focused($editing)
                    .onSubmit(go)
                if editing, !address.isEmpty {
                    Button { address = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(.secondary)
                } else if !editing, tab.url != nil {
                    Button {
                        if tab.isLoading { tab.webView.stopLoading() } else { tab.webView.reload() }
                    } label: { Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise") }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            if !editing {
                HStack {
                    Button { tab.webView.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!tab.canGoBack)
                    Spacer()
                    Button { tab.webView.goForward() } label: { Image(systemName: "chevron.right") }
                        .disabled(!tab.canGoForward)
                    Spacer()
                    if let url = tab.url {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    } else {
                        Image(systemName: "square.and.arrow.up").foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button { store.newTab() } label: { Image(systemName: "plus") }
                    Spacer()
                    Button {
                        store.tabs.forEach { $0.captureSnapshot() }
                        showTabs = true
                    } label: { Image(systemName: "square.on.square") }
                }
                .font(.title3)
                .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.bar)
    }

    private func go() {
        let text = address.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        tab.load(.from(input: text))
        editing = false
    }
}

struct StartPage: View {
    let open: (URL) -> Void
    private let sites = [
        ("Google", "https://www.google.com"), ("YouTube", "https://m.youtube.com"),
        ("Reddit", "https://www.reddit.com"), ("Wikipedia", "https://en.m.wikipedia.org"),
        ("ESPN", "https://www.espn.com"), ("GitHub", "https://github.com"),
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Skiff").font(.system(size: 44, weight: .bold, design: .rounded))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(sites, id: \.0) { name, link in
                    Button { open(URL(string: link)!) } label: {
                        VStack(spacing: 6) {
                            Text(String(name.prefix(1)))
                                .font(.title2.bold())
                                .frame(width: 56, height: 56)
                                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                            Text(name).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

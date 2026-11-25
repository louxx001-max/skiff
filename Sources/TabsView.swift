import SwiftUI

struct TabsView: View {
    @EnvironmentObject private var store: TabStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(store.tabs) { tab in
                        TabCard(tab: tab, selected: tab.id == store.currentID) {
                            store.currentID = tab.id
                            dismiss()
                        } close: {
                            store.close(tab)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("\(store.tabs.count) Tab\(store.tabs.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.newTab(); dismiss() } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
    }
}

private struct TabCard: View {
    @ObservedObject var tab: Tab
    let selected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let image = tab.snapshot {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Color(.secondarySystemBackground)
                        }
                    }
                    .frame(height: 200, alignment: .top)
                    .clipped()

                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .padding(7)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.accentColor : .clear, lineWidth: 3))

                Text(tab.title.isEmpty ? (tab.url?.host ?? "New Tab") : tab.title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

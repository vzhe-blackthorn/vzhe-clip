import SwiftUI

struct HistoryView: View {
    @Bindable var model: HistoryViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($searchFocused)
            }
            .padding(10)

            Divider()

            if model.showAccessibilityBanner {
                accessibilityBanner
            }

            if model.items.isEmpty {
                Spacer()
                Text(model.query.isEmpty ? "Nothing copied yet" : "No matches")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                cardList
            }
        }
        .frame(width: PanelController.panelSize.width, height: PanelController.panelSize.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { searchFocused = true }
        .onChange(of: model.focusRequest) { searchFocused = true }
    }

    private var cardList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { position, item in
                        ClipCardView(
                            item: item,
                            isSelected: item.id == model.selectedID,
                            thumbnail: item.kind == .image ? model.thumbnail(for: item) : nil,
                            appIcon: model.appIcon(for: item),
                            position: position
                        )
                        .id(item.id)
                        .onTapGesture { model.paste(item) }
                        .contextMenu {
                            Button("Paste") { model.paste(item) }
                            Button(item.isPinned ? "Unpin" : "Pin") { model.togglePin(item) }
                            Divider()
                            Button("Delete", role: .destructive) { model.delete(item) }
                        }
                    }
                }
                .padding(8)
            }
            .onChange(of: model.selectedID) { _, id in
                guard let id else { return }
                proxy.scrollTo(id)
            }
        }
    }

    private var accessibilityBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text("Enable Accessibility to auto-paste")
                .font(.system(size: 12))
            Spacer()
            Button("Open Settings") { model.openAccessibilitySettings() }
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.12))
    }
}

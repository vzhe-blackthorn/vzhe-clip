import SwiftUI

struct ClipCardView: View {
    let item: ClipItem
    let isSelected: Bool
    let thumbnail: NSImage?
    let appIcon: NSImage?
    /// 0-based position; positions 0...8 show their ⌘1…⌘9 shortcut.
    let position: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
            footer
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(Self.preview(of: item.text ?? ""))
                .font(.system(size: 13))
                .lineLimit(3)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Label("Image", systemImage: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if item.isPinned {
                Image(systemName: "pin.fill").foregroundStyle(.orange)
            }
            if let appIcon {
                Image(nsImage: appIcon).resizable().frame(width: 14, height: 14)
            }
            if item.kind == .image, let width = item.imageWidth, let height = item.imageHeight {
                Text("\(width)×\(height)")
            }
            Text(Self.relativeTime(item.lastUsedAt))
            Spacer()
            if position < 9 {
                Text("⌘\(position + 1)")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    static func preview(of text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
    }

    static func relativeTime(_ date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

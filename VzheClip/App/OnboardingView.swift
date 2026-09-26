import SwiftUI

struct OnboardingView: View {
    let onGrant: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("VzheClip is running", systemImage: "doc.on.clipboard")
                .font(.title2.bold())
            Text("Press **⌥V** anywhere to open your clipboard history. Pick an entry with ↑/↓ and Enter, or ⌘1–⌘9.")
            Text("To paste straight into the app you're using, VzheClip needs **Accessibility** access. Without it, entries are only copied to the clipboard.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Grant Accessibility…", action: onGrant)
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button("Done", action: onDone)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

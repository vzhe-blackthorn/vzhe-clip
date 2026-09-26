import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section("History") {
                Stepper(
                    "Keep \(model.historyLimit) items",
                    value: Binding(get: { model.historyLimit }, set: { model.setHistoryLimit($0) }),
                    in: HistoryStore.limitRange
                )
                Text("Pinned items don't count toward this limit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear History…", role: .destructive) { model.isConfirmingClear = true }
            }

            Section("Shortcut") {
                KeyboardShortcuts.Recorder("Open history:", name: .toggleHistory)
            }

            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            }

            Section("Never record copies from") {
                ForEach(model.denyList, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            model.removeDenyEntry(bundleID)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                HStack {
                    // In a grouped Form the title becomes a row label and squeezes the field
                    // to zero width, so hide the label and show the hint as a prompt instead.
                    TextField("Bundle ID", text: $model.newDenyEntry, prompt: Text("Bundle ID, e.g. com.example.app"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onSubmit { model.addDenyEntry() }
                    Button("Add") { model.addDenyEntry() }
                        .disabled(model.newDenyEntry.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("Clear all unpinned items?", isPresented: $model.isConfirmingClear) {
            Button("Clear History", role: .destructive) { model.clearHistory() }
        } message: {
            Text("Pinned items are kept.")
        }
    }
}

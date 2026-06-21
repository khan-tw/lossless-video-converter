import AppKit
import SwiftUI

@main
struct FrameKeepApp: App {
    @State private var store = FrameKeepStore()

    init() {
        UserDefaults.standard.register(defaults: [
            "framekeep.autoRevealOnFinish": true
        ])
    }

    var body: some Scene {
        WindowGroup("FrameKeep", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 700)
        }
        .defaultSize(width: 1180, height: 820)
        .commands {
            FrameKeepCommands(store: store)
        }

        Settings {
            SettingsView()
        }
    }
}

struct FrameKeepCommands: Commands {
    @Bindable var store: FrameKeepStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add MOV Files…") {
                store.importFiles()
            }
            .keyboardShortcut("o")

            Button("Choose Output Folder…") {
                store.selectOutputFolder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandMenu("Convert") {
            Button(store.isConverting ? "Converting…" : "Start Conversion") {
                store.startConversion()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!store.canStartConversion)

            Button("Cancel Conversion") {
                store.cancelConversion()
            }
            .keyboardShortcut(".")
            .disabled(!store.isConverting)

            Divider()

            Button("Reveal Latest Output") {
                store.revealLatestOutput()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(store.latestOutputURL == nil)
        }
    }
}

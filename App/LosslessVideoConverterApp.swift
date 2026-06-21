import AppKit
import SwiftUI

@main
struct LosslessVideoConverterApp: App {
    @State private var store = LosslessVideoConverterStore()

    init() {
        UserDefaults.standard.register(defaults: [
            "losslessvideoconverter.autoRevealOnFinish": true
        ])
    }

    var body: some Scene {
        WindowGroup("Lossless Video Converter", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 700)
        }
        .defaultSize(width: 1180, height: 820)
        .commands {
            LosslessVideoConverterCommands(store: store)
        }

        Settings {
            SettingsView()
        }
    }
}

struct LosslessVideoConverterCommands: Commands {
    @Bindable var store: LosslessVideoConverterStore

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

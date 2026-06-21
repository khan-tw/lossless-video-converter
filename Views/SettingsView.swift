import SwiftUI

struct SettingsView: View {
    @AppStorage("framekeep.autoRevealOnFinish") private var autoRevealOnFinish = true

    var body: some View {
        TabView {
            Form {
                Toggle("Reveal latest output in Finder when conversion finishes", isOn: $autoRevealOnFinish)
                Text("FrameKeep follows standard macOS file pickers and keeps all processing local.")
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .padding()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 480, height: 220)
    }
}

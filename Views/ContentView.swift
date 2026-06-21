import SwiftUI

struct ContentView: View {
    @Bindable var store: FrameKeepStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedFileID) {
                Section {
                    Button {
                        store.importFiles()
                    } label: {
                        Label("Add MOV Files", systemImage: "plus")
                    }

                    if store.files.isEmpty {
                        EmptyStateView()
                            .frame(maxWidth: .infinity)
                            .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20))
                    } else {
                        ForEach(store.files) { asset in
                            VideoRow(asset: asset, isActive: asset.id == store.activeFileID, result: store.results.first(where: { $0.inputURL == asset.url }))
                                .tag(asset.id)
                        }
                    }
                } header: {
                    Text("Queue")
                }
            }
            .listStyle(.sidebar)
        } detail: {
            DetailView(store: store)
        }
        .navigationTitle("FrameKeep")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.importFiles()
                } label: {
                    Label("Add Files", systemImage: "plus")
                }

                Button {
                    store.selectOutputFolder()
                } label: {
                    Label("Output Folder", systemImage: "folder")
                }

                Button {
                    store.startConversion()
                } label: {
                    Label("Convert", systemImage: "play.fill")
                }
                .disabled(!store.canStartConversion)

                Button(role: .destructive) {
                    store.clearAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(store.files.isEmpty)
            }
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "film.stack")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("Drop MOV files here")
                .font(.headline)
            Text("FrameKeep keeps everything on this Mac and uses the standard file browser for adding files.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct VideoRow: View {
    let asset: VideoAsset
    let isActive: Bool
    let result: ConversionResult?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "film")
                .font(.title3)
                .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(asset.width)×\(asset.height)  •  \(asset.codec)  •  \(Formatting.duration(asset.duration))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failure:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case nil:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DetailView: View {
    @Bindable var store: FrameKeepStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SummaryCard(store: store)

                GroupBox("Conversion Mode") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Mode", selection: $store.mode) {
                            ForEach(ConversionMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        Text(store.mode.summary)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Output") {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.outputFolderURL?.path(percentEncoded: false) ?? "Choose an output folder")
                                .textSelection(.enabled)
                            Text("Converted files stay local and are written as MP4.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Choose…") {
                            store.selectOutputFolder()
                        }
                    }
                }

                if !store.results.isEmpty {
                    GroupBox("Results") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(store.results) { result in
                                switch result {
                                case let .success(input, output):
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(input.lastPathComponent)
                                            Text(output.lastPathComponent)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                case let .failure(input, message):
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(input.lastPathComponent)
                                            Text(message)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(.background)
        .onDrop(of: ["public.file-url"], isTargeted: nil, perform: store.addDroppedItems(_:))
    }
}

private struct SummaryCard: View {
    @Bindable var store: FrameKeepStore

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Local MOV to MP4 conversion")
                            .font(.title2.weight(.semibold))
                        Text(store.statusMessage)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let activeFile = store.activeFile {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(activeFile.name)
                                .font(.headline)
                            Text(Formatting.duration(activeFile.duration))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ProgressView(value: store.progress) {
                    Text(store.isConverting ? "Progress" : "Ready")
                } currentValueLabel: {
                    Text("\(store.completedCount) / \(store.files.count)")
                }

                HStack {
                    Button(store.isConverting ? "Cancel" : "Start Conversion") {
                        store.isConverting ? store.cancelConversion() : store.startConversion()
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(store.isConverting ? false : !store.canStartConversion)

                    if store.latestOutputURL != nil {
                        Button("Reveal in Finder") {
                            store.revealLatestOutput()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

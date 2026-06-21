import SwiftUI

struct ContentView: View {
    @Bindable var store: LosslessVideoConverterStore
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
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
            .navigationTitle("Lossless Video Converter")
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

            if isDropTargeted {
                DropOverlayView()
                    .padding(20)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        .dropDestination(for: URL.self) { items, _ in
            store.addDroppedURLs(items)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isDropTargeted, perform: store.addDroppedItems(_:))
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
            Text("Lossless Video Converter keeps everything on this Mac and uses the standard file browser for adding files.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct DropOverlayView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.regularMaterial)
            .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.tint)
                    Text("Drop MOV files to add them")
                        .font(.title3.weight(.semibold))
                    Text("You can drop files anywhere in the window.")
                        .foregroundStyle(.secondary)
                }
                .padding(32)
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
    @Bindable var store: LosslessVideoConverterStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SummaryCard(store: store)

                SectionCard("Conversion Mode") {
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

                SectionCard("Output") {
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
                    SectionCard("Results") {
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
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(.background)
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}

private struct SummaryCard: View {
    @Bindable var store: LosslessVideoConverterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Local MOV to MP4 conversion without quality loss")
                        .font(.title2.weight(.semibold))
                    Text(store.statusMessage)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let activeFile = store.activeFile {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(activeFile.name)
                            .font(.headline)
                            .multilineTextAlignment(.trailing)
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

            HStack(spacing: 12) {
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
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}

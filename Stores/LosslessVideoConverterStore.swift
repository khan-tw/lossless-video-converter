import AppKit
import Foundation
import Observation

enum LosslessVideoConverterError: LocalizedError {
    case ffmpegMissing
    case unreadableMetadata
    case ffmpegFailure(String)

    var errorDescription: String? {
        switch self {
        case .ffmpegMissing:
            return "FFmpeg was not found. Set FFMPEG_PATH or install ffmpeg in a standard location such as /opt/homebrew/bin/ffmpeg or /usr/local/bin/ffmpeg."
        case .unreadableMetadata:
            return "Lossless Video Converter could not read the selected video's metadata."
        case let .ffmpegFailure(message):
            return message
        }
    }
}

@MainActor
@Observable
final class LosslessVideoConverterStore {
    var files: [VideoAsset] = []
    var selectedFileID: VideoAsset.ID?
    var outputFolderURL: URL?
    var mode: ConversionMode = .copy
    var isConverting = false
    var progress: Double = 0
    var completedCount = 0
    var statusMessage = "Add MOV files to start a local conversion."
    var results: [ConversionResult] = []
    var latestOutputURL: URL?
    var activeFileID: VideoAsset.ID?

    var canStartConversion: Bool {
        !files.isEmpty && outputFolderURL != nil && !isConverting
    }

    var activeFile: VideoAsset? {
        files.first(where: { $0.id == activeFileID })
    }

    var successfulCount: Int {
        results.reduce(into: 0) { count, result in
            if case .success = result {
                count += 1
            }
        }
    }

    private let service = FFmpegService()
    private var conversionTask: Task<Void, Never>?

    func importFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add"
        panel.message = "Choose one or more MOV files to convert locally."

        guard panel.runModal() == .OK else { return }
        Task { await addFiles(panel.urls) }
    }

    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Select where the converted MP4 files should be saved."
        panel.directoryURL = outputFolderURL ?? files.first?.folderURL

        guard panel.runModal() == .OK else { return }
        outputFolderURL = panel.url
    }

    func addDroppedItems(_ providers: [NSItemProvider]) -> Bool {
        let candidates = providers.filter { $0.hasItemConformingToTypeIdentifier("public.file-url") }
        guard !candidates.isEmpty else { return false }

        for provider in candidates {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, _ in
                guard
                    let self,
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }

                Task { @MainActor in
                    await self.addFiles([url])
                }
            }
        }
        return true
    }

    func removeSelection() {
        guard let currentSelection = selectedFileID,
              let selectedAsset = files.first(where: { $0.id == currentSelection }) else { return }
        files.removeAll { $0.id == currentSelection }
        results.removeAll { $0.inputURL == selectedAsset.url }
        if files.isEmpty {
            outputFolderURL = nil
            selectedFileID = nil
        } else {
            selectedFileID = files.first?.id
        }
    }

    func clearAll() {
        cancelConversion()
        files.removeAll()
        results.removeAll()
        selectedFileID = nil
        outputFolderURL = nil
        latestOutputURL = nil
        progress = 0
        completedCount = 0
        activeFileID = nil
        statusMessage = "Add MOV files to start a local conversion."
    }

    func startConversion() {
        guard canStartConversion, let outputFolderURL else { return }

        conversionTask?.cancel()
        conversionTask = Task { [weak self] in
            guard let self else { return }
            await self.runConversion(outputFolderURL: outputFolderURL)
        }
    }

    func cancelConversion() {
        conversionTask?.cancel()
        conversionTask = nil
        Task { await service.cancelCurrentProcess() }
        if isConverting {
            isConverting = false
            activeFileID = nil
            statusMessage = "Conversion canceled."
        }
    }

    func revealLatestOutput() {
        guard let latestOutputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([latestOutputURL])
    }

    private func addFiles(_ urls: [URL]) async {
        let movURLs = urls
            .filter { $0.pathExtension.lowercased() == "mov" }
            .filter { incomingURL in
                !files.contains(where: { $0.url.standardizedFileURL == incomingURL.standardizedFileURL })
            }

        guard !movURLs.isEmpty else { return }

        do {
            let inspected = try await withThrowingTaskGroup(of: VideoAsset.self) { group in
                for url in movURLs {
                    group.addTask {
                        let inspection = try await self.service.inspect(url: url)
                        return VideoAsset(
                            url: url,
                            duration: inspection.duration,
                            codec: inspection.codec,
                            width: inspection.width,
                            height: inspection.height
                        )
                    }
                }

                var assets: [VideoAsset] = []
                for try await asset in group {
                    assets.append(asset)
                }
                return assets.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }

            files.append(contentsOf: inspected)
            if outputFolderURL == nil {
                outputFolderURL = inspected.first?.folderURL
            }
            if selectedFileID == nil {
                selectedFileID = files.first?.id
            }
            statusMessage = "Ready to convert \(files.count) file\(files.count == 1 ? "" : "s")."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func runConversion(outputFolderURL: URL) async {
        isConverting = true
        progress = 0
        completedCount = 0
        results = []
        latestOutputURL = nil
        statusMessage = "Converting locally with FFmpeg…"

        var nextResults: [ConversionResult] = []

        for (index, asset) in files.enumerated() {
            if Task.isCancelled { break }

            activeFileID = asset.id
            progress = 0

            do {
                let outputURL = try await service.convert(
                    asset: asset,
                    outputDirectory: outputFolderURL,
                    mode: mode
                ) { [weak self] value in
                    Task { @MainActor in
                        self?.progress = value
                    }
                }

                let result = ConversionResult.success(input: asset.url, output: outputURL)
                nextResults.append(result)
                results = nextResults
                latestOutputURL = outputURL
            } catch is CancellationError {
                results = nextResults
                completedCount = index
                isConverting = false
                activeFileID = nil
                statusMessage = "Conversion canceled after \(index) file\(index == 1 ? "" : "s")."
                return
            } catch {
                let result = ConversionResult.failure(input: asset.url, message: error.localizedDescription)
                nextResults.append(result)
                results = nextResults
            }

            completedCount = index + 1
        }

        isConverting = false
        activeFileID = nil
        progress = 1

        let failures = nextResults.count - successfulCount
        if failures == 0 {
            statusMessage = "Finished \(successfulCount) file\(successfulCount == 1 ? "" : "s")."
            if UserDefaults.standard.bool(forKey: "losslessvideoconverter.autoRevealOnFinish"), let latestOutputURL {
                NSWorkspace.shared.activateFileViewerSelecting([latestOutputURL])
            }
        } else {
            statusMessage = "Finished \(successfulCount) file\(successfulCount == 1 ? "" : "s"), \(failures) failed."
        }
    }
}

import Foundation

struct VideoInspection {
    let duration: TimeInterval
    let codec: String
    let width: Int
    let height: Int
}

actor FFmpegService {
    private var currentProcess: Process?

    func inspect(url: URL) async throws -> VideoInspection {
        let ffmpegURL = try FFmpegLocator.resolve()
        let output = try await runProcess(
            executable: ffmpegURL,
            arguments: ["-hide_banner", "-i", url.path]
        )

        guard
            let durationMatch = output.firstMatch(of: /Duration:\s+(\d+):(\d+):(\d+(?:\.\d+)?)/),
            let videoMatch = output.firstMatch(of: /Video:\s*([^,]+).*?,\s*(\d{2,5})x(\d{2,5})/)
        else {
            throw LosslessVideoConverterError.unreadableMetadata
        }

        let hours = Double(durationMatch.1) ?? 0
        let minutes = Double(durationMatch.2) ?? 0
        let seconds = Double(durationMatch.3) ?? 0
        let duration = hours * 3600 + minutes * 60 + seconds

        return VideoInspection(
            duration: duration,
            codec: videoMatch.1.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            width: Int(videoMatch.2) ?? 0,
            height: Int(videoMatch.3) ?? 0
        )
    }

    func convert(
        asset: VideoAsset,
        outputDirectory: URL,
        mode: ConversionMode,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let ffmpegURL = try FFmpegLocator.resolve()
        let outputURL = OutputNamer.uniqueOutputURL(
            for: asset.url,
            in: outputDirectory,
            pathExtension: "mp4"
        )

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-y",
            "-i", asset.url.path
        ] + mode.ffmpegArguments + [
            "-movflags", "+faststart",
            "-progress", "pipe:1",
            "-nostats",
            outputURL.path
        ]
        process.standardOutput = stdout
        process.standardError = stderr

        let outputBuffer = OutputBuffer()
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            for line in outputBuffer.consume(chunk: chunk) {
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2, parts[0] == "out_time_ms", let outTimeMs = Double(parts[1]) else { continue }
                let percentage = min(0.99, (outTimeMs / 1_000_000) / max(asset.duration, 1))
                progress(percentage)
            }
        }

        let result: URL = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try process.run()
                    currentProcess = process
                } catch {
                    stdout.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                    return
                }

                process.terminationHandler = { finished in
                    stdout.fileHandleForReading.readabilityHandler = nil
                    Task {
                        await self.clearCurrentProcess(process)
                    }

                    let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let errorText = String(data: errorData, encoding: .utf8) ?? ""

                    if finished.terminationStatus == 0 {
                        progress(1)
                        continuation.resume(returning: outputURL)
                    } else if finished.terminationReason == .uncaughtSignal || finished.terminationStatus == 15 {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        let message = errorText
                            .split(separator: "\n")
                            .map(String.init)
                            .last(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                            ?? "Conversion failed."
                        continuation.resume(throwing: LosslessVideoConverterError.ffmpegFailure(message))
                    }
                }
            }
        } onCancel: {
            Task {
                await self.cancelCurrentProcess()
            }
        }

        return result
    }

    func cancelCurrentProcess() {
        currentProcess?.terminate()
        currentProcess = nil
    }

    private func clearCurrentProcess(_ process: Process) {
        guard currentProcess === process else { return }
        currentProcess = nil
    }

    private func runProcess(executable: URL, arguments: [String]) async throws -> String {
        let process = Process()
        let stderr = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardError = stderr
        process.standardOutput = Pipe()

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            process.terminationHandler = { finished in
                let data = stderr.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                if finished.terminationStatus == 0 || !text.isEmpty {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: LosslessVideoConverterError.unreadableMetadata)
                }
            }
        }
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""

    func consume(chunk: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        buffer += chunk
        let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false)
        buffer = String(lines.last ?? "")
        return lines.dropLast().map(String.init)
    }
}

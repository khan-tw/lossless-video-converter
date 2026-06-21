import Foundation

enum ConversionMode: String, CaseIterable, Identifiable {
    case copy
    case highQuality

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copy:
            return "Lossless Rewrap"
        case .highQuality:
            return "High Compatibility"
        }
    }

    var summary: String {
        switch self {
        case .copy:
            return "Keeps original quality and converts fastest."
        case .highQuality:
            return "Re-encodes to H.264/AAC for wider playback support."
        }
    }

    var ffmpegArguments: [String] {
        switch self {
        case .copy:
            return ["-c", "copy"]
        case .highQuality:
            return [
                "-c:v", "libx264",
                "-preset", "slow",
                "-crf", "15",
                "-pix_fmt", "yuv420p",
                "-c:a", "aac",
                "-b:a", "320k"
            ]
        }
    }
}

struct VideoAsset: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let duration: TimeInterval
    let codec: String
    let width: Int
    let height: Int

    var name: String { url.lastPathComponent }
    var folderURL: URL { url.deletingLastPathComponent() }
}

enum ConversionResult: Identifiable, Hashable {
    case success(input: URL, output: URL)
    case failure(input: URL, message: String)

    var id: String {
        switch self {
        case let .success(input, _):
            return "success:\(input.path)"
        case let .failure(input, _):
            return "failure:\(input.path)"
        }
    }

    var inputURL: URL {
        switch self {
        case let .success(input, _), let .failure(input, _):
            return input
        }
    }
}

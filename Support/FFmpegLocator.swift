import Foundation

enum FFmpegLocator {
    static func resolve() throws -> URL {
        let environment = ProcessInfo.processInfo.environment

        let candidates: [URL] = [
            environment["FFMPEG_PATH"].map(URL.init(fileURLWithPath:)),
            URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/local/bin/ffmpeg"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/ffmpeg")
        ].compactMap { $0 }

        guard let first = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw FrameKeepError.ffmpegMissing
        }

        return first
    }
}

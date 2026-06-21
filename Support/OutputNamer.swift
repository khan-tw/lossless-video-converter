import Foundation

enum OutputNamer {
    static func uniqueOutputURL(for inputURL: URL, in directory: URL, pathExtension: String) -> URL {
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let preferred = directory.appendingPathComponent(baseName).appendingPathExtension(pathExtension)
        guard !FileManager.default.fileExists(atPath: preferred.path) else {
            return nextAvailableURL(baseName: baseName, in: directory, pathExtension: pathExtension)
        }
        return preferred
    }

    private static func nextAvailableURL(baseName: String, in directory: URL, pathExtension: String) -> URL {
        var index = 2
        while true {
            let candidate = directory
                .appendingPathComponent("\(baseName)-\(index)")
                .appendingPathExtension(pathExtension)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}

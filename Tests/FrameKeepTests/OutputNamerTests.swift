import Foundation
import Testing
@testable import FrameKeep

struct OutputNamerTests {
    @Test func generatesIncrementedNameWhenNeeded() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let input = root.appendingPathComponent("clip.mov")
        FileManager.default.createFile(atPath: root.appendingPathComponent("clip.mp4").path, contents: Data())

        let result = OutputNamer.uniqueOutputURL(for: input, in: root, pathExtension: "mp4")
        #expect(result.lastPathComponent == "clip-2.mp4")
    }
}

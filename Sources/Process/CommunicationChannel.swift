@_exported import class Foundation.Pipe

import FileSystem
import struct Foundation.Data

public enum CommunicationChannel {
    case pipe(Pipe)
    case file(File)

    public func readAllText() async -> String {
        switch self {
        case .pipe(let pipe): return pipe.readAllText()
        case .file(let file): return await file.readAllText()
        }
    }

    // FIXME: should be property
    public func availableData() async ->  Data {
        switch self {
        case .pipe(let pipe): return pipe.availableData
        case .file(let file): return await file.availableData()
        }
    }
}

extension File {
    public func readAllText() async -> String {
        do {
            return try await open()
                .readUntilEnd(as: String.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }

    // FIXME: should be property
    public func availableData() async -> Data {
        do { return Data(try await self.open().readUntilEnd()) }
        catch { return Data() }
    }
}

extension Pipe {
    public func readAllText() -> String {
        let data = self.fileHandleForReading.readDataToEndOfFile()
        guard let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var availableData: Data {
        return fileHandleForReading.availableData
    }
}

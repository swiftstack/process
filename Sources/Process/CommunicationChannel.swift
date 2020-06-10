@_exported import class Foundation.Pipe

import FileSystem
import struct Foundation.Data

public enum CommunicationChannel {
    case pipe(Pipe)
    case file(File)

    public func readAllText() -> String {
        switch self {
        case .pipe(let pipe): return pipe.readAllText()
        case .file(let file): return file.readAllText()
        }
    }

    public var availableData: Data {
        switch self {
        case .pipe(let pipe): return pipe.availableData
        case .file(let file): return file.availableData
        }
    }
}

extension File {
    public func readAllText() -> String {
        do {
            return try open()
                .readUntilEnd(as: String.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }

    public var availableData: Data {
        do {
            return Data(try open().readUntilEnd())
        } catch {
            return Data()
        }
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

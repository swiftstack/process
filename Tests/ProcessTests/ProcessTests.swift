import Test
import Time
import Async
import FileSystem

@testable import Process

class ProcessTests: TestCase {
    func testByName() {
        async {
            scope {
                let process = Process(name: "uname")
                process.standardOutput = .pipe(Pipe())
                try process.launch()

                try process.waitUntilExit()

                let result = process.standardOutput!.readAllText()
                #if os(macOS)
                expect(result == "Darwin")
                #else
                expect(result == "Linux")
                #endif
            }
        }
        loop.run()
    }

    func testByPath() {
        async {
            scope {
                #if os(macOS)
                let process = Process(path: "/usr/bin/uname")
                #else
                let process = Process(path: "/bin/uname")
                #endif
                process.standardOutput = .pipe(Pipe())
                try process.launch()

                try process.waitUntilExit()

                let result = process.standardOutput!.readAllText()
                #if os(macOS)
                expect(result == "Darwin")
                #else
                expect(result == "Linux")
                #endif
            }
        }
        loop.run()
    }

    func testStatus() {
        async {
            scope {
                let process = Process(name: "sleep", arguments: ["1"])
                expect(process.status == .created)

                try process.launch()
                expect(process.status == .running)

                try process.waitUntilExit()
                expect(process.status == .exited(code: 0))
            }
        }
        loop.run()
    }

    func testExitTimeout() {
        async {
            scope {
                let process = Process(name: "sleep", arguments: ["1"])
                try process.launch()
                expect(throws: ProcessError.timeout) {
                    try process.waitUntilExit(deadline: .now + 100.ms)
                }
            }
        }
        loop.run()
    }

    func testFileChannel() {
        async {
            scope {
                let input = try File.randomTempFile()
                let output = try File.randomTempFile()

                try input.create()
                try output.create()

                defer {
                    try? input.remove()
                    try? output.remove()
                }

                let process = Process(name: "uname")
                process.standardInput = .file(input)
                process.standardOutput = .file(output)
                try process.launch()

                try process.waitUntilExit()

                let result = process.standardOutput!.readAllText()
                #if os(macOS)
                expect(result == "Darwin")
                #else
                expect(result == "Linux")
                #endif
            }
        }
        loop.run()
    }
}


extension File {
    static func randomTempFile() throws -> File {
        let name = "fileTest\((1_000..<2_000).randomElement() ?? 0)"
        return try File(at: Path("/tmp/\(name)"))
    }
}

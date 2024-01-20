import Test
import Time
import FileSystem

@testable import Process

test("ByName") {
    let process = Process(name: "uname")
    process.standardOutput = .pipe(Pipe())
    try process.launch()

    try await process.waitUntilExit()

    let result = await process.standardOutput!.readAllText()
    #if os(macOS)
    expect(result == "Darwin")
    #else
    expect(result == "Linux")
    #endif
}

test("ByPath") {
    #if os(macOS)
    let process = Process(path: "/usr/bin/uname")
    #else
    let process = Process(path: "/bin/uname")
    #endif
    process.standardOutput = .pipe(Pipe())
    try process.launch()

    try await process.waitUntilExit()

    let result = await process.standardOutput!.readAllText()
    #if os(macOS)
    expect(result == "Darwin")
    #else
    expect(result == "Linux")
    #endif
}

test("Status") {
    let process = Process(name: "sleep", arguments: ["1"])
    expect(process.status == .created)

    try process.launch()
    expect(process.status == .running)

    try await process.waitUntilExit()
    expect(process.status == .exited(code: 0))
}

test("ExitTimeout") {
    let process = Process(name: "sleep", arguments: ["1"])
    try process.launch()
    await expect(throws: ProcessError.timeout) {
        try await process.waitUntilExit(deadline: .now + 100.ms)
    }
}

test("FileChannel") {
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

    try await process.waitUntilExit()

    let result = await process.standardOutput!.readAllText()
    #if os(macOS)
    expect(result == "Darwin")
    #else
    expect(result == "Linux")
    #endif
}

await run()

extension File {
    static func randomTempFile() throws -> File {
        let name = "fileTest\((1_000..<2_000).randomElement() ?? 0)"
        return try File(at: Path("/tmp/\(name)"))
    }
}

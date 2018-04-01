import Test
import Time
import AsyncDispatch

@testable import Async
@testable import Process

class ProcessTests: TestCase {
    override func setUp() {
        async.setUp(Dispatch.self)
    }

    func testByName() {
        do {
            let process = Process(name: "uname")
            process.standardOutput = .pipe(Pipe())
            try process.launch()

            assertNoThrow(try process.waitUntilExit())

            let result = process.standardOutput!.readAllText()
        #if os(macOS)
            assertEqual(result, "Darwin")
        #else
            assertEqual(result, "Linux")
        #endif
        } catch {
            fail(String(describing: error))
        }
    }

    func testByPath() {
        do {
        #if os(macOS)
            let process = Process(path: "/usr/bin/uname")
        #else
            let process = Process(path: "/bin/uname")
        #endif
            process.standardOutput = .pipe(Pipe())
            try process.launch()

            assertNoThrow(try process.waitUntilExit())

            let result = process.standardOutput!.readAllText()
        #if os(macOS)
            assertEqual(result, "Darwin")
        #else
            assertEqual(result, "Linux")
        #endif
        } catch {
            fail(String(describing: error))
        }
    }

    func testStatus() {
        let process = Process(name: "uname")
        assertEqual(process.status, .created)

        assertNoThrow(try process.launch())
        assertEqual(process.status, .running)

        assertNoThrow(try process.waitUntilExit())
        assertEqual(process.status, .exited(code: 0))
    }

    func testExitTimeout() {
        let process = Process(name: "sleep", arguments: ["1"])
        assertNoThrow(try process.launch())
        assertThrowsError(try process.waitUntilExit(deadline: .now + 100.ms))
        { error in
            assertEqual(error as? ProcessError, .timeout)
        }
    }
}

import Test
import AsyncDispatch
@testable import Process

class ProcessTests: TestCase {
    override func setUp() {
        AsyncDispatch().registerGlobal()
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
}

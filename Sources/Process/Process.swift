import Time
import Async
import Platform
import FileSystem

enum ProcessError: Error {
    case alreadyLaunched
    case timeout
}

public class Process {
    public enum Source {
        case name(String)
        case path(String)
    }

    public enum Status {
        case created
        case running
        case signaled(signal: Int)
        case exited(code: Int)
        case unsupported
    }

    public let source: Source
    public var arguments: [String]
    public var environment: [String : String]

    open var currentDirectory: Directory

    public private(set) var processIdentifier: Int32 = -1

    private init(
        source: Source,
        arguments: [String],
        environment: [String : String],
        currentDirectory: Directory
    ) {
        self.source = source
        self.arguments = arguments
        self.environment = environment
        self.currentDirectory = currentDirectory
        self._status = .created
    }

    public convenience init(
        path: String,
        arguments: [String] = [],
        environment: [String : String] = Environment.values,
        currentDirectory: Directory = .current ?? .default
    ) {
        self.init(
            source: .path(path),
            arguments: arguments,
            environment: environment,
            currentDirectory: currentDirectory)
    }

    public convenience init(
        name: String,
        arguments: [String] = [],
        environment: [String : String] = Environment.values,
        currentDirectory: Directory = .current ?? .default
    ) {
        self.init(
            source: .name(name),
            arguments: arguments,
            environment: environment,
            currentDirectory: currentDirectory)
    }

    private var _status: Status
    public private(set) var status: Status {
        get {
            if case .running = _status {
                updateStatus()
            }
            return _status
        }
        set {
            _status = newValue
        }
    }

    // standard I/O channels
    open var standardInput: CommunicationChannel?
    open var standardOutput: CommunicationChannel?
    open var standardError: CommunicationChannel?

    typealias CString = UnsafeMutablePointer<Int8>

    public func launch() throws {
        guard status == .created else {
            throw ProcessError.alreadyLaunched
        }

        var arguments = self.arguments

        switch source {
        case .name(let name): arguments.insert(name, at: 0)
        case .path(let path): arguments.insert(path, at: 0)
        }

        // Convert the arguments array into a posix_spawn-friendly format

        let argv: UnsafeMutablePointer<CString?> =
            arguments.withUnsafeBufferPointer {
                let array: UnsafeBufferPointer<String> = $0
                let buffer = UnsafeMutablePointer<CString?>.allocate(
                    capacity: array.count + 1)
                buffer.initialize(
                    from: array.map { $0.withCString(strdup) },
                    count: array.count)
                buffer[array.count] = nil
                return buffer
        }

        defer {
            for arg in argv ..< argv + arguments.count {
                free(UnsafeMutableRawPointer(arg.pointee))
            }
            argv.deallocate()
        }

        // Convert the environment into a posix_spawn-friendly format

        let envp: UnsafeMutablePointer<CString?>

        envp = UnsafeMutablePointer<CString?>.allocate(
            capacity: environment.count + 1)
        envp.initialize(
            from: environment.map { strdup("\($0)=\($1)") },
            count: environment.count)
        envp[environment.count] = nil

        defer {
            for pair in envp ..< envp + environment.count {
                free(UnsafeMutableRawPointer(pair.pointee))
            }
            envp.deallocate()
        }

        // Initialize file actions
        #if os(macOS)
            var fileActions: posix_spawn_file_actions_t? = nil
        #else
            var fileActions: posix_spawn_file_actions_t =
                posix_spawn_file_actions_t()
        #endif

        func ensureZeroExit(_ code: Int32) throws {
            if code != 0 {
                throw SystemError()
            }
        }

        try ensureZeroExit(posix_spawn_file_actions_init(&fileActions))
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        // Save fds for file actions
        var fdsToDuplicate = [(Int32, Int32)]()
        var fdsToClose = Set<Int32>()

        if let standardInput = standardInput {
            switch standardInput {
            case .pipe(let pipe):
                fdsToDuplicate.append(
                    (STDIN_FILENO, pipe.fileHandleForReading.fileDescriptor))
                fdsToClose.insert(pipe.fileHandleForWriting.fileDescriptor)
            case .file(let file):
                let fd = try system { open(file.path.string, O_RDONLY) }
                fdsToDuplicate.append((STDIN_FILENO, fd))
            }
        }

        if let standardOutput = standardOutput {
            switch standardOutput {
            case .pipe(let pipe):
                fdsToDuplicate.append(
                    (STDOUT_FILENO, pipe.fileHandleForWriting.fileDescriptor))
                fdsToClose.insert(pipe.fileHandleForReading.fileDescriptor)
            case .file(let file):
                let fd = try system { open(file.path.string, O_WRONLY) }
                fdsToDuplicate.append((STDOUT_FILENO, fd))
            }
        }

        if let standardError = standardError {
            switch standardError {
            case .pipe(let pipe):
                fdsToDuplicate.append(
                    (STDERR_FILENO, pipe.fileHandleForWriting.fileDescriptor))
                fdsToClose.insert(pipe.fileHandleForReading.fileDescriptor)
            case .file(let file):
                let fd = try system { open(file.path.string, O_WRONLY) }
                fdsToDuplicate.append((STDERR_FILENO, fd))
            }
        }

        // Register file actions
        for (newfildes, fildes) in fdsToDuplicate {
            try ensureZeroExit(
                posix_spawn_file_actions_adddup2(
                    &fileActions, fildes, newfildes))
        }
        for fd in fdsToClose {
            try ensureZeroExit(
                posix_spawn_file_actions_addclose(&fileActions, fd))
        }

        // Change current directory path
        let previousDirectory: Directory = .current ?? .default
        try Directory.changeWorkingDirectory(to: currentDirectory.path)

        // Launch the process
        var pid = pid_t()

        switch source {
        case .name(let name):
            try ensureZeroExit(
                posix_spawnp(&pid, name, &fileActions, nil, argv, envp))
        case .path(let path):
            try ensureZeroExit(
                posix_spawn(&pid, path, &fileActions, nil, argv, envp))
        }

        // Reset the previous working directory path.
        try Directory.changeWorkingDirectory(to: previousDirectory.path)

        // Close the read end of input and the write end of the output pipes.
        if let input = standardInput, case .pipe(let pipe) = input {
            pipe.fileHandleForReading.closeFile()
        }
        if let output = standardOutput, case .pipe(let pipe) = output  {
            pipe.fileHandleForWriting.closeFile()
        }
        if let output = standardError, case .pipe(let pipe) = output  {
            pipe.fileHandleForWriting.closeFile()
        }

        self.processIdentifier = pid
        self.status = .running
    }
}

extension Process {
    @discardableResult
    func updateStatus() -> Bool {
        var exitCode : Int32 = 0
        var waitResult : Int32 = 0

        repeat {
            waitResult = waitpid(processIdentifier, &exitCode, WNOHANG)
        } while waitResult == -1 && errno == EINTR

        guard waitResult != 0 else {
            return false
        }

        if WIFSIGNALED(exitCode) {
            self.status = .signaled(signal: Int(WTERMSIG(exitCode)))
        } else if WIFEXITED(exitCode) {
            self.status = .exited(code: Int(WEXITSTATUS(exitCode)))
        } else {
            assertionFailure("not implemented")
            self.status = .unsupported
        }

        return true
    }

    public func waitUntilExit(deadline: Time = .distantFuture) throws {
        while updateStatus() == false {
            if deadline < .now {
                throw ProcessError.timeout
            }
            async.sleep(until: .now + 50.ms)
        }
    }
}

extension Process.Status: Equatable {
    public static func ==(lhs: Process.Status, rhs: Process.Status) -> Bool {
        switch (lhs, rhs) {
        case (.created, .created): return true
        case (.running, .running): return true
        case (.signaled(let lhs), .signaled(let rhs)): return lhs == rhs
        case (.exited(let lhs), .exited(let rhs)): return lhs == rhs
        default: return false
        }
    }
}

extension Directory {
    public static var `default`: Directory {
        do {
            let path = try Path("~/").expandingTilde()
            return try Directory(at: path)
        } catch {
            return try! .init(at: "/")
        }
    }
}

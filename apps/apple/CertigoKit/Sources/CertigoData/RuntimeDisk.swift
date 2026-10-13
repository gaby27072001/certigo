import Foundation

#if os(iOS)
    import CertigoAppleFileIO
#endif

/// Flat generated names, directory-relative handles and no-follow opens avoid path re-resolution.
/// The caller serializes access; root must be dedicated trusted application storage.

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif
public enum RuntimeStoreError: Error, Equatable, Sendable {
    case unsafeDiskEntry
    case io(Int32)
    case corruptState
    case capacity
    case busy
    case missingFile
    case staleActivation
}
enum RuntimeWritePoint: Sendable { case beforeRename, afterRename }
final class RuntimeDisk {
    struct Entry {
        let name: String
        let bytes: Int
    }
    private let directory: Int32
    private let lockFile: Int32
    private let maximumBytes: Int
    private let fault: @Sendable (RuntimeWritePoint, String) throws -> Void

    init(
        root: URL, maximumBytes: Int,
        fault: @escaping @Sendable (RuntimeWritePoint, String) throws -> Void = { _, _ in }
    ) throws {
        guard root.isFileURL, maximumBytes > 0, maximumBytes <= 384 * 1_024 * 1_024 else {
            throw RuntimeStoreError.capacity
        }
        guard root.path.hasPrefix("/"), !root.path.utf8.contains(0),
            root.path.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." })
        else { throw RuntimeStoreError.unsafeDiskEntry }
        var original = stat()
        if lstat(root.path, &original) == 0 {
            guard original.st_mode & mode_t(S_IFMT) == mode_t(S_IFDIR) else {
                throw RuntimeStoreError.unsafeDiskEntry
            }
        } else if errno != ENOENT {
            throw RuntimeStoreError.io(errno)
        }
        // Canonicalize only an existing ancestor; Foundation may rewrite a missing Darwin suffix.
        let path = try Self.creationPath(root)
        var handle = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard handle >= 0 else { throw RuntimeStoreError.io(errno) }
        do {
            for component in path.split(separator: "/") {
                let name = String(component)
                var next = openat(handle, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                if next < 0, errno == ENOENT {
                    guard mkdirat(handle, name, 0o700) == 0 || errno == EEXIST else {
                        throw RuntimeStoreError.io(errno)
                    }
                    next = openat(handle, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                }
                guard next >= 0 else { throw RuntimeStoreError.unsafeDiskEntry }
                close(handle)
                handle = next
            }
            let lock = openat(
                handle, ".lock", O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
            guard lock >= 0 else { throw RuntimeStoreError.unsafeDiskEntry }
            var attributes = stat()
            guard fstat(lock, &attributes) == 0, attributes.st_nlink == 1,
                attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG)
            else {
                close(lock)
                throw RuntimeStoreError.unsafeDiskEntry
            }
            directory = handle
            lockFile = lock
        } catch {
            close(handle)
            throw error
        }
        self.maximumBytes = maximumBytes
        self.fault = fault
    }

    private static func creationPath(_ root: URL) throws -> String {
        var ancestor = root
        var missing: [String] = []
        while true {
            if let resolved = realpath(ancestor.path, nil) {
                defer { free(resolved) }
                let prefix = String(cString: resolved)
                return ([prefix] + missing.reversed()).joined(separator: "/")
            }
            let failure = errno
            guard failure == ENOENT else { throw RuntimeStoreError.io(failure) }
            let component = ancestor.lastPathComponent
            guard !component.isEmpty, component != "/", component != ".", component != ".." else {
                throw RuntimeStoreError.unsafeDiskEntry
            }
            missing.append(component)
            ancestor.deleteLastPathComponent()
        }
    }

    deinit {
        close(lockFile)
        close(directory)
    }

    func exclusive<T>(_ body: () throws -> T) throws -> T {
        guard flock(lockFile, LOCK_EX | LOCK_NB) == 0 else {
            if errno == EWOULDBLOCK { throw RuntimeStoreError.busy }
            throw RuntimeStoreError.io(errno)
        }
        defer { _ = flock(lockFile, LOCK_UN) }
        return try body()
    }

    func read(_ name: String, maximum: Int) throws -> Data? {
        try safeName(name)
        let handle = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        if handle < 0 {
            if errno == ENOENT { return nil }
            if errno == ELOOP { throw RuntimeStoreError.unsafeDiskEntry }
            throw RuntimeStoreError.io(errno)
        }
        defer { close(handle) }
        var attributes = stat()
        guard fstat(handle, &attributes) == 0 else { throw RuntimeStoreError.io(errno) }
        guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG), attributes.st_nlink == 1
        else {
            throw RuntimeStoreError.unsafeDiskEntry
        }
        guard attributes.st_size >= 0, attributes.st_size <= maximum else {
            throw RuntimeStoreError.capacity
        }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 16 * 1_024)
        while true {
            let count = buffer.withUnsafeMutableBytes { raw in
                systemRead(handle, raw.baseAddress, raw.count)
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw RuntimeStoreError.io(errno)
            }
            if count == 0 { return result }
            guard count <= maximum - result.count else { throw RuntimeStoreError.capacity }
            result.append(contentsOf: buffer.prefix(count))
        }
    }

    func write(_ bytes: Data, name: String) throws {
        try safeName(name)
        let used = try usedBytes()
        // Reserve the entire temporary copy too; never evict a pinned snapshot to make room.
        guard bytes.count <= maximumBytes - used else { throw RuntimeStoreError.capacity }
        let temporary = ".tmp-\(UUID().uuidString)"
        let handle = openat(
            directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard handle >= 0 else { throw RuntimeStoreError.io(errno) }
        defer {
            close(handle)
            _ = unlinkat(directory, temporary, 0)
        }
        #if os(iOS)
            let protection = try firstUnlockProtectionClass()
            guard certigo_set_file_protection(handle, protection) == 0 else {
                throw RuntimeStoreError.io(errno)
            }
            let applied = certigo_file_protection(handle)
            guard applied >= 0 else { throw RuntimeStoreError.io(errno) }
            guard applied == protection else { throw RuntimeStoreError.unsafeDiskEntry }
        #endif
        try bytes.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let count = systemWrite(
                    handle, raw.baseAddress?.advanced(by: offset), raw.count - offset)
                if count < 0 {
                    if errno == EINTR { continue }
                    throw RuntimeStoreError.io(errno)
                }
                guard count > 0 else { throw RuntimeStoreError.io(EIO) }
                offset += count
            }
        }
        guard fsync(handle) == 0 else { throw RuntimeStoreError.io(errno) }
        try fault(.beforeRename, name)
        guard renameat(directory, temporary, directory, name) == 0 else {
            throw RuntimeStoreError.io(errno)
        }
        guard fsync(directory) == 0 else { throw RuntimeStoreError.io(errno) }
        try fault(.afterRename, name)
    }

    #if os(iOS)
        private func firstUnlockProtectionClass() throws -> Int32 {
            // Foundation exposes the protection policy; Darwin exposes descriptor operations,
            // but the SDK does not expose a Swift class-C constant. Never guess its numeric value.
            var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            guard
                path.withUnsafeMutableBufferPointer({
                    certigo_file_path(directory, $0.baseAddress, $0.count)
                }) == 0
            else { throw RuntimeStoreError.io(errno) }
            guard let terminator = path.firstIndex(of: 0),
                let directoryPath = String(
                    bytes: path[..<terminator].map { UInt8(bitPattern: $0) }, encoding: .utf8)
            else { throw RuntimeStoreError.unsafeDiskEntry }
            let name = ".tmp-\(UUID().uuidString)"
            let url = URL(fileURLWithPath: directoryPath, isDirectory: true)
                .appendingPathComponent(name)
            let handle = openat(
                directory, name,
                O_CREAT | O_EXCL | O_RDWR | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
            guard handle >= 0 else { throw RuntimeStoreError.io(errno) }
            defer { close(handle) }
            let result: Int32
            do {
                var opened = stat()
                var named = stat()
                guard fstat(handle, &opened) == 0, lstat(url.path, &named) == 0,
                    opened.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
                    opened.st_nlink == 1, opened.st_size == 0,
                    opened.st_dev == named.st_dev, opened.st_ino == named.st_ino
                else { throw RuntimeStoreError.unsafeDiskEntry }
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path)
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                guard
                    attributes[.protectionKey] as? FileProtectionType
                        == .completeUntilFirstUserAuthentication
                else { throw RuntimeStoreError.unsafeDiskEntry }
                result = certigo_file_protection(handle)
                guard result >= 0 else { throw RuntimeStoreError.io(errno) }
                guard lstat(url.path, &named) == 0,
                    opened.st_dev == named.st_dev, opened.st_ino == named.st_ino
                else { throw RuntimeStoreError.unsafeDiskEntry }
            } catch {
                guard unlinkat(directory, name, 0) == 0 else {
                    throw RuntimeStoreError.io(errno)
                }
                throw error
            }
            guard unlinkat(directory, name, 0) == 0 else { throw RuntimeStoreError.io(errno) }
            return result
        }
    #endif

    private func usedBytes() throws -> Int {
        try entries().reduce(0) { $0 + $1.bytes }
    }

    func remove(_ name: String) throws {
        try safeName(name)
        guard name != "state.json", name != ".lock" else {
            throw RuntimeStoreError.unsafeDiskEntry
        }
        var attributes = stat()
        guard fstatat(directory, name, &attributes, AT_SYMLINK_NOFOLLOW) == 0 else {
            throw RuntimeStoreError.io(errno)
        }
        guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG), attributes.st_nlink == 1
        else {
            throw RuntimeStoreError.unsafeDiskEntry
        }
        guard unlinkat(directory, name, 0) == 0, fsync(directory) == 0 else {
            throw RuntimeStoreError.io(errno)
        }
    }

    func entries() throws -> [Entry] {
        // A new open file description is needed: dup would share readdir's advancing offset.
        let handle = openat(directory, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard handle >= 0 else { throw RuntimeStoreError.io(errno) }
        guard let stream = fdopendir(handle) else {
            close(handle)
            throw RuntimeStoreError.io(errno)
        }
        defer { closedir(stream) }
        var total = 0
        var count = 0
        var result: [Entry] = []
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                guard errno == 0 else { throw RuntimeStoreError.io(errno) }
                return result
            }
            let name = withUnsafePointer(to: entry.pointee.d_name) {
                $0.withMemoryRebound(
                    to: CChar.self, capacity: MemoryLayout.size(ofValue: entry.pointee.d_name)
                ) {
                    String(cString: $0)
                }
            }
            if name == "." || name == ".." { continue }
            try safeName(name)
            count += 1
            guard count <= 30_000 else { throw RuntimeStoreError.capacity }
            var attributes = stat()
            guard fstatat(directory, name, &attributes, AT_SYMLINK_NOFOLLOW) == 0 else {
                throw RuntimeStoreError.io(errno)
            }
            guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
                attributes.st_nlink == 1
            else { throw RuntimeStoreError.unsafeDiskEntry }
            guard attributes.st_size >= 0, attributes.st_size <= maximumBytes - total else {
                throw RuntimeStoreError.capacity
            }
            total += Int(attributes.st_size)
            result.append(Entry(name: name, bytes: Int(attributes.st_size)))
        }
    }

    private func safeName(_ value: String) throws {
        let pattern = "^(?:state\\.json|\\.lock|[bx]-[0-9a-f]{64}\\.json|\\.tmp-[0-9A-F-]{36})$"
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            throw RuntimeStoreError.unsafeDiskEntry
        }
    }
}
private func systemRead(_ fd: Int32, _ pointer: UnsafeMutableRawPointer?, _ count: Int) -> Int {
    #if canImport(Darwin)
        Darwin.read(fd, pointer, count)
    #else
        Glibc.read(fd, pointer, count)
    #endif
}
private func systemWrite(_ fd: Int32, _ pointer: UnsafeRawPointer?, _ count: Int) -> Int {
    #if canImport(Darwin)
        Darwin.write(fd, pointer, count)
    #else
        Glibc.write(fd, pointer, count)
    #endif
}

import Foundation

/// A filehandle that only represents directories.
struct DirFileHandle: ~Copyable, Hashable {
    var fileDescriptor: Int32

    /// Open directory at `path`.
    init(_ path: Path) throws(POSIXError) {
        self.fileDescriptor = open(
            path.cString,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC
        )
        if fileDescriptor < 0 { throw POSIXError.fromErrno }
    }

    /// Open directory at `path`, relative to existing file handle.
    init(_ path: Path, relativeTo parent: borrowing DirFileHandle) throws(POSIXError) {
        self.fileDescriptor = openat(
            parent.fileDescriptor,
            path.cString,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC
        )
        if fileDescriptor < 0 { throw POSIXError.fromErrno }
    }

    consuming func close() throws(POSIXError) {
        let result = Darwin.close(fileDescriptor)
        if result < 0 { throw POSIXError.fromErrno }
    }

    deinit {
        Darwin.close(fileDescriptor)
    }
}

extension POSIXError {
    static var fromErrno: Self {
        .init(POSIXErrorCode(rawValue: Darwin.errno) ?? .ENOTRECOVERABLE)
    }

    init(_ code: Int32) {
        self.init(POSIXErrorCode(rawValue: code) ?? .ENOTRECOVERABLE)
    }
}

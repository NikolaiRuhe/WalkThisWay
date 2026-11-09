import Foundation

public struct Directory: Sendable {
    public let path: Path
    private weak var parentHandle: SharedDirFileHandle?

    public init(_ path: Path) {
        self.path = path.flattened
    }

    fileprivate init(_ path: Path, parentHandle: SharedDirFileHandle) {
        self.path = path
        self.parentHandle = parentHandle
    }

    public func enumerateDirectories(
        _ directoryHandler: (Directory) -> Void,
        files fileHandler: (File) -> Void,
        errors errorHandler: (Path, any Error) -> Void = { _, _ in },
    ) throws {
        let fileHandle: DirFileHandle = if let parentHandle {
            try DirFileHandle(path, relativeTo: parentHandle.fileHandle)
        } else {
            try DirFileHandle(path.flattened)
        }

        try withExtendedLifetime(SharedDirFileHandle(fileHandle)) { ref in
            var dirEntries: [DirEntry] = []
            try enumerateContentsOfDirectory(
                at: ref.fileHandle.fileDescriptor
            ) { entry in
                if let error = entry.error {
                    errorHandler(
                        path.appending(entry.name),
                        error,
                    )
                } else if entry.type == .directory {
                    dirEntries.append(entry)
                } else {
                    fileHandler(File(entry, path: path.appending(entry.name)))
                }
            }

            for entry in dirEntries {
                let directory = Directory(
                    path.appending(entry.name),
                    parentHandle: ref
                )
                directoryHandler(directory)
            }
        }
    }
}

fileprivate final class SharedDirFileHandle: Sendable {
    let fileHandle: DirFileHandle
    init(_ fileHandle: consuming DirFileHandle) {
        self.fileHandle = fileHandle
    }
}

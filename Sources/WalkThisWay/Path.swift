import Foundation

/// A filename or path into the filesystem, stored as a C string, plus a linked
/// list of relative base paths.
public struct Path: Sendable, Hashable, CustomStringConvertible {
    // always non-empty and zero terminated
    var cString: [CChar]

    // only set for non-absolute paths
    fileprivate var basePathRef: PathRef?

    public init(_ cString: [CChar], relativeTo base: Path? = nil) {
        // cString must always be non-empty and zero terminated
        precondition(cString.count >= 2)
        precondition(cString.last == 0)
        precondition(cString == [.pathSeparator, 0] || cString.dropLast().last != .pathSeparator)

        self.cString = cString
        if let base {
            precondition(cString[0] != .pathSeparator, "trying to create an absolute path with a base path")
            self.basePathRef = PathRef(base)
        }
    }

    internal init(_ buffer: some Sequence<CChar>, relativeTo base: Path? = nil) {
        self.init(.init(buffer), relativeTo: base)
    }

    public init(_ string: String, relativeTo base: Path? = nil) {
        let ptr = FileManager.default.fileSystemRepresentation(withPath: string)
        self.init(.init(UnsafeBufferPointer(start: ptr, count: strlen(ptr) + 1)), relativeTo: base)
    }

    /// The base path this (relative) path is based on.
    var basePath: Path? { basePathRef?.wrapped }

    fileprivate var concatenatedPath: [CChar] {
        (basePath?.concatenatedPath ?? []) + cString.dropLast() + [.pathSeparator]
    }

    var flattened: Path {
        if basePathRef == nil {
            return self
        } else {
            return Path(concatenatedPath.dropLast() + [0], relativeTo: nil)
        }
    }

    public var description: String {
        let cString = flattened.cString
        return FileManager.default.string(
            withFileSystemRepresentation: cString,
            length: cString.count - 1
        )
    }

    func appending(_ other: [CChar]) -> Path {
        return Path(other, relativeTo: self)
    }
}

final class PathRef: Hashable, Sendable {
    let wrapped: Path
    init(_ path: Path) { self.wrapped = path }

    static func == (lhs: borrowing PathRef, rhs: borrowing PathRef) -> Bool {
        lhs.wrapped == rhs.wrapped
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(wrapped)
    }
}

extension CChar {
    static var pathSeparator: Self { return 47 }
}

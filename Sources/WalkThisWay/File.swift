import Foundation

public struct File: CustomStringConvertible {
    let dirEntry: DirEntry
    public let path: Path

    init(_ dirEntry: DirEntry, path: Path) {
        self.dirEntry = dirEntry
        self.path = path
    }

    public var size: Int { dirEntry.size ?? 0 }

    public var isRegularFile: Bool { dirEntry.type == .regularFile }
    public var isLink: Bool { dirEntry.type == .symbolicLink }

    public var description: String {
        "\(isLink ? " symbolic link" : String(format: "%14d", size)) \(path)"
    }
}


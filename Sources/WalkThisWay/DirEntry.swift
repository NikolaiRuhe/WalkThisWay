import Foundation
import Darwin

/// Information about an entry in the filesystem.
internal struct DirEntry: Sendable {
    var error: UInt32?
    var name: [CChar]
    var type: DirEntryType
    var fileID: UInt64?
    var crTime: timespec?
    var modTime: timespec?
    var accTime: timespec?
    var size: Int?
}

extension DirEntry: CustomStringConvertible {
    var description: String {
        "\(name, default: "<unknown>")\(type == .directory ? "/" : "")"
    }
}

enum DirEntryType: Sendable {
    case regularFile
    case directory
    case symbolicLink
    case other
}

extension DirEntryType {
    init(_ vtype: vtype) {
        switch vtype {
        case VREG: self = .regularFile
        case VDIR: self = .directory
        case VLNK: self = .symbolicLink
        default: self = .other
        }
    }
}

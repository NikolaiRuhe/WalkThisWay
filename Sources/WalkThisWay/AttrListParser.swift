import Foundation
public import Darwin

extension DirFileHandle {
    internal func enumerateContentsOfDirectory(
        options: attribute_set = .default,
        _ entryHandler: (DirEntry) -> Void,
    ) throws(POSIXError) {
        try WalkThisWay.enumerateContentsOfDirectory(
            at: self.fileDescriptor,
            options: options,
            entryHandler,
        )
    }
}

internal func enumerateContentsOfDirectory(
    at fileDescriptor: Int32,
    options: attribute_set = .default,
    _ entryHandler: (DirEntry) -> Void,
) throws(POSIXError) {
    try withUnsafeTemporaryAllocation(
        byteCount: bufferSize,
        alignment: 4
    ) { (buffer) throws(POSIXError) in
        var attributes = options.attrlist

        while true {
            let count = getattrlistbulk(
                fileDescriptor,
                &attributes,
                buffer.baseAddress!,
                buffer.count,
                UInt64(FSOPT_PACK_INVAL_ATTRS)
            )
            if count < 0 { throw POSIXError.errno }
            if count == 0 { break }

            var parser = AttrListParser(buffer.bytes)
            for _ in 0 ..< count {
                if let entry = parser.readDirEntry() {
                    entryHandler(entry)
                } else {
                    print("warning: could not read entry")
                }
            }
        }
    }
}

fileprivate let bufferSize = 64 * 1024

/// Enumerates contents of a directory. Wrapper around `getattrlistbulk`.
fileprivate struct AttrListParser: ~Escapable {
    let bytes: RawSpan
    var offset: Int

    @_lifetime(copy bytes)
    init(_ bytes: RawSpan, offset: Int = 0) {
        self.bytes = bytes
        self.offset = offset
    }

    // Only types that conform to ConvertibleFromBytes can be read safely.
    fileprivate mutating func read<T: ConvertibleFromBytes>(_ type: T.Type) -> T {
        defer { offset = offset + MemoryLayout<T>.stride }
        return bytes.load(fromByteOffset: offset, as: T.self)
    }

    fileprivate mutating func unsafeRead<T: BitwiseCopyable>(_ type: T.Type) -> T {
        defer { offset = offset + MemoryLayout<T>.stride }
        return bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: T.self)
    }

    @_lifetime(copy self)
    fileprivate mutating func readAttrRef() -> RawSpan {
        let base = offset
        let ref = unsafeRead(attrreference_t.self)
        let start = base + Int(ref.attr_dataoffset)
        let end = start + Int(ref.attr_length)
        return bytes.extracting(start ..< end)
    }

    fileprivate mutating func readFilename() -> [CChar] {
        Span<CChar>(viewing: readAttrRef()).withUnsafeBufferPointer {
            .init($0)
        }
    }

    fileprivate mutating func readDirEntry() -> DirEntry? {
        let newOffset = offset + Int(read(UInt32.self))
        defer { offset = newOffset }

        var dirEntry: DirEntry = .init(name: [], type: .other)
        let attrs = unsafeRead(attribute_set.self)
        if attrs.error   { dirEntry.error = read(UInt32.self) }

        guard attrs.name && attrs.objType else { return nil }
        dirEntry.name = readFilename()
        dirEntry.type = .init(vtype(read(fsobj_type_t.self)))

        if attrs.crTime  { dirEntry.crTime = unsafeRead(timespec.self) }
        if attrs.modTime { dirEntry.modTime = unsafeRead(timespec.self) }
        if attrs.accTime { dirEntry.accTime = unsafeRead(timespec.self) }
        if attrs.fileID  { dirEntry.fileID = read(UInt64.self) }
        if attrs.dataLength { dirEntry.size = Int(read(off_t.self)) }

        return dirEntry
    }
}

fileprivate extension attrgroup_t {
    func isSet(_ flag: Int32) -> Bool {
        self & attrgroup_t(flag) != 0
    }
    mutating func set(_ flag: Int32, to isSet: Bool) {
        if isSet {
            self |= attrgroup_t(flag)
        } else {
            self &= ~attrgroup_t(flag)
        }
    }
}

extension attribute_set {
    public static var `default`: Self {
        .init(
            commonattr: ATTR_CMN_RETURNED_ATTRS | attrgroup_t(ATTR_CMN_NAME) | attrgroup_t(ATTR_CMN_OBJTYPE),
            volattr: 0,
            dirattr: 0,
            fileattr: attrgroup_t(ATTR_FILE_DATALENGTH),
            forkattr: 0,
        )
    }

    public var error: Bool       {
        get { commonattr.isSet(ATTR_CMN_ERROR) }
    }
    public var name: Bool       {
        get { commonattr.isSet(ATTR_CMN_NAME) }
        set { commonattr.set(ATTR_CMN_NAME, to: newValue) }
    }
    public var objType: Bool    {
        get{ commonattr.isSet(ATTR_CMN_OBJTYPE) }
        set{ commonattr.set(ATTR_CMN_OBJTYPE, to: newValue) }
    }
    public var crTime: Bool     {
        get{ commonattr.isSet(ATTR_CMN_CRTIME) }
        set{ commonattr.set(ATTR_CMN_CRTIME, to: newValue) }
    }
    public var modTime: Bool    {
        get{ commonattr.isSet(ATTR_CMN_MODTIME) }
        set{ commonattr.set(ATTR_CMN_MODTIME, to: newValue) }
    }
    public var accTime: Bool    {
        get{ commonattr.isSet(ATTR_CMN_ACCTIME) }
        set{ commonattr.set(ATTR_CMN_ACCTIME, to: newValue) }
    }
    public var fileID: Bool     {
        get{ commonattr.isSet(ATTR_CMN_FILEID) }
        set{ commonattr.set(ATTR_CMN_FILEID, to: newValue) }
    }
    public var dataLength: Bool {
        get{ fileattr.isSet(ATTR_FILE_DATALENGTH) }
        set{ fileattr.set(ATTR_FILE_DATALENGTH, to: newValue) }
    }

    fileprivate var attrlist: attrlist {
        .init(
            bitmapcount: u_short(ATTR_BIT_MAP_COUNT),
            reserved: 0,
            commonattr: commonattr | ATTR_CMN_RETURNED_ATTRS,
            volattr: volattr,
            dirattr: dirattr,
            fileattr: fileattr,
            forkattr: forkattr,
        )
    }
}

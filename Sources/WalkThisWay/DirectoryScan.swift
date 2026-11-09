import Foundation
import Synchronization

final class DirectoryScan: Sendable, CustomStringConvertible {
    let path: Path
    let fileCount:        Atomic<Int> = .init(0)
    let logicalSize:      Atomic<Int> = .init(0)
    let dirCount:         Atomic<Int> = .init(0)
    let errorCount:       Atomic<Int> = .init(0)
    let overallTaskCount: Atomic<Int> = .init(0)
    let currentTaskCount: Mutex<Int> = .init(0)
    let maxParallelTasks: Int
    let quiet:            Bool

    let continuation: AsyncStream<Directory>.Continuation
    let directories: AsyncStream<Directory>

    init(_ path: Path, quiet: Bool = false, maxParallelTasks: Int) {
        let (stream, continuation) = AsyncStream<Directory>.makeStream()
        self.continuation = continuation
        self.directories = stream
        self.maxParallelTasks = maxParallelTasks
        self.quiet = quiet
        self.path = path
    }

    func traverse() async {
        spawnAsyncTraversal(Directory(path))

        await withDiscardingTaskGroup { group in
            for await directory in directories {
                group.addTask {
                    self.enumerate(directory)
                    self.finishTraversal()
                }
            }
        }
    }

    private func spawnAsyncTraversal(_ directory: Directory) {
        currentTaskCount.withLock { $0 += 1 }
        overallTaskCount.add(1, ordering: .relaxed)

        continuation.yield(directory)
    }

    private func finishTraversal() {
        let stillRunningCount = currentTaskCount
            .withLock { $0 -= 1; return $0 }

        if stillRunningCount == 0 {
            continuation.finish()
        }
    }

    private var shouldSpanNewTask: Bool {
        let currentTasks = currentTaskCount.withLock { $0 }
        return currentTasks < maxParallelTasks
    }

    private func enumerate(_ directory: Directory) {

        do {
            try directory.enumerateDirectories { subDirectory in
                dirCount.wrappingAdd(1, ordering: .relaxed)
                if shouldSpanNewTask {
                    spawnAsyncTraversal(subDirectory)
                } else {
                    enumerate(subDirectory)
                }
            } files: { file in
                fileCount.wrappingAdd(1, ordering: .relaxed)
                logicalSize.wrappingAdd(file.size, ordering: .relaxed)
                if !quiet {
                    print(file)
                }
            } errors: { path, error in
                print("warning: \(path): \(error.localizedDescription)")
                errorCount.wrappingAdd(1, ordering: .relaxed)
            }
        } catch {
            print("warning: \(directory.path): \(error.localizedDescription)")
            errorCount.wrappingAdd(1, ordering: .relaxed)
        }
    }

    var description: String {
        """
                    path: \(path)
             directories: \(dirCount.load(ordering: .relaxed))
                   files: \(fileCount.load(ordering: .relaxed))
            logical size: \(logicalSize.load(ordering: .relaxed).formatted(.byteCount(style: .memory, includesActualByteCount: true).locale(.standard)))
                  errors: \(errorCount.load(ordering: .relaxed))
        maxParallelTasks: \(maxParallelTasks)
        overallTaskCount: \(overallTaskCount.load(ordering: .relaxed))
        """
    }
}

extension Locale {
    static var standard: Self { Locale(identifier: "en_US_POSIX") }
}

extension Duration {
    var shortDescription: String {
        let units = Duration.UnitsFormatStyle(
            allowedUnits: [.seconds],
            width: .narrow,
            fractionalPart: .show(length: 3)
        ).locale(.standard)

        return self.formatted(units)
    }
}

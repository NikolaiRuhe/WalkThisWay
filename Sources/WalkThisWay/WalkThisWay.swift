import Foundation

@main
struct Main {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            throw CancellationError()
        }

        let root = Path(CommandLine.arguments[1])

        let scan = DirectoryScan(root, maxParallelTasks: 1)
        let duration = await ContinuousClock().measure {
            await scan.traverse()
        }

        print("\(scan)\n        duration: \(duration.shortDescription)")
    }
}

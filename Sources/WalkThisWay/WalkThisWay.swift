import Foundation

@main
struct Main {
    static func main() async throws {
        let args = try ArgParser()

        let scan = DirectoryScan(
            Path(args.path),
            quiet: args.isQuiet,
            maxParallelTasks: args.maxParallelTasks,
        )

        let duration = await ContinuousClock().measure {
            await scan.traverse()
        }

        print("\(scan)\n        duration: \(duration.shortDescription)")
    }
}

struct ArgParser {
    var isQuiet: Bool = false
    var path: String = "."
    var maxParallelTasks: Int = 1

    init() throws {
        var didReadPath = false
        for arg in CommandLine.arguments.dropFirst() {
            if arg == "-q" {
                self.isQuiet = true
            } else if !didReadPath {
                self.path = arg
                didReadPath = true
            } else if let count = Int(arg) {
                self.maxParallelTasks = count
            } else {
                throw CancellationError()
            }
        }

        if !didReadPath {
            throw CancellationError()
        }
    }
}

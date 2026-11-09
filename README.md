# WalkThisWay

... is a command line tool that uses `getattrlistbulk` to walk directory trees.
I've built it for educational purposes and to research the performance of
(parallel) file system traversal.

The code which parses the binary output of `getattrlistbulk` uses a `RawSpan`
view on the buffer and taught me about safe (and not so safe) raw memory access
using lifetime annotations.

To try it out:

```sh
swift run -c release WalkThisWay -q /Applications/Xcode.app 6
```

Output on my machine:

```
            path: /Applications/Xcode.app
     directories: 29960
           files: 137231
    logical size: 9.64 GB (10347616331 bytes)
          errors: 0
maxParallelTasks: 6
overallTaskCount: 6181
        duration: 0.618s
```

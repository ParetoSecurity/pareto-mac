//
//  ShellPathTests.swift
//  Pareto SecurityTests
//

@testable import Pareto_Security
import XCTest

/// Runs `body` on a background thread and waits. `DispatchQueue.global().sync`
/// would execute on the calling (main) thread.
func onBackgroundThread<T>(_ body: @escaping () -> T) -> T {
    var result: T?
    let done = DispatchSemaphore(value: 0)
    Thread {
        result = body()
        done.signal()
    }.start()
    done.wait()
    return result!
}

class ShellPathTests: XCTestCase {
    func testParseKeepsAbsoluteUniqueEntriesInOrder() {
        XCTAssertEqual(
            ShellPath.parse("/a/shims:/usr/bin::relative:/a/shims:/bin\n"),
            ["/a/shims", "/usr/bin", "/bin"]
        )
    }

    func testDirectoriesAreNilOutsideARunAndNeverResolve() {
        var calls = 0
        let shellPath = ShellPath(resolver: {
            calls += 1
            return ["/x"]
        })

        XCTAssertNil(shellPath.directories)
        XCTAssertEqual(calls, 0)
    }

    func testResolvesOncePerRunAndDropsCacheAtEnd() {
        var calls = 0
        let shellPath = ShellPath(resolver: {
            calls += 1
            return ["/run\(calls)"]
        })

        onBackgroundThread {
            shellPath.withRun {
                XCTAssertEqual(shellPath.directories, ["/run1"])
                // A nested run (single re-check during a scan) reuses the cache.
                shellPath.withRun {
                    XCTAssertEqual(shellPath.directories, ["/run1"])
                }
                XCTAssertEqual(shellPath.directories, ["/run1"])
            }
            XCTAssertNil(shellPath.directories)

            shellPath.withRun {
                XCTAssertEqual(shellPath.directories, ["/run2"])
            }
        }
        XCTAssertEqual(calls, 2)
    }

    func testMainThreadNeverTriggersResolution() {
        var calls = 0
        let shellPath = ShellPath(resolver: {
            calls += 1
            return ["/x"]
        })

        shellPath.withRun {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(shellPath.directories)
            onBackgroundThread {
                XCTAssertEqual(shellPath.directories, ["/x"])
            }
            // Once a background caller resolved it, the main thread reuses it.
            XCTAssertEqual(shellPath.directories, ["/x"])
        }
        XCTAssertEqual(calls, 1)
    }

    func testFailedResolutionIsCachedForTheRun() {
        var calls = 0
        let shellPath = ShellPath(resolver: {
            calls += 1
            return nil
        })

        onBackgroundThread {
            shellPath.withRun {
                XCTAssertNil(shellPath.directories)
                XCTAssertNil(shellPath.directories)
            }
        }
        XCTAssertEqual(calls, 1)
    }

    func testResolvesRealLoginShellPath() throws {
        let directories = try XCTUnwrap(ShellPath.resolveFromLoginShell())
        XCTAssertFalse(directories.isEmpty)
        XCTAssertTrue(directories.allSatisfy { ($0 as NSString).isAbsolutePath })
    }
}

//
//  CommandRunnerTests.swift
//  Pareto Security
//
//  Created by ArchitektApx on 11/11/2026.
//

import os
@testable import Pareto_Security
import XCTest

class CommandRunnerTests: XCTestCase {
    func testReturnsStandardOutput() throws {
        XCTAssertEqual(try runCMD(app: "/bin/echo", args: ["hello"]), "hello\n")
    }

    func testMergesStandardErrorByDefault() throws {
        let command = "echo out; echo err >&2"
        let merged = try runCMD(app: "/bin/sh", args: ["-c", command])
        XCTAssertTrue(merged.contains("out"))
        XCTAssertTrue(merged.contains("err"))

        let stdoutOnly = try runCMD(app: "/bin/sh", args: ["-c", command], includeStandardError: false)
        XCTAssertEqual(stdoutOnly, "out\n")
    }

    func testIgnoresExitStatusByDefault() throws {
        XCTAssertEqual(try runCMD(app: "/bin/sh", args: ["-c", "echo out; exit 1"]), "out\n")
    }

    func testAsyncTimesOutWhenBackgroundChildKeepsPipeOpen() async throws {
        let start = Date()
        do {
            _ = try await runCMDAsync(app: "/bin/sh", args: ["-c", "sleep 5 & echo x"], timeout: 0.5)
            XCTFail("The command must time out")
        } catch CommandRunnerError.timedOut {}
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testOutputIsCompleteUnderParallelLoad() {
        let incomplete = OSAllocatedUnfairLock(initialState: 0)
        DispatchQueue.concurrentPerform(iterations: 2000) { _ in
            if (try? runCMD(app: "/bin/sh", args: ["-c", "printf a; printf b >&2; printf c"])) != "abc" {
                incomplete.withLock { $0 += 1 }
            }
        }
        XCTAssertEqual(incomplete.withLock { $0 }, 0)
    }

    func testLargeOutputDoesNotDeadlock() throws {
        let output = try runCMD(app: "/bin/sh", args: ["-c", "head -c 200000 /dev/zero | tr '\\0' a"])
        XCTAssertEqual(output.count, 200_000)
    }

    func testAppliesEnvironmentAndDirectory() throws {
        let environment = try runCMD(app: "/usr/bin/env", args: [], environment: ["PARETO_TEST": "value"])
        XCTAssertEqual(environment, "PARETO_TEST=value\n")

        let directory = URL(fileURLWithPath: "/private/tmp")
        XCTAssertEqual(try runCMD(app: "/bin/pwd", args: [], directory: directory), "/private/tmp\n")
    }
}

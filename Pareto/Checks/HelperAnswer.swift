//
//  HelperAnswer.swift
//  Pareto Security
//
//  Created by Janez Troha on 24/11/2026.
//

import Foundation
import os.log

/// The privileged helper's answer for one check. A run waits for the helper, so it reports the
/// current answer, and an answer that lands after its run is stored and shown as soon as it does.
final class HelperAnswer: Sendable {
    /// How long a run or a report waits for the helper before it reports an error.
    let timeout: TimeInterval
    private let state = OSAllocatedUnfairLock(initialState: State())

    private struct State {
        /// Outer nil: the helper has not answered yet. Inner nil: its answer could not be evaluated.
        var answer: Bool??
        var inFlight = false
        var fetchStarted = Date.distantPast
        /// A report asked for the answer ahead of its run.
        var prefetchRequested = false
        /// The answer comes from prefetch() and the next run has not used it yet.
        var prefetched = false
        /// A run reported without the answer of the fetch it was waiting for.
        var publishWhenLanded = false
        var waiters: [@Sendable () -> Void] = []
    }

    init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    /// Asks the helper before a report runs, so the report does not print the stored result.
    /// `fetch` returns nil when the helper's output cannot be evaluated.
    func prefetch(for check: ParetoCheck, fetch: @escaping () async -> Bool?, completion: @escaping () -> Void) {
        let finished = OSAllocatedUnfairLock(initialState: false)
        let finish: @Sendable (_ landed: Bool) -> Void = { [state] landed in
            let first = finished.withLock { done in
                defer { done = true }
                return !done
            }
            guard first else { return }
            if !landed {
                state.withLock { $0.prefetchRequested = false }
            }
            completion()
        }
        state.withLock { $0.prefetchRequested = true }
        refresh(for: check, fetch: fetch) { finish(true) }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
    }

    /// The result for `checkPasses()`; sets the check's error state when the helper gave no usable answer.
    func passes(for check: ParetoCheck, fetch: @escaping () async -> Bool?) -> Bool {
        let usePrefetched = state.withLock { state in
            defer { state.prefetched = false }
            return state.prefetched
        }
        if !usePrefetched {
            let landed = DispatchSemaphore(value: 0)
            let started = refresh(for: check, fetch: fetch) { landed.signal() }
            let remaining = timeout - Date().timeIntervalSince(started)
            // The fetch hops to the main actor, so the main thread cannot wait for it
            if !Thread.isMainThread, remaining > 0 {
                _ = landed.wait(timeout: .now() + remaining)
            }
        }

        let (answer, pending, overdue) = state.withLock { state -> (Bool??, Bool, Bool) in
            guard state.inFlight else {
                return (state.answer, false, false)
            }
            // The answer is stored and shown as soon as it lands
            state.publishWhenLanded = true
            return (state.answer, true, Date().timeIntervalSince(state.fetchStarted) >= timeout)
        }
        if pending, overdue {
            os_log("%{public}s: no answer from the helper after %{public}.1f s", log: Log.check, check.UUID, timeout)
            check.hasError = true
            return false
        }
        // run() clears hasError before checkPasses(), so the error comes from the cached answer
        guard let answer else {
            return check.checkPassed
        }
        guard let passes = answer else {
            check.hasError = true
            return false
        }
        return passes
    }

    /// Calls `completion` when the helper has answered. Only one fetch runs at a time, so a helper
    /// that never answers is not asked again. Returns when the fetch that will answer was started.
    @discardableResult
    private func refresh(
        for check: ParetoCheck, fetch: @escaping () async -> Bool?, completion: @escaping @Sendable () -> Void
    ) -> Date {
        let (shouldStart, started) = state.withLock { state -> (Bool, Date) in
            state.waiters.append(completion)
            if state.inFlight {
                return (false, state.fetchStarted)
            }
            state.inFlight = true
            state.fetchStarted = Date()
            return (true, state.fetchStarted)
        }
        guard shouldStart else { return started }

        // Runs wait for this, so it must not run below their priority
        Task.detached(priority: .userInitiated) { [state] in
            let passes = await fetch()
            let (waiters, publish) = state.withLock { state -> ([@Sendable () -> Void], Bool) in
                defer {
                    state.waiters.removeAll()
                    state.publishWhenLanded = false
                    state.prefetchRequested = false
                }
                state.answer = .some(passes)
                state.inFlight = false
                state.prefetched = state.prefetchRequested
                return (state.waiters, state.publishWhenLanded)
            }
            waiters.forEach { $0() }
            if publish {
                // Waits for a run that is still storing its own result
                let late = LateResult(check: check)
                DispatchQueue.global(qos: .userInitiated).async {
                    late.check.publishLateResult(passes)
                }
            }
        }
        return started
    }
}

/// Carries the check to the queue that stores its late result; publishLateResult() takes the check's lock.
private struct LateResult: @unchecked Sendable {
    let check: ParetoCheck
}

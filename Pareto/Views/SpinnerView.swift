//
//  SpinnerView.swift
//  SpinnerView
//
//  Created by Janez Troha on 02/09/2021.
//

import SwiftUI

struct KeyframeAnimation: AnimatableModifier {
    typealias OnCompleteHandler = (Int) -> Void

    private let keyframe: Int
    private var progressiveKeyframe: Double
    private let onComplete: OnCompleteHandler

    init(keyframe: Double, onComplete: @escaping OnCompleteHandler) {
        self.keyframe = Int(keyframe)
        progressiveKeyframe = keyframe
        self.onComplete = onComplete
    }

    var animatableData: Double {
        get { progressiveKeyframe }
        set {
            progressiveKeyframe = newValue
            if Int(progressiveKeyframe) == keyframe {
                onComplete(keyframe)
            }
        }
    }

    func body(content: Content) -> some View {
        content
    }
}

enum TimingFunction {
    case timingCurve(c0x: Double, c0y: Double, c1x: Double, c1y: Double)
    case linear
    case easeInOut

    func animation(duration: Double) -> Animation {
        switch self {
        case let .timingCurve(c0x, c0y, c1x, c1y):
            return .timingCurve(c0x, c0y, c1x, c1y, duration: duration)
        case .linear:
            return .linear(duration: duration)
        case .easeInOut:
            return .easeInOut(duration: duration)
        }
    }
}

class KeyframeIterator: IteratorProtocol {
    typealias Element = (Int, Animation, Animation?, Bool)

    private let beginTime: Double
    private let duration: Double
    private let timingFunctions: [TimingFunction]
    private let keyTimes: [Double]
    private let durations: [Double]
    private let animations: [Animation]
    private var keyframe: Int = 0
    private var isRepeating = false

    init(beginTime: Double,
         duration: Double,
         timingFunctions: [TimingFunction],
         keyTimes: [Double]) {
        self.beginTime = beginTime
        self.duration = duration
        self.timingFunctions = timingFunctions
        self.keyTimes = keyTimes

        assert(keyTimes.count - timingFunctions.count == 1)

        let keyPercents = zip(keyTimes[0 ..< keyTimes.count - 1], keyTimes[1...])
            .map { $1 - $0 }
        let durations = keyPercents.map { duration * $0 }

        self.durations = durations + [0]
        animations = zip(durations, timingFunctions).map { duration, timingFunction in
            timingFunction.animation(duration: duration)
        }
    }

    func next() -> Element? {
        let isFirst = keyframe == 0
        let isLast = keyframe == keyTimes.count - 1
        let delay = isFirst && !isRepeating ? beginTime : 0
        let keyframeTracker = Animation.linear(duration: durations[keyframe]).delay(delay)
        let animation = isLast ? nil : animations[keyframe].delay(delay)
        let nextKeyframe = isLast ? 0 : keyframe + 1
        let element: Element = (nextKeyframe, keyframeTracker, animation, isLast)

        if isLast {
            isRepeating = true
        }
        keyframe = nextKeyframe

        return element
    }
}

struct KeyframeAnimationController<T: View>: View {
    typealias Content = (Int) -> T

    @State private var keyframe: Double = 0
    @State private var animation: Animation?
    private let beginTime: Double
    private let duration: Double
    private let timingFunctions: [TimingFunction]
    private let keyTimes: [Double]
    private let keyframeIterator: KeyframeIterator
    private var content: Content

    var body: some View {
        content(Int(keyframe))
            .animation(animation)
            .modifier(KeyframeAnimation(keyframe: self.keyframe, onComplete: handleComplete))
            .onAppear {
                self.nextKeyframe()
            }
    }

    init(beginTime: Double,
         duration: Double,
         timingFunctions: [TimingFunction],
         keyTimes: [Double],
         content: @escaping Content) {
        self.beginTime = beginTime
        self.duration = duration
        self.timingFunctions = timingFunctions
        self.keyTimes = keyTimes
        keyframeIterator = KeyframeIterator(beginTime: beginTime,
                                            duration: duration,
                                            timingFunctions: timingFunctions,
                                            keyTimes: keyTimes)
        self.content = content
    }

    private func handleComplete(_: Int) {
        nextKeyframe()
    }

    private func nextKeyframe() {
        DispatchQueue.main.async {
            guard let data = self.keyframeIterator.next() else {
                return
            }

            let (keyframe, keyframeTracker, animation, _) = data

            self.animation = animation
            withAnimation(keyframeTracker) {
                self.keyframe = Double(keyframe)
            }
        }
    }
}

private struct SemiCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let dimension = min(rect.size.width, rect.size.height)
        var path = Path()

        path.addArc(center: CGPoint(x: dimension / 2, y: dimension / 2),
                    radius: dimension / 2,
                    startAngle: Angle(radians: 7 * .pi / 6),
                    endAngle: Angle(radians: 11 * .pi / 6),
                    clockwise: false)

        return path
    }
}

public struct SemiCircleSpin: View {
    private let duration = 0.6
    private let timingFunction = TimingFunction.linear
    private let keyTimes = [0, 1.0]
    private let value = [0, 2 * Double.pi]

    public var body: some View {
        GeometryReader(content: render)
    }

    public init() {}

    func render(geometry: GeometryProxy) -> some View {
        let dimension = min(geometry.size.width, geometry.size.height)
        let timingFunctions = Array(repeating: timingFunction, count: keyTimes.count - 1)

        return KeyframeAnimationController(beginTime: 0,
                                           duration: duration,
                                           timingFunctions: timingFunctions,
                                           keyTimes: keyTimes) {
            SemiCircle()
                .rotation(Angle(radians: self.value[$0]))
        }
        .frame(width: dimension, height: dimension, alignment: .center)
    }
}

struct SemiCircleSpin_Previews: PreviewProvider {
    static var previews: some View {
        SemiCircleSpin()
    }
}

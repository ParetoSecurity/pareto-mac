//
//  NetworkHandler.swift
//  Pareto Security
//
//  Created by Janez Troha on 28/09/2021.
//

import Foundation
import Network

protocol NetworkHandlerObserver: AnyObject {
    func statusDidChange(status: NWPath.Status)
}

class NetworkHandler {
    struct NetworkHandlerObservation {
        weak var observer: NetworkHandlerObserver?
    }

    /// NWPathMonitor instance
    private var monitor = NWPathMonitor()

    /// NetworkHandler shared instance
    private static let _sharedInstance = NetworkHandler()

    /// Observer collection
    private var observers = [ObjectIdentifier: NetworkHandlerObservation]()

    /// Current NWPathMonitor Status
    var currentStatus: NWPath.Status {
        return monitor.currentPath.status
    }

    class func sharedInstance() -> NetworkHandler {
        return _sharedInstance
    }

    init() {
        monitor.pathUpdateHandler = { [unowned self] path in
            /// Initialise observers
            for (id, observations) in self.observers {
                /// If any observer is nil, remove it from the list of observers
                guard let observer = observations.observer else {
                    self.observers.removeValue(forKey: id)
                    continue
                }

                /// Async execution of statusDidChange
                DispatchQueue.main.async {
                    observer.statusDidChange(status: path.status)
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }

    /// Add Observer
    func addObserver(observer: NetworkHandlerObserver) {
        let id = ObjectIdentifier(observer)
        observers[id] = NetworkHandlerObservation(observer: observer)
    }

    /// Remove Observer
    func removeObserver(observer: NetworkHandlerObserver) {
        let id = ObjectIdentifier(observer)
        observers.removeValue(forKey: id)
    }
}

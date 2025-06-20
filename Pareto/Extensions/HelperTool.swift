//
//  HelperTool.swift
//  Pareto Security
//
//  Created by Janez Troha on 23. 5. 25.
//

import os.log
import ServiceManagement

enum HelperToolAction {
    case none // Only check status
    case install // Install the helper tool
    case uninstall // Uninstall the helper tool
}

// Static helper utility functions (not actor-isolated)
class HelperToolUtilities {
    // Static method to check helper tool status without actor isolation
    static func isHelperInstalled() -> Bool {
        let plistName = "co.niteo.ParetoSecurityHelper.plist"
        let service = SMAppService.daemon(plistName: plistName)
        return service.status == .enabled
    }

    // Static method to compare version strings (semantic versioning)
    static func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1Components = version1.components(separatedBy: ".").compactMap { Int($0) }
        let v2Components = version2.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0
            
            if v1Value < v2Value {
                return .orderedAscending
            } else if v1Value > v2Value {
                return .orderedDescending
            }
        }
        
        return .orderedSame
    }

    // Static method to check if helper needs updating
    static func helperNeedsUpdate(currentVersion: String, expectedVersion: String) -> Bool {
        return compareVersions(currentVersion, expectedVersion) == .orderedAscending
    }

    // Manual version counter - increment this when helper needs updating
    static let expectedHelperVersion = "1.0.3"
    
    // Static method to get expected helper version (manual counter)
    static func getExpectedHelperVersion() -> String {
        return expectedHelperVersion
    }
}

@MainActor
class HelperToolManager: ObservableObject {

    private var helperConnection: NSXPCConnection?
    let helperToolIdentifier = "co.niteo.ParetoSecurityHelper"
    @Published var isHelperToolInstalled: Bool = false
    @Published var message: String = "Checking..."
    var status: String {
        return isHelperToolInstalled ? "Registered" : "Not Registered"
    }

    init() {
        Task {
            await manageHelperTool()
        }
    }

    // Function to manage the helper tool installation/uninstallation
    func manageHelperTool(action: HelperToolAction = .none) async {
        let plistName = "\(helperToolIdentifier).plist"
        let service = SMAppService.daemon(plistName: plistName)
        var occurredError: NSError?

        // Perform install/uninstall actions if specified
        switch action {
        case .install:
            // Pre-check before registering
            switch service.status {
            case .requiresApproval:
                message = "Registered but requires enabling in System Settings > Login Items."
                SMAppService.openSystemSettingsLoginItems()
            case .enabled:
                message = "Service is already enabled."
            default:
                do {
                    try service.register()
                    if service.status == .requiresApproval {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                } catch let nsError as NSError {
                    occurredError = nsError
                    if nsError.code == 1 { // Operation not permitted
                        message = "Permission required. Enable in System Settings > Login Items."
                        SMAppService.openSystemSettingsLoginItems()
                    } else {
                        message = "Installation failed: \(nsError.localizedDescription)"
                        print("Failed to register helper: \(nsError.localizedDescription)")
                    }
                }
            }

        case .uninstall:
            do {
                try await service.unregister()
                // Close any existing connection
                helperConnection?.invalidate()
                helperConnection = nil
            } catch let nsError as NSError {
                occurredError = nsError
                print("Failed to unregister helper: \(nsError.localizedDescription)")
            }

        case .none:
            break
        }

        updateStatusMessages(with: service, occurredError: occurredError)
        isHelperToolInstalled = (service.status == .enabled)
    }

    // Function to open Settings > Login Items
    func openSMSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // Function to run privileged commands
    func isFirewallEnabled(completion: @escaping (String) -> Void) async {
        if !HelperToolUtilities.isHelperInstalled() {
            os_log("XPC: Helper tool is not installed")
            completion("XPC: Helper tool is not installed")
            return
        }

        guard let connection = getConnection() else {
            os_log("XPC: Connection not available")
            completion("XPC: Connection not available")
            return
        }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            DispatchQueue.main.async {
                os_log("XPC: Connection error: \(error.localizedDescription)")
                completion("XPC: Connection error: \(error.localizedDescription)")
            }
        }) as? ParetoSecurityHelperProtocol else {
            os_log("XPC: Failed to get remote object")
            completion("XPC: Failed to get remote object")
            return
        }

        proxy.isFirewallEnabled(with: { output in
            DispatchQueue.main.async {
                completion(output)
            }
        })
    }

    // Function to run privileged commands
    func isFirewallStealthEnabled(completion: @escaping (String) -> Void) async {
        if !HelperToolUtilities.isHelperInstalled() {
            os_log("XPC: Helper tool is not installed")
            completion("XPC: Helper tool is not installed")
            return
        }

        guard let connection = getConnection() else {
            os_log("XPC: Connection not available")
            completion("XPC: Connection not available")
            return
        }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            DispatchQueue.main.async {
                os_log("XPC: Connection error: \(error.localizedDescription)")
                completion("XPC: Connection error: \(error.localizedDescription)")
            }
        }) as? ParetoSecurityHelperProtocol else {
            os_log("XPC: Failed to get remote object")
            completion("XPC: Failed to get remote object")
            return
        }

        proxy.isFirewallStealthEnabled(with: { output in
            DispatchQueue.main.async {
                completion(output)
            }
        })
    }

    // Function to get helper tool version
    func getHelperVersion(completion: @escaping (String) -> Void) async {
        if !HelperToolUtilities.isHelperInstalled() {
            os_log("XPC: Helper tool is not installed")
            completion("Not installed")
            return
        }

        guard let connection = getConnection() else {
            os_log("XPC: Connection not available")
            completion("Connection unavailable")
            return
        }

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            DispatchQueue.main.async {
                os_log("XPC: Connection error: \(error.localizedDescription)")
                completion("Connection error")
            }
        }) as? ParetoSecurityHelperProtocol else {
            os_log("XPC: Failed to get remote object")
            completion("Connection failed")
            return
        }

        proxy.getVersion(with: { version in
            DispatchQueue.main.async {
                completion(version)
            }
        })
    }

    // Function to check and update helper if needed
    func ensureHelperIsUpToDate() async -> Bool {
        let expectedVersion = HelperToolUtilities.getExpectedHelperVersion()
        
        // If helper is not installed, install it
        guard HelperToolUtilities.isHelperInstalled() else {
            os_log("Helper not installed, installing version %{public}s", expectedVersion)
            await manageHelperTool(action: .install)
            return HelperToolUtilities.isHelperInstalled()
        }

        // Get current helper version using async/await
        let currentVersion = await withCheckedContinuation { continuation in
            Task {
                await getHelperVersion { version in
                    continuation.resume(returning: version)
                }
            }
        }

        // Check if update is needed
        if HelperToolUtilities.helperNeedsUpdate(currentVersion: currentVersion, expectedVersion: expectedVersion) {
            os_log("Helper version %{public}s is outdated, updating to %{public}s", currentVersion, expectedVersion)
            await manageHelperTool(action: .uninstall)
            await manageHelperTool(action: .install)
            return HelperToolUtilities.isHelperInstalled()
        }

        os_log("Helper version %{public}s is up to date", currentVersion)
        return true
    }

    // Create/reuse XPC connection
    private func getConnection() -> NSXPCConnection? {
        if let connection = helperConnection {
            return connection
        }
        let connection = NSXPCConnection(machServiceName: helperToolIdentifier, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: ParetoSecurityHelperProtocol.self)
        connection.invalidationHandler = { [weak self] in
            self?.helperConnection = nil
        }
        connection.resume()
        helperConnection = connection
        return connection
    }

    // Helper to update helper status messages
    func updateStatusMessages(with service: SMAppService, occurredError: NSError?) {
        if let nsError = occurredError {
            switch nsError.code {
            case kSMErrorAlreadyRegistered:
                message = "Service is already registered and enabled."
            case kSMErrorLaunchDeniedByUser:
                message = "User denied permission. Enable in System Settings > Login Items."
            case kSMErrorInvalidSignature:
                message = "Invalid signature, ensure proper signing on the application and helper tool."
            case 1:
                message = "Authorization required in Settings > Login Items."
            default:
                message = "Operation failed: \(nsError.localizedDescription)"
            }
        } else {
            switch service.status {
            case .notRegistered:
                message = "Service hasn’t been registered. You may register it now."
            case .enabled:
                message = "Service successfully registered and eligible to run."
            case .requiresApproval:
                message = "Service registered but requires user approval in Settings > Login Items."
            case .notFound:
                message = "Service is not installed."
            @unknown default:
                message = "Unknown service status (\(service.status))."
            }
        }
    }
}

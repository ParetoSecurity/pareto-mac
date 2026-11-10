//
//  IgnoredFirewallAppsSettingsView.swift
//  Pareto Security
//
//  Created by ArchitektApx on 06/11/2026.
//

import AppKit
import Defaults
import Foundation
import SwiftUI

@MainActor
final class IgnoredFirewallAppsViewModel: ObservableObject {
    @Published var exceptions: [FirewallExceptionsCheck.Exception] = []
    @Published var isLoading = false
    @Published var loadFailed = false
    @Published var showRerunNotice = false

    var needsReview: [FirewallExceptionsCheck.Exception] {
        exceptions.filter { $0.trust == nil }
    }

    var allowedByUser: [FirewallExceptionsCheck.Exception] {
        exceptions.filter { $0.trust == .user }
    }

    var trustedAutomatically: [FirewallExceptionsCheck.Exception] {
        exceptions.filter { $0.trust == .apple || $0.trust == .appStore || $0.trust == .notInstalled }
    }

    func load() async {
        if isLoading {
            return
        }
        isLoading = true
        let result = await Task.detached(priority: .userInitiated) {
            FirewallExceptionsCheck().evaluate()
        }.value
        exceptions = result ?? []
        loadFailed = result == nil
        isLoading = false
    }

    func allow(_ exception: FirewallExceptionsCheck.Exception) async {
        var list = Defaults[.ignoredFirewallApps]
        if !list.contains(exception.bundle) {
            list.append(exception.bundle)
            Defaults[.ignoredFirewallApps] = list.sorted()
        }
        showRerunNotice = true
        await load()
    }

    func revoke(_ exception: FirewallExceptionsCheck.Exception) async {
        Defaults[.ignoredFirewallApps] = Defaults[.ignoredFirewallApps].filter { entry in
            !exception.paths.contains { FirewallExceptionsCheck.isCovered($0, by: [entry]) }
        }
        showRerunNotice = true
        await load()
    }
}

struct IgnoredFirewallAppsSettingsView: View {
    @StateObject private var model: IgnoredFirewallAppsViewModel
    @State private var showTrusted: Bool
    private let loadsOnAppear: Bool

    init(model: IgnoredFirewallAppsViewModel? = nil, showTrusted: Bool = false) {
        _model = StateObject(wrappedValue: model ?? IgnoredFirewallAppsViewModel())
        _showTrusted = State(initialValue: showTrusted)
        loadsOnAppear = model == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.showRerunNotice {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundColor(.orange)
                    Text("Allowed apps updated. Rerun checks to refresh the report.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") { model.showRerunNotice = false }.buttonStyle(.link)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }

            if model.isLoading, model.exceptions.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading firewall settings…").font(.caption).foregroundColor(.secondary)
                }
            } else if model.loadFailed {
                Label("Could not read the firewall app list.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                needsReviewSection
                if !model.allowedByUser.isEmpty {
                    section(title: "Allowed by you") {
                        ForEach(model.allowedByUser) { exception in
                            FirewallAppRow(exception: exception) {
                                Button("Remove") { Task { await model.revoke(exception) } }
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                if !model.trustedAutomatically.isEmpty {
                    DisclosureGroup(isExpanded: $showTrusted) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(model.trustedAutomatically) { exception in
                                FirewallAppRow(exception: exception) {
                                    TrustBadge(trust: exception.trust)
                                }
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Text("Trusted automatically (\(model.trustedAutomatically.count))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text("Apple's own apps, App Store apps and entries for removed apps are trusted automatically. "
                + "Script interpreters such as "
                + "Python or Ruby always need your review. Manage the list in System Settings > Network > "
                + "Firewall > Options.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task {
            if loadsOnAppear {
                await model.load()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runChecksFinished)) { _ in
            Task { await model.load() }
        }
    }

    @ViewBuilder
    private var needsReviewSection: some View {
        if model.needsReview.isEmpty {
            Label("No apps need your review.", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundColor(.green)
        } else {
            section(title: "Needs review (\(model.needsReview.count))") {
                ForEach(model.needsReview) { exception in
                    FirewallAppRow(exception: exception) {
                        Button("Allow") { Task { await model.allow(exception) } }
                            .controlSize(.small)
                            .help("Keep accepting incoming connections for this app without failing the check")
                    }
                }
            }
        }
    }

    private func section(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            content()
        }
    }
}

private struct FirewallAppRow<Accessory: View>: View {
    let exception: FirewallExceptionsCheck.Exception
    @ViewBuilder let accessory: () -> Accessory

    private var name: String {
        let display = FileManager.default.displayName(atPath: exception.bundle)
        return display.hasSuffix(".app") ? String(display.dropLast(4)) : display
    }

    private var helperNote: String? {
        let helpers = FirewallExceptionsCheck.helpers(of: exception).count
        guard helpers > 0 else { return nil }
        if helpers == exception.paths.count {
            return helpers == 1 ? "through a helper" : "through \(helpers) helpers"
        }
        return helpers == 1 ? "and 1 helper" : "and \(helpers) helpers"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: exception.bundle))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(.system(size: 13, weight: .medium))
                    if let helperNote {
                        Text(helperNote).font(.caption2).foregroundColor(.secondary)
                    }
                }
                Text(exception.bundle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(exception.paths.joined(separator: "\n"))
            }
            Spacer(minLength: 8)
            accessory()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(exception.bundle, inFileViewerRootedAtPath: "")
            }
        }
    }
}

private struct TrustBadge: View {
    let trust: FirewallExceptionsCheck.Trust?

    private var label: String {
        switch trust {
        case .apple: "Apple"
        case .appStore: "App Store"
        case .notInstalled: "Removed"
        default: ""
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(4)
    }
}

struct IgnoredFirewallAppsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        IgnoredFirewallAppsSettingsView()
    }
}

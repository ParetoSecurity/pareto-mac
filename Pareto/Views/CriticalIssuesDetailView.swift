//
//  CriticalIssuesDetailView.swift
//  Pareto Security
//
//  Created by Claude on 04/12/2025.
//

import AppKit
import SwiftUI

struct CriticalIssuesDetailView: View {
    @ObservedObject private var failureStore = HTTPFailureStore.shared
    @State private var selectedFailure: FailedRequest?
    @State private var copiedToClipboard = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            if failureStore.failures.isEmpty {
                emptyStateView
            } else {
                HSplitView {
                    // Left panel - list of failures
                    failureListView
                        .frame(minWidth: 200, maxWidth: 250)

                    // Right panel - failure details
                    if let failure = selectedFailure ?? failureStore.latestFailure {
                        failureDetailView(failure: failure)
                    } else {
                        Text("Select a request to view details")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            selectedFailure = failureStore.latestFailure
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.red)

            VStack(alignment: .leading) {
                Text("Network Issues")
                    .font(.headline)
                Text("\(failureStore.failureCount) request(s) failed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Copy All") {
                let allLogs = failureStore.failures.map { $0.fullLog }.joined(separator: "\n\n---\n\n")
                copyToClipboard(allLogs)
            }
            .disabled(failureStore.failures.isEmpty)

            Button("Clear All") {
                failureStore.clear()
                selectedFailure = nil
            }
            .disabled(failureStore.failures.isEmpty)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("No Network Issues")
                .font(.headline)
            Text("All requests are completing successfully")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failureListView: some View {
        List(failureStore.failures, selection: $selectedFailure) { failure in
            VStack(alignment: .leading, spacing: 4) {
                Text(failure.method)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(urlHost(failure.url))
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)

                HStack {
                    if let status = failure.statusCode {
                        Text("HTTP \(status)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(statusColor(status).opacity(0.2))
                            .foregroundColor(statusColor(status))
                            .cornerRadius(4)
                    }

                    Text(failure.formattedTimestamp)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            .tag(failure)
        }
    }

    private func failureDetailView(failure: FailedRequest) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Error summary
                GroupBox(label: Label("Error", systemImage: "exclamationmark.circle")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(failure.errorMessage)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)

                        if let code = failure.errorCode {
                            Text("Error code: \(code)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                // Troubleshooting suggestions
                GroupBox(label: Label("Suggestions", systemImage: "lightbulb")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(failure.troubleshootingSuggestions, id: \.self) { suggestion in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(suggestion)
                            }
                            .font(.callout)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                // Request details
                GroupBox(label: Label("Request", systemImage: "arrow.up.circle")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(failure.method)
                                .fontWeight(.semibold)
                            Text(failure.url)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }

                        if !failure.requestHeaders.isEmpty {
                            Divider()
                            Text("Headers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(failure.requestHeaders.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack(alignment: .top) {
                                    Text(key + ":")
                                        .fontWeight(.medium)
                                    Text(value)
                                        .textSelection(.enabled)
                                }
                                .font(.system(.caption, design: .monospaced))
                            }
                        }

                        if let body = failure.requestBody, !body.isEmpty {
                            Divider()
                            Text("Body")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(body)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                // Response details (if available)
                if failure.statusCode != nil || failure.responseHeaders != nil || failure.responseBody != nil {
                    GroupBox(label: Label("Response", systemImage: "arrow.down.circle")) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let status = failure.statusCode {
                                HStack {
                                    Text("Status:")
                                        .fontWeight(.medium)
                                    Text("\(status)")
                                        .foregroundColor(statusColor(status))
                                }
                            }

                            if let headers = failure.responseHeaders, !headers.isEmpty {
                                Divider()
                                Text("Headers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                    HStack(alignment: .top) {
                                        Text(key + ":")
                                            .fontWeight(.medium)
                                        Text(value)
                                            .textSelection(.enabled)
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                }
                            }

                            if let body = failure.responseBody, !body.isEmpty {
                                Divider()
                                Text("Body")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(body)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }

                // Copy button
                HStack {
                    Spacer()
                    Button {
                        copyToClipboard(failure.fullLog)
                    } label: {
                        Label(copiedToClipboard ? "Copied!" : "Copy Full Log", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                    }
                }
            }
            .padding()
        }
    }

    private func urlHost(_ urlString: String) -> String {
        if let url = URL(string: urlString) {
            return url.host ?? urlString
        }
        return urlString
    }

    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 200 ..< 300:
            return .green
        case 400 ..< 500:
            return .orange
        case 500 ..< 600:
            return .red
        default:
            return .secondary
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedToClipboard = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}

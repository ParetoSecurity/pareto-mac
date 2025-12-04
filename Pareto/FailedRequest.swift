//
//  FailedRequest.swift
//  Pareto Security
//
//  Created by Claude on 04/12/2025.
//

import Foundation

struct FailedRequest: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let url: String
    let method: String
    let statusCode: Int?
    let errorMessage: String
    let errorCode: Int?
    let requestHeaders: [String: String]
    let requestBody: String?
    let responseHeaders: [String: String]?
    let responseBody: String?

    init(
        url: String,
        method: String,
        statusCode: Int? = nil,
        errorMessage: String,
        errorCode: Int? = nil,
        requestHeaders: [String: String] = [:],
        requestBody: String? = nil,
        responseHeaders: [String: String]? = nil,
        responseBody: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.url = url
        self.method = method
        self.statusCode = statusCode
        self.errorMessage = errorMessage
        self.errorCode = errorCode
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
    }

    var troubleshootingSuggestions: [String] {
        var suggestions: [String] = []

        // Check for network connectivity errors
        if let code = errorCode {
            switch code {
            case -1009: // NSURLErrorNotConnectedToInternet
                suggestions.append("Check your internet connection")
                suggestions.append("Try connecting to a different network")
            case -1001: // NSURLErrorTimedOut
                suggestions.append("Server may be temporarily unavailable")
                suggestions.append("Try again in a few minutes")
            case -1003, -1006: // NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed
                suggestions.append("Check your DNS settings")
                suggestions.append("Try using 8.8.8.8 or 1.1.1.1 as DNS")
            case -1200 ... -1202: // SSL errors
                suggestions.append("Check your date and time settings")
                suggestions.append("Corporate firewall may be interfering")
                suggestions.append("Try disabling VPN temporarily")
            case -1005: // NSURLErrorNetworkConnectionLost
                suggestions.append("Network connection was lost")
                suggestions.append("Check your WiFi or ethernet connection")
            default:
                break
            }
        }

        // Check for HTTP status code errors
        if let status = statusCode {
            switch status {
            case 401, 403:
                suggestions.append("Re-enroll your device with the team")
                suggestions.append("Check team enrollment status")
            case 404:
                suggestions.append("Device may have been removed from team")
                suggestions.append("Contact your administrator")
            case 429:
                suggestions.append("Too many requests - wait a few minutes")
            case 500 ... 599:
                suggestions.append("Server is experiencing issues")
                suggestions.append("Try again later")
            default:
                break
            }
        }

        // Generic suggestions if no specific ones matched
        if suggestions.isEmpty {
            suggestions.append("Check your internet connection")
            suggestions.append("Try disabling VPN temporarily")
            suggestions.append("Check firewall settings")
        }

        return suggestions
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    var fullLog: String {
        var log = """
        === Request Failed ===
        Time: \(formattedTimestamp)
        URL: \(url)
        Method: \(method)
        """

        if let status = statusCode {
            log += "\nStatus Code: \(status)"
        }

        log += "\nError: \(errorMessage)"

        if let code = errorCode {
            log += "\nError Code: \(code)"
        }

        if !requestHeaders.isEmpty {
            log += "\n\n--- Request Headers ---"
            for (key, value) in requestHeaders.sorted(by: { $0.key < $1.key }) {
                log += "\n\(key): \(value)"
            }
        }

        if let body = requestBody, !body.isEmpty {
            log += "\n\n--- Request Body ---\n\(body)"
        }

        if let headers = responseHeaders, !headers.isEmpty {
            log += "\n\n--- Response Headers ---"
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                log += "\n\(key): \(value)"
            }
        }

        if let body = responseBody, !body.isEmpty {
            log += "\n\n--- Response Body ---\n\(body)"
        }

        return log
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FailedRequest, rhs: FailedRequest) -> Bool {
        lhs.id == rhs.id
    }
}

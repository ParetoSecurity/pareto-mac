import Alamofire
import Foundation
import os

private let subsystem = "niteo.co.Pareto"

enum Log {
    static let app = OSLog(subsystem: subsystem, category: "App")
    static let check = OSLog(subsystem: subsystem, category: "Check")
    static let api = OSLog(subsystem: subsystem, category: "API")
}

final class NetworkEventLogger: EventMonitor {
    let queue = DispatchQueue(label: "co.pareto.network.logger")
    private let maxBodyLength = 4000
    private let redactedHeaders = Set([
        "authorization",
        "cookie",
        "set-cookie",
        "x-device-auth",
    ])

    func requestDidResume(_ request: Request) {
        guard let urlRequest = request.request else {
            os_log("HTTP request started without URLRequest: %{public}@", log: Log.api, request.description)
            return
        }

        os_log(
            "HTTP request started [%{public}@] %{public}@",
            log: Log.api,
            urlRequest.httpMethod ?? "UNKNOWN",
            urlRequest.url?.absoluteString ?? "unknown-url"
        )

        let headers = sanitizedHeaders(urlRequest.headers)
        if !headers.isEmpty {
            os_log("HTTP request headers: %{public}@", log: Log.api, headers)
        }

        if let body = formattedBody(from: urlRequest.httpBody) {
            os_log("HTTP request body: %{public}@", log: Log.api, body)
        }
    }

    func request<Value: Sendable>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        logResponse(
            request: request.request,
            statusCode: response.response?.statusCode,
            headers: response.response?.headers,
            data: response.data,
            error: response.error
        )
    }

    func request<Value: Sendable>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value, AFError>) {
        logResponse(
            request: request.request,
            statusCode: response.response?.statusCode,
            headers: response.response?.headers,
            data: nil,
            error: response.error
        )
    }

    private func logResponse(
        request: URLRequest?,
        statusCode: Int?,
        headers: HTTPHeaders?,
        data: Data?,
        error: AFError?
    ) {
        os_log(
            "HTTP response received [%{public}@] %{public}@ status=%{public}d error=%{public}@",
            log: Log.api,
            request?.httpMethod ?? "UNKNOWN",
            request?.url?.absoluteString ?? "unknown-url",
            statusCode ?? -1,
            error?.localizedDescription ?? "none"
        )

        if let headers, !headers.isEmpty {
            os_log("HTTP response headers: %{public}@", log: Log.api, sanitizedHeaders(headers))
        }

        if let body = formattedBody(from: data) {
            os_log("HTTP response body: %{public}@", log: Log.api, body)
        }
    }

    private func sanitizedHeaders(_ headers: HTTPHeaders) -> String {
        headers.map { header in
            let value = redactedHeaders.contains(header.name.lowercased()) ? "<redacted>" : header.value
            return "\(header.name): \(value)"
        }
        .joined(separator: ", ")
    }

    private func formattedBody(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }

        let text = String(data: data, encoding: .utf8) ?? data.base64EncodedString()
        if text.count <= maxBodyLength {
            return text
        }

        return String(text.prefix(maxBodyLength)) + "... [truncated]"
    }
}

enum Network {
    static let logger = NetworkEventLogger()
    static let session = Session(eventMonitors: [logger])
}

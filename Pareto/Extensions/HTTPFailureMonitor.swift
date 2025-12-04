//
//  HTTPFailureMonitor.swift
//  Pareto Security
//
//  Created by Claude on 04/12/2025.
//

import Alamofire
import Foundation
import os.log

final class HTTPFailureMonitor: EventMonitor {
    let queue = DispatchQueue(label: "co.niteo.Pareto.HTTPFailureMonitor", qos: .utility)

    func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: AFError?) {
        guard let error = error else { return }

        let urlString = task.originalRequest?.url?.absoluteString ?? "Unknown URL"
        let method = task.originalRequest?.httpMethod ?? "Unknown"

        os_log("Request failed: %{public}@ %{public}@", log: Log.network, method, urlString)

        // Extract request details
        var requestHeaders: [String: String] = [:]
        if let headers = task.originalRequest?.allHTTPHeaderFields {
            requestHeaders = headers
        }

        var requestBody: String?
        if let bodyData = task.originalRequest?.httpBody {
            requestBody = String(data: bodyData, encoding: .utf8)
        }

        // Extract response details
        var statusCode: Int?
        var responseHeaders: [String: String]?
        if let httpResponse = task.response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
            responseHeaders = httpResponse.allHeaderFields as? [String: String]
        }

        // Get underlying error code
        var errorCode: Int?
        if let urlError = error.underlyingError as? URLError {
            errorCode = urlError.errorCode
        }

        let failure = FailedRequest(
            url: urlString,
            method: method,
            statusCode: statusCode,
            errorMessage: error.localizedDescription,
            errorCode: errorCode,
            requestHeaders: requestHeaders,
            requestBody: requestBody,
            responseHeaders: responseHeaders,
            responseBody: nil
        )

        Task { @MainActor in
            HTTPFailureStore.shared.add(failure)
        }
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        // Only capture failures
        guard case let .failure(error) = response.result else { return }

        let urlString = request.request?.url?.absoluteString ?? "Unknown URL"
        let method = request.request?.httpMethod ?? "Unknown"

        os_log("Response parsing failed: %{public}@ %{public}@", log: Log.network, method, urlString)

        // Extract request details
        var requestHeaders: [String: String] = [:]
        if let headers = request.request?.allHTTPHeaderFields {
            requestHeaders = headers
        }

        var requestBody: String?
        if let bodyData = request.request?.httpBody {
            requestBody = String(data: bodyData, encoding: .utf8)
        }

        // Extract response details
        let statusCode = response.response?.statusCode
        let responseHeaders = response.response?.allHeaderFields as? [String: String]

        var responseBody: String?
        if let data = response.data {
            responseBody = String(data: data, encoding: .utf8)
        }

        // Get underlying error code
        var errorCode: Int?
        if let urlError = error.underlyingError as? URLError {
            errorCode = urlError.errorCode
        }

        let failure = FailedRequest(
            url: urlString,
            method: method,
            statusCode: statusCode,
            errorMessage: error.localizedDescription,
            errorCode: errorCode,
            requestHeaders: requestHeaders,
            requestBody: requestBody,
            responseHeaders: responseHeaders,
            responseBody: responseBody
        )

        Task { @MainActor in
            HTTPFailureStore.shared.add(failure)
        }
    }
}

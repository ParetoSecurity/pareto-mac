//
//  UpdateService.swift
//  Pareto Security
//
//  Created by Claude on 06/07/2025.
//

import Alamofire
import Cache
import Defaults
import Foundation
import os.log

enum APIError: Swift.Error {
    case invalidURL
    case noData
    case invalidResponse
    case networkError(String)
    case decodingError(String)
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .invalidResponse:
            return "Invalid response"
        case let .networkError(message):
            return "Network error: \(message)"
        case let .decodingError(message):
            return "Decoding error: \(message)"
        }
    }
}

class UpdateService {
    static let shared = UpdateService()

    private let baseURL = "https://paretosecurity.com/api"
    private let session: Session

    private init() {
        // Create URLSessionConfiguration without caching (we'll handle it manually)
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Create Alamofire session with custom configuration
        session = Session(configuration: configuration)
    }

    func request<T: Decodable>(
        endpoint: String,
        queryParameters: [String: String] = [:],
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        guard let url = buildURL(endpoint: endpoint, queryParameters: queryParameters) else {
            completion(.failure(.invalidURL))
            return
        }

        os_log("Making API request to: %{public}s", url.absoluteString)

        let request = URLRequest(url: url)

        session.request(request)
            .validate()
            .responseData { response in
                switch response.result {
                case let .success(data):
                    do {
                        let result = try JSONDecoder().decode(T.self, from: data)
                        completion(.success(result))
                    } catch {
                        os_log("Failed to decode response: %{public}s", error.localizedDescription)
                        completion(.failure(.decodingError(error.localizedDescription)))
                    }
                case let .failure(error):
                    os_log("API request failed: %{public}s", error.localizedDescription)
                    completion(.failure(.networkError(error.localizedDescription)))
                }
            }
    }

    func requestAsync<T: Decodable>(
        endpoint: String,
        queryParameters: [String: String] = [:]
    ) async throws -> T {
        guard let url = buildURL(endpoint: endpoint, queryParameters: queryParameters) else {
            throw APIError.invalidURL
        }

        os_log("Making async API request to: %{public}s", url.absoluteString)

        let request = URLRequest(url: url)
        return try await withCheckedThrowingContinuation { continuation in
            session.request(request)
                .responseData { response in
                    if let statusCode = response.response?.statusCode {
                        if statusCode == 503 {
                            os_log("Ignoring HTTP %{public}d response for API request (service temporarily unavailable)", statusCode)
                            continuation.resume(throwing: APIError.networkError("HTTP \(statusCode) - temporarily unavailable"))
                            return
                        } else if statusCode == 403 {
                            os_log("Ignoring HTTP %{public}d response for API request (access forbidden)", statusCode)
                            continuation.resume(throwing: APIError.networkError("HTTP \(statusCode) - access forbidden"))
                            return
                        }
                    }

                    guard let httpResponse = response.response,
                          (200 ... 299).contains(httpResponse.statusCode)
                    else {
                        let statusCode = response.response?.statusCode ?? 0
                        os_log("Async API request failed with status: %{public}d", statusCode)
                        continuation.resume(throwing: APIError.networkError("HTTP \(statusCode)"))
                        return
                    }

                    switch response.result {
                    case let .success(data):
                        do {
                            let decodedResult = try JSONDecoder().decode(T.self, from: data)
                            continuation.resume(returning: decodedResult)
                        } catch {
                            os_log("Failed to decode response: %{public}s", error.localizedDescription)
                            continuation.resume(throwing: APIError.decodingError(error.localizedDescription))
                        }
                    case let .failure(error):
                        os_log("Async API request failed: %{public}s", error.localizedDescription)
                        continuation.resume(throwing: APIError.networkError(error.localizedDescription))
                    }
                }
        }
    }

    private func buildURL(endpoint: String, queryParameters: [String: String]) -> URL? {
        var components = URLComponents(string: baseURL + endpoint)

        if !queryParameters.isEmpty {
            // Sort query parameters to ensure consistent cache keys
            components?.queryItems = queryParameters
                .sorted { $0.key < $1.key }
                .map { key, value in
                    URLQueryItem(name: key, value: value)
                }
        }

        return components?.url
    }
}

extension UpdateService {
    func getUpdates(completion: @escaping (Result<[Release], APIError>) -> Void) {
        let params = [
            "uuid": Defaults[.machineUUID],
            "version": AppInfo.appVersion,
            "os_version": AppInfo.macOSVersionString,
            "distribution": AppInfo.utmSource,
        ]

        request(
            endpoint: "/updates",
            queryParameters: params,
            completion: completion
        )
    }

    func getUpdatesAsync() async throws -> [Release] {
        let params = [
            "uuid": Defaults[.machineUUID],
            "version": AppInfo.appVersion,
            "os_version": AppInfo.macOSVersionString,
            "distribution": AppInfo.utmSource,
        ]

        return try await requestAsync(
            endpoint: "/updates",
            queryParameters: params
        )
    }
}

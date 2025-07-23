//
//  APIService.swift
//  Pareto Security
//
//  Created by Claude on 06/07/2025.
//

import Alamofire
import Defaults
import Foundation
import os.log
import Defaults
import Alamofire
import JWTDecode

enum APIError: Swift.Error {
    case invalidURL
    case noData
    case invalidResponse
    case networkError(String)
    case decodingError(String)
    case invalidToken
    case enrollmentFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .invalidResponse:
            return "Invalid response"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .invalidToken:
            return "Invalid authentication token"
        case .enrollmentFailed:
            return "Device enrollment failed"
        }
    }
}

struct DeviceEnrollmentRequest: Codable {
    let inviteID: String
    
    enum CodingKeys: String, CodingKey {
        case inviteID = "invite_id"
    }
}

struct DeviceEnrollmentResponse: Codable {
    let auth: String
}

class APIService {
    static let shared = APIService()

    private let baseURL = "https://paretosecurity.com/api"
    private let session: Session
    private var memoryCache: [String: (data: Data, timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes

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
        responseType: T.Type,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        guard let url = buildURL(endpoint: endpoint, queryParameters: queryParameters) else {
            completion(.failure(.invalidURL))
            return
        }

        let cacheKey = url.absoluteString

        // Check memory cache first
        if let cachedItem = memoryCache[cacheKey] {
            let age = Date().timeIntervalSince(cachedItem.timestamp)
            if age < cacheExpiration {
                os_log("Returning cached response for: %{public}s (age: %{public}f seconds)", url.absoluteString, age)
                do {
                    let result = try JSONDecoder().decode(responseType, from: cachedItem.data)
                    completion(.success(result))
                    return
                } catch {
                    os_log("Failed to decode cached data: %{public}s", error.localizedDescription)
                    // Remove invalid cached data and continue with network request
                    memoryCache.removeValue(forKey: cacheKey)
                }
            } else {
                // Cache expired, remove it
                memoryCache.removeValue(forKey: cacheKey)
            }
        }

        os_log("Making API request to: %{public}s", url.absoluteString)

        let request = URLRequest(url: url)

        session.request(request)
            .validate()
            .responseData { response in
                switch response.result {
                case let .success(data):
                    do {
                        let result = try JSONDecoder().decode(responseType, from: data)
                        // Cache the response data
                        self.memoryCache[cacheKey] = (data: data, timestamp: Date())
                        os_log("API request completed and cached: %{public}s", url.absoluteString)
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

    func requestSync<T: Decodable>(
        endpoint: String,
        queryParameters: [String: String] = [:],
        responseType: T.Type
    ) throws -> T {
        guard let url = buildURL(endpoint: endpoint, queryParameters: queryParameters) else {
            throw APIError.invalidURL
        }

        let cacheKey = url.absoluteString

        // Check memory cache first
        if let cachedItem = memoryCache[cacheKey] {
            let age = Date().timeIntervalSince(cachedItem.timestamp)
            if age < cacheExpiration {
                os_log("Returning cached response for sync request: %{public}s (age: %{public}f seconds)", url.absoluteString, age)
                do {
                    let result = try JSONDecoder().decode(responseType, from: cachedItem.data)
                    return result
                } catch {
                    os_log("Failed to decode cached data: %{public}s", error.localizedDescription)
                    // Remove invalid cached data and continue with network request
                    memoryCache.removeValue(forKey: cacheKey)
                }
            } else {
                // Cache expired, remove it
                memoryCache.removeValue(forKey: cacheKey)
            }
        }

        os_log("Making sync API request to: %{public}s", url.absoluteString)

        let request = URLRequest(url: url)

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, APIError>?

        session.request(request)
            .validate()
            .responseData { response in
                switch response.result {
                case let .success(data):
                    do {
                        let decodedResult = try JSONDecoder().decode(responseType, from: data)
                        // Cache the response data
                        self.memoryCache[cacheKey] = (data: data, timestamp: Date())
                        os_log("Sync API request completed and cached: %{public}s", url.absoluteString)
                        result = .success(decodedResult)
                    } catch {
                        os_log("Failed to decode response: %{public}s", error.localizedDescription)
                        result = .failure(.decodingError(error.localizedDescription))
                    }
                case let .failure(error):
                    os_log("Sync API request failed: %{public}s", error.localizedDescription)
                    result = .failure(.networkError(error.localizedDescription))
                }
                semaphore.signal()
            }

        _ = semaphore.wait(timeout: .now() + 10.0)

        guard let finalResult = result else {
            throw APIError.networkError("Request timeout")
        }

        switch finalResult {
        case let .success(data):
            return data
        case let .failure(error):
            throw error
        }
    }

    func clearCache() {
        memoryCache.removeAll()
        os_log("API cache cleared")
    }

    private func buildURL(endpoint: String, queryParameters: [String: String]) -> URL? {
        var components = URLComponents(string: baseURL + endpoint)

        if !queryParameters.isEmpty {
            components?.queryItems = queryParameters.map { key, value in
                URLQueryItem(name: key, value: value)
            }
        }

        return components?.url
    }
    
    // Team enrollment specific methods using different base URL
    private var teamBaseURL: String {
        return "https://cloud.paretosecurity.com"
    }
    
    func enrollDevice(inviteID: String, completion: @escaping (Result<(String, String), APIError>) -> Void) {
        let request = DeviceEnrollmentRequest(inviteID: inviteID)
        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        os_log("Enrolling device with invite ID: %{public}s", inviteID)
        
        session.request(
            "\(teamBaseURL)/api/v1/team/enroll",
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: headers
        ) { $0.timeoutInterval = 10 }
        .validate()
        .responseDecodable(of: DeviceEnrollmentResponse.self) { response in
            os_log("%{public}s", log: Log.api, response.debugDescription)
            
            switch response.result {
            case .success(let enrollmentResponse):
                // Extract team ID from the JWT token
                if let teamID = self.extractTeamIDFromToken(enrollmentResponse.auth) {
                    completion(.success((enrollmentResponse.auth, teamID)))
                } else {
                    completion(.failure(.invalidToken))
                }
            case .failure(let error):
                os_log("Device enrollment failed: %{public}s", error.localizedDescription)
                completion(.failure(.networkError(error.localizedDescription)))
            }
        }
    }
    
    private func extractTeamIDFromToken(_ token: String) -> String? {
        do {
            let jwt = try decode(jwt: token)
            return jwt.claim(name: "team_id").string
        } catch {
            os_log("Failed to extract team ID from token: %{public}s", error.localizedDescription)
            return nil
        }
    }
}

extension APIService {
    func getUpdates(completion: @escaping (Result<[Release], APIError>) -> Void) {
        let params = [
            "uuid": Defaults[.machineUUID],
            "version": AppInfo.appVersion,
            "os_version": AppInfo.macOSVersionString,
            "distribution": AppInfo.utmSource
        ]

        request(
            endpoint: "/updates",
            queryParameters: params,
            responseType: [Release].self,
            completion: completion
        )
    }

    func getUpdatesSync() throws -> [Release] {
        let params = [
            "uuid": Defaults[.machineUUID],
            "version": AppInfo.appVersion,
            "os_version": AppInfo.macOSVersionString,
            "distribution": AppInfo.utmSource
        ]

        return try requestSync(
            endpoint: "/updates",
            queryParameters: params,
            responseType: [Release].self
        )
    }
}

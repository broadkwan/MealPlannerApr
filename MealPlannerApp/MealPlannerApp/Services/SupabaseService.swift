import Foundation

enum SupabaseError: LocalizedError {
    case missingConfiguration(String)
    case invalidResponse
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let key):
            return "Missing configuration for \(key). Fill in Secrets.xcconfig before running the app."
        case .invalidResponse:
            return "The server returned an unreadable response."
        case .server(let message):
            return message
        }
    }
}

struct SupabaseConfiguration {
    let url: URL?
    let anonKey: String
    let menuTable: String
    let assignmentsTable: String

    var isConfigured: Bool {
        url != nil && !anonKey.isEmpty
    }

    init(bundle: Bundle = .main) {
        if let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String {
            let trimmedURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if
                !trimmedURL.isEmpty,
                trimmedURL != "$(SUPABASE_URL)",
                let parsedURL = URL(string: trimmedURL),
                parsedURL.host != nil
            {
                url = parsedURL
            } else if let rawHost = bundle.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String {
                let trimmedHost = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedHost.isEmpty, trimmedHost != "$(SUPABASE_HOST)" {
                    url = URL(string: "https://\(trimmedHost)")
                } else {
                    url = nil
                }
            } else {
                url = nil
            }
        } else {
            if let rawHost = bundle.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String {
                let trimmedHost = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
                url = trimmedHost.isEmpty || trimmedHost == "$(SUPABASE_HOST)" ? nil : URL(string: "https://\(trimmedHost)")
            } else {
                url = nil
            }
        }

        if let rawAnonKey = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String {
            anonKey = rawAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            anonKey = ""
        }

        if let rawMenuTable = bundle.object(forInfoDictionaryKey: "SUPABASE_MENU_TABLE") as? String {
            let trimmedMenuTable = rawMenuTable.trimmingCharacters(in: .whitespacesAndNewlines)
            menuTable = trimmedMenuTable.isEmpty ? "menu_items" : trimmedMenuTable
        } else {
            menuTable = "menu_items"
        }

        if let rawAssignmentsTable = bundle.object(forInfoDictionaryKey: "SUPABASE_ASSIGNMENTS_TABLE") as? String {
            let trimmedAssignmentsTable = rawAssignmentsTable.trimmingCharacters(in: .whitespacesAndNewlines)
            assignmentsTable = trimmedAssignmentsTable.isEmpty ? "daily_menu_assignments" : trimmedAssignmentsTable
        } else {
            assignmentsTable = "daily_menu_assignments"
        }
    }
}

struct AuthResponse: Decodable {
    let accessToken: String
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}

struct AuthUser: Decodable {
    let email: String
}

struct SupabaseService {
    private let configuration: SupabaseConfiguration
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let session: URLSession

    init(configuration: SupabaseConfiguration = SupabaseConfiguration()) {
        self.configuration = configuration
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 120
        sessionConfiguration.timeoutIntervalForResource = 180
        self.session = URLSession(configuration: sessionConfiguration)
    }

    var isConfigured: Bool {
        configuration.isConfigured
    }

    var configuredURLString: String {
        configuration.url?.absoluteString ?? "Not Configured"
    }

    func fetchMenuItems() async throws -> [MenuItem] {
        guard configuration.isConfigured else { return [] }
        let data = try await send(
            path: "/rest/v1/\(configuration.menuTable)",
            method: "GET",
            accessToken: nil,
            bodyData: nil,
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "name.asc"),
                URLQueryItem(name: "is_archived", value: "eq.false")
            ],
            extraHeaders: [:]
        )
        return try decode([MenuItem].self, from: data)
    }

    func fetchAssignments() async throws -> [DailyMenuAssignment] {
        guard configuration.isConfigured else { return [] }
        let data = try await send(
            path: "/rest/v1/\(configuration.assignmentsTable)",
            method: "GET",
            accessToken: nil,
            bodyData: nil,
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "service_date.asc")
            ],
            extraHeaders: [:]
        )
        return try decode([DailyMenuAssignment].self, from: data)
    }

    func signIn(email: String, password: String) async throws -> UserSession {
        try requireConfiguration()
        let payload = ["email": email, "password": password]
        let bodyData = try encoder.encode(payload)
        let data = try await send(
            path: "/auth/v1/token",
            method: "POST",
            accessToken: nil,
            bodyData: bodyData,
            queryItems: [
                URLQueryItem(name: "grant_type", value: "password")
            ],
            extraHeaders: [:]
        )
        let response = try decode(AuthResponse.self, from: data)
        return UserSession(email: response.user.email, accessToken: response.accessToken)
    }

    func upsert(menuItem: MenuItem, accessToken: String? = nil) async throws -> MenuItem {
        try requireConfiguration()
        let bodyData = try encoder.encode(menuItem)
        let data = try await send(
            path: "/rest/v1/\(configuration.menuTable)",
            method: "POST",
            accessToken: accessToken,
            bodyData: bodyData,
            queryItems: [
                URLQueryItem(name: "on_conflict", value: "id")
            ],
            extraHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )
        let result = try decode([MenuItem].self, from: data)
        guard let item = result.first else { throw SupabaseError.invalidResponse }
        return item
    }

    func archive(menuItem: MenuItem, accessToken: String? = nil) async throws -> MenuItem {
        var archived = menuItem
        archived.isArchived = true
        return try await upsert(menuItem: archived, accessToken: accessToken)
    }

    func delete(menuItemID: UUID, accessToken: String? = nil) async throws {
        try requireConfiguration()
        _ = try await send(
            path: "/rest/v1/\(configuration.menuTable)",
            method: "DELETE",
            accessToken: accessToken,
            bodyData: nil,
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(menuItemID.uuidString.lowercased())")
            ],
            extraHeaders: [:]
        )
    }

    func upsert(assignment: DailyMenuAssignment, accessToken: String? = nil) async throws -> DailyMenuAssignment {
        try requireConfiguration()
        let bodyData = try encoder.encode(assignment)
        let data = try await send(
            path: "/rest/v1/\(configuration.assignmentsTable)",
            method: "POST",
            accessToken: accessToken,
            bodyData: bodyData,
            queryItems: [
                URLQueryItem(name: "on_conflict", value: "service_date")
            ],
            extraHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )
        let result = try decode([DailyMenuAssignment].self, from: data)
        guard let saved = result.first else { throw SupabaseError.invalidResponse }
        return saved
    }

    func deleteAssignment(for serviceDate: String, accessToken: String? = nil) async throws {
        try requireConfiguration()
        _ = try await send(
            path: "/rest/v1/\(configuration.assignmentsTable)",
            method: "DELETE",
            accessToken: accessToken,
            bodyData: nil,
            queryItems: [
                URLQueryItem(name: "service_date", value: "eq.\(serviceDate)")
            ],
            extraHeaders: [:]
        )
    }

    private func send(
        path: String,
        method: String,
        accessToken: String?,
        bodyData: Data?,
        queryItems: [URLQueryItem],
        extraHeaders: [String: String]
    ) async throws -> Data {
        guard let baseURL = configuration.url else {
            throw SupabaseError.missingConfiguration("SUPABASE_URL")
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseError.invalidResponse
        }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let requestURL = components.url else {
            throw SupabaseError.invalidResponse
        }

        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = method
        urlRequest.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accessToken {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            urlRequest.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        }

        for (key, value) in extraHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        urlRequest.httpBody = bodyData

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .timedOut {
            throw SupabaseError.server(message: "The connection to Supabase timed out. Please try again in a moment.")
        } catch {
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let message = String(data: data, encoding: .utf8), !message.isEmpty {
                throw SupabaseError.server(message: message)
            }
            throw SupabaseError.server(message: "Request failed with status \(httpResponse.statusCode).")
        }

        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SupabaseError.server(message: "Decoding failed: \(error.localizedDescription)")
        }
    }

    private func requireConfiguration() throws {
        guard configuration.url != nil else {
            throw SupabaseError.missingConfiguration("SUPABASE_URL")
        }

        guard !configuration.anonKey.isEmpty else {
            throw SupabaseError.missingConfiguration("SUPABASE_ANON_KEY")
        }
    }
}

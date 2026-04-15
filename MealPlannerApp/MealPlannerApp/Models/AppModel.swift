import Foundation
import SwiftUI

struct MenuItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var supportsLunch: Bool
    var supportsDinner: Bool
    var ingredients: String
    var photoDataBase64: String
    var instructions: String
    var isArchived: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case supportsLunch = "supports_lunch"
        case supportsDinner = "supports_dinner"
        case ingredients
        case photoDataBase64 = "ingredient_sources"
        case instructions
        case isArchived = "is_archived"
    }

    static var empty: MenuItem {
        MenuItem(
            id: UUID(),
            name: "",
            supportsLunch: true,
            supportsDinner: true,
            ingredients: "",
            photoDataBase64: "",
            instructions: "",
            isArchived: false
        )
    }
}

struct DailyMenuAssignment: Identifiable, Codable, Hashable {
    let id: UUID
    var serviceDate: String
    var lunchMenuItemID: UUID?
    var dinnerMenuItemID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case serviceDate = "service_date"
        case lunchMenuItemID = "lunch_menu_item_id"
        case dinnerMenuItemID = "dinner_menu_item_id"
    }

    init(id: UUID, serviceDate: String, lunchMenuItemID: UUID?, dinnerMenuItemID: UUID?) {
        self.id = id
        self.serviceDate = serviceDate
        self.lunchMenuItemID = lunchMenuItemID
        self.dinnerMenuItemID = dinnerMenuItemID
    }

    static func empty(for date: Date) -> DailyMenuAssignment {
        DailyMenuAssignment(
            id: UUID(),
            serviceDate: DateFormatting.apiDate.string(from: date),
            lunchMenuItemID: nil,
            dinnerMenuItemID: nil
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        serviceDate = try container.decode(String.self, forKey: .serviceDate)
        lunchMenuItemID = try container.decodeIfPresent(UUID.self, forKey: .lunchMenuItemID)
        dinnerMenuItemID = try container.decodeIfPresent(UUID.self, forKey: .dinnerMenuItemID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(serviceDate, forKey: .serviceDate)

        if let lunchMenuItemID {
            try container.encode(lunchMenuItemID, forKey: .lunchMenuItemID)
        } else {
            try container.encodeNil(forKey: .lunchMenuItemID)
        }

        if let dinnerMenuItemID {
            try container.encode(dinnerMenuItemID, forKey: .dinnerMenuItemID)
        } else {
            try container.encodeNil(forKey: .dinnerMenuItemID)
        }
    }
}

struct UserSession {
    let email: String
    let accessToken: String
}

enum DateFormatting {
    static let apiDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
}

@MainActor
final class AppModel: ObservableObject {
    @Published var menuItems: [MenuItem] = []
    @Published var assignments: [DailyMenuAssignment] = []
    @Published var session: UserSession?
    @Published var isLoading = false
    @Published var errorMessage: String?

    let service: SupabaseService

    init(service: SupabaseService = SupabaseService()) {
        self.service = service
    }

    var activeMenuItems: [MenuItem] {
        menuItems.filter { !$0.isArchived }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var isSupabaseConfigured: Bool {
        service.isConfigured
    }

    var configuredSupabaseURL: String {
        service.configuredURLString
    }

    var configuredSupabaseHostDisplay: String {
        guard let url = URL(string: service.configuredURLString), let host = url.host, !host.isEmpty else {
            return "Not Configured"
        }
        let projectRef = host.components(separatedBy: ".").first ?? host
        guard projectRef.count > 12 else { return projectRef }
        let prefix = projectRef.prefix(8)
        let suffix = projectRef.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    func loadInitialData() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            async let menus = service.fetchMenuItems()
            async let assignments = service.fetchAssignments()
            self.menuItems = try await menus
            self.assignments = try await assignments
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func menuItem(id: UUID?) -> MenuItem? {
        guard let id else { return nil }
        return menuItems.first { $0.id == id }
    }

    func assignment(for date: Date) -> DailyMenuAssignment? {
        let key = DateFormatting.apiDate.string(from: date)
        return assignments.first { $0.serviceDate == key }
    }

    func signIn(email: String, password: String) async -> Bool {
        errorMessage = nil

        do {
            session = try await service.signIn(email: email, password: password)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() {
        session = nil
    }

    func save(menuItem: MenuItem) async -> Bool {
        guard service.isConfigured else {
            if let index = menuItems.firstIndex(where: { $0.id == menuItem.id }) {
                menuItems[index] = menuItem
            } else {
                menuItems.append(menuItem)
            }
            menuItems.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return true
        }

        do {
            let saved = try await service.upsert(menuItem: menuItem, accessToken: session?.accessToken)
            if let index = menuItems.firstIndex(where: { $0.id == saved.id }) {
                menuItems[index] = saved
            } else {
                menuItems.append(saved)
            }
            menuItems.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func archive(menuItem: MenuItem) async -> Bool {
        guard service.isConfigured else {
            if let index = menuItems.firstIndex(where: { $0.id == menuItem.id }) {
                var archived = menuItems[index]
                archived.isArchived = true
                menuItems[index] = archived
            }
            return true
        }

        do {
            let archived = try await service.archive(menuItem: menuItem, accessToken: session?.accessToken)
            if let index = menuItems.firstIndex(where: { $0.id == archived.id }) {
                menuItems[index] = archived
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(menuItem: MenuItem) async -> Bool {
        errorMessage = nil

        if service.isConfigured {
            do {
                try await service.delete(menuItemID: menuItem.id, accessToken: session?.accessToken)
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }

        menuItems.removeAll { $0.id == menuItem.id }
        assignments = assignments.map { assignment in
            var updated = assignment
            if updated.lunchMenuItemID == menuItem.id {
                updated.lunchMenuItemID = nil
            }
            if updated.dinnerMenuItemID == menuItem.id {
                updated.dinnerMenuItemID = nil
            }
            return updated
        }
        return true
    }

    func saveAssignment(for date: Date, lunchID: UUID?, dinnerID: UUID?) async -> Bool {
        let serviceDate = DateFormatting.apiDate.string(from: date)

        if lunchID == nil, dinnerID == nil {
            guard service.isConfigured else {
                assignments.removeAll { $0.serviceDate == serviceDate }
                return true
            }

            do {
                try await service.deleteAssignment(for: serviceDate, accessToken: session?.accessToken)
                assignments.removeAll { $0.serviceDate == serviceDate }
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }

        let assignment = DailyMenuAssignment(
            id: assignment(for: date)?.id ?? UUID(),
            serviceDate: serviceDate,
            lunchMenuItemID: lunchID,
            dinnerMenuItemID: dinnerID
        )

        guard service.isConfigured else {
            if let index = assignments.firstIndex(where: { $0.serviceDate == assignment.serviceDate }) {
                assignments[index] = assignment
            } else {
                assignments.append(assignment)
            }
            assignments.sort { $0.serviceDate < $1.serviceDate }
            return true
        }

        do {
            let saved = try await service.upsert(assignment: assignment, accessToken: session?.accessToken)
            if let index = assignments.firstIndex(where: { $0.serviceDate == saved.serviceDate }) {
                assignments[index] = saved
            } else {
                assignments.append(saved)
            }
            assignments.sort { $0.serviceDate < $1.serviceDate }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

import Foundation
import Supabase
import Combine

struct MonthDescriptor: Codable, Identifiable, Equatable {
    let id: Int
    let userId: UUID
    let monthYear: String
    let descriptor: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case monthYear = "month_year"
        case descriptor
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

class MonthDescriptorService: ObservableObject {
    static let shared = MonthDescriptorService()
    private let supabase: SupabaseClient
    
    @Published private var monthDescriptors: [MonthDescriptor] = []
    
    private init() {
        guard let supabaseURL = URL(string: Config.supabaseURL) else {
            fatalError("Missing Supabase URL configuration")
        }
        
        let supabaseKey = Config.supabaseAnonKey
        
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
    
    // MARK: - Public API
    
    func getDescriptor(for monthYear: String) -> String? {
        return monthDescriptors.first { $0.monthYear == monthYear }?.descriptor
    }
    
    func loadMonthDescriptors() async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        let response: [MonthDescriptor] = try await supabase
            .from("month_descriptors")
            .select("*")
            .eq("user_id", value: userId)
            .order("month_year", ascending: false)
            .execute()
            .value
        
        await MainActor.run {
            self.monthDescriptors = response
        }
    }
    
    func setDescriptor(for monthYear: String, descriptor: String) async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        if descriptor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // If descriptor is empty, remove it
            try await removeDescriptor(for: monthYear)
            return
        }
        
        let trimmedDescriptor = descriptor.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if descriptor already exists
        if let existing = monthDescriptors.first(where: { $0.monthYear == monthYear }) {
            // Update existing descriptor
            let updateData: [String: AnyJSON] = [
                "descriptor": .string(trimmedDescriptor)
            ]
            
            try await supabase
                .from("month_descriptors")
                .update(updateData)
                .eq("id", value: existing.id)
                .execute()
            
            await MainActor.run {
                if let index = self.monthDescriptors.firstIndex(where: { $0.id == existing.id }) {
                    self.monthDescriptors[index] = MonthDescriptor(
                        id: existing.id,
                        userId: existing.userId,
                        monthYear: existing.monthYear,
                        descriptor: trimmedDescriptor,
                        createdAt: existing.createdAt,
                        updatedAt: Date()
                    )
                }
            }
        } else {
            // Create new descriptor
            let insertData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "month_year": .string(monthYear),
                "descriptor": .string(trimmedDescriptor)
            ]
            
            let response: [MonthDescriptor] = try await supabase
                .from("month_descriptors")
                .insert(insertData)
                .select("*")
                .execute()
                .value
            
            if let newDescriptor = response.first {
                await MainActor.run {
                    self.monthDescriptors.append(newDescriptor)
                    // Keep the list sorted
                    self.monthDescriptors.sort { $0.monthYear > $1.monthYear }
                }
            }
        }
    }
    
    func removeDescriptor(for monthYear: String) async throws {
        guard let existing = monthDescriptors.first(where: { $0.monthYear == monthYear }) else {
            return // Nothing to remove
        }
        
        try await supabase
            .from("month_descriptors")
            .delete()
            .eq("id", value: existing.id)
            .execute()
        
        await MainActor.run {
            self.monthDescriptors.removeAll { $0.id == existing.id }
        }
    }
    
    // MARK: - Helper Functions
    
    func formatMonthYearForDisplay(_ monthYear: String, with descriptor: String?) -> String {
        // Convert "2025-08" format to "August 2025" format
        let components = monthYear.components(separatedBy: "-")
        guard components.count == 2,
              let year = components.first,
              let monthNum = Int(components.last ?? "") else {
            return monthYear
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM"
        guard let date = dateFormatter.date(from: String(format: "%02d", monthNum)) else {
            return monthYear
        }
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: date)
        
        let baseText = "\(monthName) \(year)"
        
        if let descriptor = descriptor, !descriptor.isEmpty {
            return "\(baseText) - \(descriptor)"
        } else {
            return baseText
        }
    }
    
    func convertDisplayDateToMonthYear(_ displayDate: String) -> String {
        // Convert "August 2025" or "August 2025 - Some descriptor" to "2025-08" format
        let baseDate = displayDate.components(separatedBy: " - ").first ?? displayDate
        let components = baseDate.components(separatedBy: " ")
        
        guard components.count == 2,
              let year = components.last,
              let month = components.first else {
            return displayDate
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        guard let date = dateFormatter.date(from: month) else {
            return displayDate
        }
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM"
        let monthNum = monthFormatter.string(from: date)
        
        return "\(year)-\(monthNum)"
    }
}
import Foundation

struct MockECGSample: Identifiable, Equatable {
    let id: UUID
    let startDate: Date
    let duration: TimeInterval

    static func == (lhs: MockECGSample, rhs: MockECGSample) -> Bool {
        return lhs.id == rhs.id
    }
}

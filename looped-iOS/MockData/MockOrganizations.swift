#if DEBUG
import Foundation

struct MockOrganizations {
    static let companies: [Organization] = [
        Organization(name: "Anthropic", category: "Technology", logoText: "AN", kind: .company),
        Organization(name: "OpenAI", category: "Technology", logoText: "OA", kind: .company),
        Organization(name: "Google", category: "Technology", logoText: "GOOG", kind: .company),
        Organization(name: "Microsoft", category: "Technology", logoText: "MS", kind: .company),
        Organization(name: "J.P. Morgan", category: "Finance", logoText: "JPM", kind: .company),
        Organization(name: "Goldman Sachs", category: "Finance", logoText: "GS", kind: .company),
        Organization(name: "Morgan Stanley", category: "Finance", logoText: "MS", kind: .company),
        Organization(name: "Bank of America", category: "Finance", logoText: "BOA", kind: .company)
    ]

    static let schools: [Organization] = [
        Organization(name: "NC State University", category: "University", logoText: "NCSU", kind: .school),
        Organization(name: "UNC Chapel Hill", category: "University", logoText: "UNC", kind: .school),
        Organization(name: "Duke University", category: "University", logoText: "DU", kind: .school),
        Organization(name: "Wake Forest University", category: "University", logoText: "WF", kind: .school),
        Organization(name: "UNC Charlotte", category: "University", logoText: "UNCC", kind: .school),
        Organization(name: "NC A&T State University", category: "University", logoText: "NCAT", kind: .school),
        Organization(name: "East Carolina University", category: "University", logoText: "ECU", kind: .school),
        Organization(name: "Appalachian State University", category: "University", logoText: "APP", kind: .school)
    ]
}
#endif

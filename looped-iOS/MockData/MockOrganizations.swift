import Foundation

struct MockOrganizations {
    static let companies: [Organization] = [
        Organization(name: "Anthropic", category: "Technology", logoText: "AN"),
        Organization(name: "OpenAI", category: "Technology", logoText: "OA"),
        Organization(name: "Google", category: "Technology", logoText: "GOOG"),
        Organization(name: "Microsoft", category: "Technology", logoText: "MS"),
        Organization(name: "J.P. Morgan", category: "Finance", logoText: "JPM"),
        Organization(name: "Goldman Sachs", category: "Finance", logoText: "GS"),
        Organization(name: "Morgan Stanley", category: "Finance", logoText: "MS"),
        Organization(name: "Bank of America", category: "Finance", logoText: "BOA")
    ]

    static let schools: [Organization] = [
        Organization(name: "NC State University", category: "University", logoText: "NCSU"),
        Organization(name: "UNC Chapel Hill", category: "University", logoText: "UNC"),
        Organization(name: "Duke University", category: "University", logoText: "DU"),
        Organization(name: "Wake Forest University", category: "University", logoText: "WF"),
        Organization(name: "UNC Charlotte", category: "University", logoText: "UNCC"),
        Organization(name: "NC A&T State University", category: "University", logoText: "NCAT"),
        Organization(name: "East Carolina University", category: "University", logoText: "ECU"),
        Organization(name: "Appalachian State University", category: "University", logoText: "APP")
    ]
}

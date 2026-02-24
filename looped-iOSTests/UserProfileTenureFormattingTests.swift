import Foundation
import Testing
@testable import looped_iOS

struct UserProfileTenureFormattingTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return value
    }

    @Test
    func formattedTimeInLoop_usesDaysWhenLessThanOneWeek() {
        let createdAt = makeDate(year: 2026, month: 1, day: 1)
        let asOf = makeDate(year: 2026, month: 1, day: 4)
        let profile = makeProfile(createdAt: createdAt)

        #expect(profile.formattedTimeInLoop(asOf: asOf, calendar: calendar) == "3 days in the Loop")
    }

    @Test
    func formattedTimeInLoop_usesWeeksWhenLessThanOneMonth() {
        let createdAt = makeDate(year: 2026, month: 1, day: 1)
        let asOf = makeDate(year: 2026, month: 1, day: 20)
        let profile = makeProfile(createdAt: createdAt)

        #expect(profile.formattedTimeInLoop(asOf: asOf, calendar: calendar) == "2 weeks in the Loop")
    }

    @Test
    func formattedTimeInLoop_usesMonthsWhenLessThanOneYear() {
        let createdAt = makeDate(year: 2026, month: 1, day: 1)
        let asOf = makeDate(year: 2026, month: 4, day: 1)
        let profile = makeProfile(createdAt: createdAt)

        #expect(profile.formattedTimeInLoop(asOf: asOf, calendar: calendar) == "3 months in the Loop")
    }

    @Test
    func formattedTimeInLoop_usesYearsAtOneYearOrMore() {
        let createdAt = makeDate(year: 2023, month: 1, day: 1)
        let asOf = makeDate(year: 2026, month: 1, day: 1)
        let profile = makeProfile(createdAt: createdAt)

        #expect(profile.formattedTimeInLoop(asOf: asOf, calendar: calendar) == "3 years in the Loop")
    }

    @Test
    func formattedTimeInLoop_usesSingularUnit() {
        let createdAt = makeDate(year: 2026, month: 1, day: 1)
        let asOf = makeDate(year: 2026, month: 1, day: 8)
        let profile = makeProfile(createdAt: createdAt)

        #expect(profile.formattedTimeInLoop(asOf: asOf, calendar: calendar) == "1 week in the Loop")
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )
        return calendar.date(from: components) ?? .distantPast
    }

    private func makeProfile(createdAt: Date) -> UserProfile {
        UserProfile(
            id: UUID(),
            backendId: 1,
            username: "looped",
            displayName: "Looped",
            handle: "looped",
            company: "Looped",
            jobTitle: "Team Member",
            bio: nil,
            profileImageURL: nil,
            isVerified: true,
            isAnonymous: false,
            yearsInLoop: 0,
            followingCount: 0,
            followersCount: 0,
            postsCount: 0,
            commentsCount: 0,
            showFollowerCount: true,
            isCurrentUser: true,
            displayCommunity: nil,
            displaySpecialization: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

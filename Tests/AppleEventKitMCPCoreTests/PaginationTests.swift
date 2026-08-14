import Testing
@testable import AppleEventKitMCPCore

struct PaginationTests {
    @Test func defaultsWhenUnspecified() throws {
        let page = try Pagination.resolve(limit: nil, offset: nil)
        #expect(page.limit == 50)
        #expect(page.offset == 0)
    }

    @Test func rejectsOutOfRangeLimit() {
        for bad in [0, -1, 1001, Int.max] {
            #expect(throws: ReminderError.self, "limit \(bad) should be rejected") {
                _ = try Pagination.resolve(limit: bad, offset: nil)
            }
        }
    }

    @Test func acceptsLimitBoundaries() throws {
        #expect(try Pagination.resolve(limit: 1, offset: nil).limit == 1)
        #expect(try Pagination.resolve(limit: 1000, offset: nil).limit == 1000)
    }

    @Test func rejectsNegativeOffset() {
        #expect(throws: ReminderError.self) {
            _ = try Pagination.resolve(limit: nil, offset: -1)
        }
    }

    @Test func windowClampsToTotal() throws {
        let page = try Pagination.resolve(limit: 10, offset: 0)
        #expect(page.window(totalCount: 3) == 0..<3)
        #expect(page.window(totalCount: 25) == 0..<10)
    }

    @Test func windowIsEmptyPastTheEnd() throws {
        let page = try Pagination.resolve(limit: 10, offset: 100)
        #expect(page.window(totalCount: 5).isEmpty)
        // Exactly at the boundary is also empty, not a crash.
        let atEnd = try Pagination.resolve(limit: 10, offset: 5)
        #expect(atEnd.window(totalCount: 5).isEmpty)
    }

    @Test func windowAdvancesWithoutGapsOrOverlap() throws {
        let total = 25
        var seen: [Int] = []
        var offset = 0
        while true {
            let page = try Pagination.resolve(limit: 10, offset: offset)
            let w = page.window(totalCount: total)
            if w.isEmpty { break }
            seen.append(contentsOf: w)
            guard page.hasMore(totalCount: total) else { break }
            offset += w.count
        }
        #expect(seen == Array(0..<total), "paging must cover every index exactly once")
    }

    @Test func hasMoreIsFalseOnTheFinalPage() throws {
        let page = try Pagination.resolve(limit: 10, offset: 20)
        let w = page.window(totalCount: 25)
        #expect(w == 20..<25)
        #expect(page.hasMore(totalCount: 25) == false)
    }

    @Test func hasMoreIsFalsePastTheEnd() throws {
        let page = try Pagination.resolve(limit: 10, offset: 100)
        #expect(page.window(totalCount: 5).isEmpty)
        #expect(page.hasMore(totalCount: 5) == false)
    }

    @Test func hasMoreIsTrueMidway() throws {
        let page = try Pagination.resolve(limit: 10, offset: 0)
        #expect(page.hasMore(totalCount: 25) == true)
    }

    @Test func emptyResultSetIsNotMore() throws {
        let page = try Pagination.resolve(limit: 50, offset: 0)
        #expect(page.window(totalCount: 0).isEmpty)
        #expect(page.hasMore(totalCount: 0) == false)
    }
}

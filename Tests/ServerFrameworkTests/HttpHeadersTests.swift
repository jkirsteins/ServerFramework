import XCTest
@testable import ServerFramework

final class HttpHeadersTests: XCTestCase {
    func testSubscript_caseInsensitive() throws {
        var sut = HttpHeaders()
        sut.append(HttpHeaderKeyValuePair(name: "X-UserId", value: " hello "))
        
        XCTAssertEqual(sut["X-USERID"], "hello")
        XCTAssertEqual(sut["X-UserId"], "hello")
        XCTAssertEqual(sut["x-userid"], "hello")
    }
}

import XCTest
@testable import ServerFramework

final class ServerFrameworkTests: XCTestCase {
    func testInit_simpleExactMatch() throws {
        let sut = try PathPatternParser("/hello")
        
        XCTAssertEqual(sut.patternParts, [.literal(value: "/hello")])
    }
    
    func testInit_simpleVariableMatch() throws {
        let sut = try PathPatternParser("/{hello}")
        
        XCTAssertEqual(sut.patternParts, [
            .literal(value: "/"),
            .variable(name: "hello")
        ])
    }
    
    func testInit_unterminatedVariable() throws {
        XCTAssertThrowsError(try PathPatternParser("/{hello")) {
            XCTAssertEqual($0 as? PathPatternParser.Error, .unterminatedVariable(name: "hello"))
        }
    }
    
    func testInit_openTwice() throws {
        XCTAssertThrowsError(try PathPatternParser("/{{")) {
            XCTAssertEqual($0 as? PathPatternParser.Error, .doubleOpen)
        }
    }
    
    func testInit_closeUnopened_fromLiteral() throws {
        XCTAssertThrowsError(try PathPatternParser("/hello}")) {
            XCTAssertEqual($0 as? PathPatternParser.Error, .closeUnopened)
        }
    }
    
    func testInit_closeUnopened_fromNil() throws {
        XCTAssertThrowsError(try PathPatternParser("/{hello}}")) {
            XCTAssertEqual($0 as? PathPatternParser.Error, .closeUnopened)
        }
    }
    
    func testMatch_exactMatch() throws {
        let sut = try PathPatternParser("/hello")
        let result = sut.match(against: "/hello")

        XCTAssertTrue(result.successful)
        XCTAssertEqual(result.components, [:])
    }
    
    func testMatch_variableInMiddle() throws {
        let sut = try PathPatternParser("/hello/{my-var}/2")
        let result = sut.match(against: "/hello/heyoo2/2")

        XCTAssertTrue(result.successful)
        XCTAssertEqual(result.components, ["my-var":"heyoo2"])
    }
    
    func testMatch_variableAtStart() throws {
        let sut = try PathPatternParser("{my-var}/2")
        let result = sut.match(against: "/hello/heyoo2/2")

        XCTAssertTrue(result.successful)
        XCTAssertEqual(result.components, ["my-var":"/hello/heyoo2"])
    }
    
    func testMatch_variableAtEnd() throws {
        let sut = try PathPatternParser("/hello/{my-var}")
        let result = sut.match(against: "/hello/heyoo2/2")

        XCTAssertTrue(result.successful)
        XCTAssertEqual(result.components, ["my-var":"heyoo2/2"])
    }
    
    func testMatch_emptyVariable() throws {
        let sut = try PathPatternParser("/hello/{my-var}{my-var2}")
        let result = sut.match(against: "/hello/heyoo2/2")

        XCTAssertTrue(result.successful)
        XCTAssertEqual(result.components, ["my-var":"heyoo2/2"])
    }
    
    func testMatch_tooManyVariables() throws {
        let sut = try PathPatternParser("/hello/{my-var}/2{my-var2}")
        let result = sut.match(against: "/hello/heyoo2/2")

        XCTAssertTrue(result.successful)
        XCTAssertEqual(result.components, ["my-var":"heyoo2"])
    }
    
    func testMatch_noMatch_containsVariable() throws {
        let sut = try PathPatternParser("/different/{my-var}")
        let result = sut.match(against: "/hello/heyoo2/2")

        XCTAssertFalse(result.successful)
    }
}

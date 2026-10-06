import XCTest

@testable import Calc

final class CalcTests: XCTestCase {
  func testAdd() {
    XCTAssertEqual(add(1, 2), 3)
  }
}

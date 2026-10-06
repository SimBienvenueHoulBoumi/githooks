import XCTest

@testable import Calc

final class CalcTests: XCTestCase {
  func testAdd() {
    XCTAssertEqual(Calc.add(1, 2), 4)
  }
}

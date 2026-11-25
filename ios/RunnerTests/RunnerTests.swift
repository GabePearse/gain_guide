import XCTest
import HealthKit
@testable import Runner

class RunnerTests: XCTestCase {
  func testStandardUnitsAndCatalog() throws {
    let weight = try XCTUnwrap(HealthMetric.catalog.first { $0.key == "weight" })
    XCTAssertEqual(weight.value(HKQuantity(unit: .pound(), doubleValue: 100)), 45.359237, accuracy: 0.00001)
    let fat = try XCTUnwrap(HealthMetric.catalog.first { $0.key == "body_fat" })
    XCTAssertEqual(fat.value(HKQuantity(unit: .percent(), doubleValue: 0.21)), 21, accuracy: 0.00001)
    XCTAssertEqual(Set(HealthMetric.catalog.map { $0.key }).count, 19)
  }
}

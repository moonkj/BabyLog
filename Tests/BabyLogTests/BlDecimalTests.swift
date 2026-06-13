// BlDecimalTests.swift
// 키·몸무게 입력 파싱(blDecimal) — 콤마 로케일/공백/빈값/비숫자 처리.

import XCTest
@testable import BabyLog

final class BlDecimalTests: XCTestCase {

    func test_parsesDotDecimal() {
        XCTAssertEqual(blDecimal("78.5"), 78.5)
    }

    func test_parsesCommaAsDecimalSeparator() {
        XCTAssertEqual(blDecimal("8,5"), 8.5)
    }

    func test_trimsWhitespace() {
        XCTAssertEqual(blDecimal("  10 "), 10)
    }

    func test_integerString() {
        XCTAssertEqual(blDecimal("12"), 12)
    }

    func test_emptyStringIsNil() {
        XCTAssertNil(blDecimal(""))
        XCTAssertNil(blDecimal("   "))
    }

    func test_nonNumericIsNil() {
        XCTAssertNil(blDecimal("abc"))
        XCTAssertNil(blDecimal("10kg"))
    }
}

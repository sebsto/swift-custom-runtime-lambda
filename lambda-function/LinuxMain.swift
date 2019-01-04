import XCTest

import helloTests

var tests = [XCTestCaseEntry]()
tests += helloTests.__allTests()

XCTMain(tests)

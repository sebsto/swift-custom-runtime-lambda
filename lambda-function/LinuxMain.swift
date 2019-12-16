//
// LambdaRuntime API implementation for Swift 5
//
// Published under dual Apache 2.0 
// https://www.apache.org/licenses/LICENSE-2.0
// Sebastien Stormacq, (c) 2018 stormacq.com 
//

import XCTest

import helloTests

var tests = [XCTestCaseEntry]()
tests += helloTests.__allTests()

XCTMain(tests)

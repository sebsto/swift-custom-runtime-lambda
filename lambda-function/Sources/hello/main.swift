//
// LambdaRuntime API implementation for Swift 4
//
// Published under dual Apache 2.0 
// https://www.apache.org/licenses/LICENSE-2.0
// Sebastien Stormacq, (c) 2018 stormacq.com 
//
import Foundation

import LambdaRuntime
import HeliumLogger
import LoggerAPI

let logger = HeliumLogger(.verbose)
Log.logger = logger
#if DEBUG
    HeliumLogger.use(.debug)
#endif

func handler(context: Context, event: LambdaEvent) throws -> LambdaResponse {
    Log.debug("lambda handler")

    return [
        "result": event["key1"] ?? "unknown key : key1"
    ]
}

try LambdaRuntime(handler).run()


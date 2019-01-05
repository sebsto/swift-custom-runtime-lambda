//
// LambdaRuntime API implementation for Swift 4
//
// Published under dual Apache 2.0 
// https://www.apache.org/licenses/LICENSE-2.0
// Sebastien Stormacq, (c) 2018 stormacq.com 
//
import Foundation

import LambdaRuntime
import LoggerAPI

func handler(context: Context, event: LambdaEvent) throws -> LambdaResponse {
    Log.debug("Starting lambda handler")

    // fetch data from https://httpbin.org/json
    let endpoint = "https://httpbin.org/get?value=\(event["key1"] ?? "no value provided")"
    Log.debug(endpoint)
    let (data, response, error) = URLSession.shared.synchronousDataTask(with: endpoint) //if url is invalid, it is a programming error
    
    // did we receive an error ?
    guard error == nil else {
        return  [ "error": error!.localizedDescription ]
    }
    
    guard let event = data else {
        return  [ "error": "no body returned" ]
    }
    
    guard let resp = response else {
        return  [ "error": "no response returned" ]
    }
    
    if (resp.statusCode == 200) {
        return try JSONify(jsonData: event) as LambdaEvent
    } else {
        return  [ "error": String(resp.statusCode) ]
    }

}

try LambdaRuntime(handler).run()


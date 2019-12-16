//
// LambdaRuntime API implementation for Swift 5
//
// Published under dual Apache 2.0 
// https://www.apache.org/licenses/LICENSE-2.0
// Sebastien Stormacq, (c) 2018 stormacq.com 
//
import Foundation

import LambdaRuntime
import LoggerAPI

import SwiftyRequest

func handler(context: Context, event: LambdaEvent, completion: @escaping LambdaCallback) throws -> Void {
    Log.debug("Starting lambda handler")

    let request = RestRequest(method: .get, url: "https://httpbin.org/get?value=\(event["key1"] ?? "no key1 provided")")
    
    request.responseString { result in
        switch result {
        case .success(let response):
            print("Success")
            completion([ "result": "\(response.body)" ])
        case .failure(let error):
            print("Failure")
            completion([ "result": "\(error)" ])
        }
    }
    
    return

}

try LambdaRuntime(handler).run()

// idea for a v2

// func handler(context: Context, event: LambdaEvent) throws -> LambdaResponse {
//     Log.debug("Starting lambda handler")

//     // fetch data from https://httpbin.org/json
//     let endpoint = "https://httpbin.org/get?value=\(event["key1"] ?? "no value provided")"
//     Log.debug(endpoint)
//     let (data, response, error) = URLSession.shared.synchronousDataTask(with: endpoint) //if url is invalid, it is a programming error
    
//     // did we receive an error ?
//     guard error == nil else {
//         return  [ "error": error!.localizedDescription ]
//     }
    
//     guard let event = data else {
//         return  [ "error": "no body returned" ]
//     }
    
//     guard let resp = response else {
//         return  [ "error": "no response returned" ]
//     }
    
//     if (resp.statusCode == 200) {
//         return try JSONify(jsonData: event) as LambdaEvent
//     } else {
//         return  [ "error": String(resp.statusCode) ]
//     }

// }

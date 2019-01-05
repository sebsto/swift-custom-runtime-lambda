//
// LambdaRuntime API implementation for Swift 4
//
// Published under Apache 2.0 License
// https://www.apache.org/licenses/LICENSE-2.0
// Sebastien Stormacq, (c) 2018 stormacq.com
//

import Foundation
import HeliumLogger
import LoggerAPI

protocol LambaRuntimeAPI {
    
    func nextEvent() throws -> (headers : [AnyHashable:Any], event : LambdaEvent)
    func invocationSuccess(awsRequestId : String, response: LambdaResponse) throws -> Void
    func invocationError(awsRequestId : String, error: Error) -> Void
    func initError(error: Error) -> Void

}

class LambadRuntimeAPICommon {
    func JSONify(jsonString : String) throws -> LambdaEvent  {
        let jsonData = jsonString.data(using: .utf8)
        return try JSONify(jsonData: jsonData)
    }
    
    func JSONify(jsonData : Data?) throws -> LambdaEvent  {
        
        let d = String(data: jsonData!, encoding: .utf8)
        Log.debug("Received : \(d!)")
        var result : LambdaEvent = [:]
        if let data = jsonData {
            do {
                result = try JSONSerialization.jsonObject(with: data, options: []) as! LambdaEvent
            } catch {
                Log.warning("\(data) can not be serialized to JSON Dictionary : \(error)")
                throw error
            }
        }
        
        return result
    }
}

// this is the class we'll use when running inside a Lambda container
class LambdaContainerRuntimeAPI : LambadRuntimeAPICommon, LambaRuntimeAPI  {
    
    private let lambdaRuntimeAPIEndpoint : String
    
    init(_ apiEndpoint: String) {
        lambdaRuntimeAPIEndpoint = apiEndpoint

        // initialize logger
        let logger = HeliumLogger(.verbose)
        Log.logger = logger
        #if DEBUG
            HeliumLogger.use(.debug)
        #endif
    }
    
    func nextEvent() throws -> (headers : [AnyHashable:Any], event : LambdaEvent) {
        
        let paths = Paths()
        
        // synchronously call next event API to collect data and headers
        let endpoint = "http://\(lambdaRuntimeAPIEndpoint)\(paths.next)"
        let (data, response, error) = URLSession.shared.synchronousDataTask(with: endpoint) //if url is invalid, it is a programming error
        
        // did we receive an error ?
        guard error == nil else {
            throw RuntimeError.NEXT_EVENT_ERROR(error?.localizedDescription ?? "no localized error message")
        }
        
        guard let event = data else {
            throw RuntimeError.NEXT_EVENT_NO_DATA
        }
        
        guard let resp = response else {
            throw RuntimeError.MISSING_HTTP_HEADERS
        }
        
        if (resp.statusCode == 200) {
            return (resp.allHeaderFields, try JSONify(jsonData: event) as LambdaEvent)
        } else {
            let m = String(data: event, encoding: .utf8)
            throw RuntimeError.NEXT_EVENT_ERROR("\(resp.statusCode) : \(String(describing: m))")
        }
    }

    func invocationSuccess(awsRequestId : String, response: LambdaResponse) throws -> Void {
        let paths = Paths(awsRequestId: awsRequestId)
        
        // synchronously call init error API to collect data and headers
        let url = URL(string: "http://\(lambdaRuntimeAPIEndpoint)\(paths.invocationSuccess)")
        
        var request = URLRequest(url: url!) // if URL is not correct, here this is a programming error
        request.httpMethod = "POST"
        do {
            let data = try JSONSerialization.data(withJSONObject: response)
            request.httpBody = data
            _ = URLSession.shared.synchronousDataTask(with: request)
        } catch {
            throw RuntimeError.INVALID_HANDLER_RESPONSE
        }
    }

    func invocationError(awsRequestId : String, error: Error) -> Void {
        let paths = Paths(awsRequestId: awsRequestId)
        
        // synchronously call init error API to collect data and headers
        let url = URL(string: "http://\(lambdaRuntimeAPIEndpoint)\(paths.invocationError)")
        
        var request = URLRequest(url: url!) // if URL is not correct, here this is a programming error
        request.httpMethod = "POST"
        request.httpBody = error.localizedDescription.data(using: .utf8)
        _ = URLSession.shared.synchronousDataTask(with: request)
    }

    func initError(error: Error) -> Void {
        let paths = Paths()
        
        // synchronously call init error API to collect data and headers
        let url = URL(string: "http://\(lambdaRuntimeAPIEndpoint)\(paths.initError)")

        var request = URLRequest(url: url!) // if URL is not correct, here this is a programming error
        request.httpMethod = "POST"
        request.httpBody = error.localizedDescription.data(using: .utf8)
        _ = URLSession.shared.synchronousDataTask(with: request)
    }
}

// this is the class we'll use when running inside a docker container for testing.
// docker will use LAMBDA_EVENT environment variable or read event.json file in current directory
class LambdaDockerRuntimeAPI : LambadRuntimeAPICommon, LambaRuntimeAPI {
    
    private var invocationCounter = 0
    private let MAX_INVOCATIONS = 1
    
    override init() {
        // initialize logger
        let logger = HeliumLogger(.verbose)
        Log.logger = logger
        #if DEBUG
            HeliumLogger.use(.debug)
        #endif
    }
    
    // provide the next event by first attempting to read LAMBDA_EVENT env variable,
    // then tryig to read event.json in current directory.
    func nextEvent() throws -> (headers : [AnyHashable:Any], event : LambdaEvent) {
        
        // circuit breaker for testing mode
        if invocationCounter >= MAX_INVOCATIONS {
            return ([:],[:])
        } else {
            invocationCounter = invocationCounter + 1
        }
        
        // read environment variable or file
        
        var result : LambdaEvent?
        do {
            // let's try to read the env variable first
            Log.debug("Reading event from environment variable")
            let env =  ProcessInfo.processInfo.environment
            result = try JSONify(jsonString: env["LAMBDA_EVENT"] ?? "")
        }
        catch {
            Log.warning("LAMBDA_EVENT is not a valid JSON document\n\(error.localizedDescription)")
            
            // not working, let's try to read a file
            let file = FileManager.default.currentDirectoryPath + "/test/event.json"
            Log.debug("Let's try to read a file (\(file))")
            
            // content of the file
            do {
                let url = URL(fileURLWithPath: file)
                result = try JSONify(jsonString: String(contentsOf: url, encoding: .utf8))
            }
            catch {
                Log.error("\(file) can not be serialized to JSON Dictionary : \(error)")
                throw RuntimeError.NEXT_EVENT_ERROR("Both env var LAMBDA_EVENT and file event.json fails to serialize to JSON\n\(error.localizedDescription)")
            }
        }
        
        // prepare mocked headers
        let headers : [AnyHashable:Any] = [
            "Lambda-Runtime-Aws-Request-Id": "request-id-123",
            "Lambda-Runtime-Invoked-Function-Arn": "local-execution-mocked",
            "Lambda-Runtime-Trace-Id": "x-trace-id-123",
            "Lambda-Runtime-Deadline-Ms" : "3000"
        ]
        
        Log.debug("LAMBDA_EVENT = \(String(describing: result))")
        return (headers, result!)
    }
    func invocationSuccess(awsRequestId : String, response: LambdaResponse) -> Void {
        Log.info("SUCCESS : Request-Id = \(awsRequestId)\n\(response)")
    }
    func invocationError(awsRequestId : String, error: Error) -> Void {
        Log.info("ERROR : Request-Id = \(awsRequestId)\n\(error.localizedDescription)")
    }
    func initError(error: Error) -> Void {
        Log.info("INIT ERROR : \(error.localizedDescription)")
    }
}

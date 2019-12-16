//
// LambdaRuntime API implementation for Swift 5
//
// Published under dual Apache 2.0 
// https://www.apache.org/licenses/LICENSE-2.0
// Sebastien Stormacq, (c) 2018 stormacq.com 
//

import Foundation

import HeliumLogger
import LoggerAPI

public class LambdaRuntime {
    
    private var context : Context
    private let runtimeApi : LambaRuntimeAPI
    private let handler : AsyncLambdaHandler
    
    private let MAX_RETRIES = 3
    private var retry = 0

//    // support sync handler for ease of programing
//    public init(_ handler: SyncLambdaHandler) throws {
//    }

    // initialize the runtime and load shared libraries, if any
    // also takes the custom handler that will be the core of the lambda function
    public init(_ handler: @escaping AsyncLambdaHandler) throws {

        // initialize logger
        let logger = HeliumLogger(.verbose)
        Log.logger = logger
        #if DEBUG
            HeliumLogger.use(.debug)
        #endif

        do {

            // read environment variables
            let env =  ProcessInfo.processInfo.environment
            
            // are we running in Lambda or Docker (for testing)
            // prepare matching runtimeApi implementation
            if let runtimeApiEndpoint = env["AWS_LAMBDA_RUNTIME_API"] {
                
                Log.debug("Looks like we are running inside Lambda, initializing RuntimeApi")
                self.runtimeApi = LambdaContainerRuntimeAPI(runtimeApiEndpoint)
                
                // prepare context
                self.context = try Context()

            } else {
                
                Log.debug("Looks like we are running outside Lambda Containers, initializing Mock RuntimeApi")
                self.runtimeApi = LambdaDockerRuntimeAPI()

                // prepare mocked up context
                self.context = Context(environment:
                    ["AWS_LAMBDA_FUNCTION_NAME" : "mockup function name",
                     "AWS_LAMBDA_FUNCTION_VERSION":  "1",
                     "AWS_LAMBDA_LOG_GROUP_NAME" : "log group name",
                     "AWS_LAMBDA_LOG_STREAM_NAME" : "log stream name",
                     "AWS_LAMBDA_FUNCTION_MEMORY_SIZE" : "1024",
                     ])
            }
            
            // store the handler
            self.handler = handler
        }
        catch {
            Log.error("Error during initialization : \(error.localizedDescription)")
            self.runtimeApi.initError(error: error)
            throw error
        }
    }

    // main lambda event loop
    public func run() -> Void {
        
        while (retry < MAX_RETRIES) {
            
            var headers : [AnyHashable:Any]
            var event : LambdaEvent
            
            // 1. fetch next event
            do {
                Log.debug("Fetching next event")
                (headers, event) = try runtimeApi.nextEvent()
            } catch {
                Log.error("Error during next event API call : \(error.localizedDescription). Going to retry")
                retry = retry + 1
                sleep(UInt32(retry * 1))
                continue
            }
            
            //circuit breaker when testing
            if headers.isEmpty && event.isEmpty {
                Log.debug("Circuit Breaker activated (we are in test mode), exiting the loop")
                break
            }
            
            // 2. prepare environment variable and context based on headers received
            do {
                try self.context.invocationSpecificInit(headers: headers)
            } catch {
                // there is not so much we can do here, it is mostly caused by programming error
                Log.error("Can not initialize context from headers : \(headers)\n\(error)")
                
                // let's retry in case this is a transient error
                retry = retry + 1
                sleep(UInt32(retry * 1))
                continue
            }
            if let xtraceRuntimeTraceId = context.runtimeTraceId {
                setenv("_X_AMZN_TRACE_ID", xtraceRuntimeTraceId, 0)
            }

            guard let awsRequestId = self.context.awsRequestId else {
                Log.error("awsRequestId is not defined, this is a programming error")
                return
            }
            
            // 3. call handler
            do {
                var response: LambdaResponse?
                let dispatchGroup = DispatchGroup()
                dispatchGroup.enter()
                do {
                    try handler(self.context, event, { (result) in
                        response = result
                        Log.debug("Handler returned : \(String(describing: response))")
                        dispatchGroup.leave()
                    })
                } catch {
                    response = ["error" : "\(error)"]
                    dispatchGroup.leave()
                }
                dispatchGroup.wait()
                
                // 4. call success or error
                try runtimeApi.invocationSuccess(awsRequestId: awsRequestId, response: response!)
            } catch {
                Log.debug("An error occured in the handler or when signaling the success :  \(error)")
                runtimeApi.invocationError(awsRequestId: awsRequestId, error: error)
            }
        }
        
        if (retry >= MAX_RETRIES) {
            Log.error("Runtime exceeded max number of retries : \(retry)")
        } else {
            Log.info("We are in test mode, running the loop only once.")
        }
    }
}

public func JSONify(jsonString : String) throws -> LambdaEvent  {
    let jsonData = jsonString.data(using: .utf8)
    return try JSONify(jsonData: jsonData)
}

public func JSONify(jsonData : Data?) throws -> LambdaEvent  {
    
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


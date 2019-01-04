//
// LambdaRuntime API implementation for Swift 4
//
// Published under Apache 2.0 License 
// https://www.apache.org/licenses/LICENSE-2.0
// Sebastien Stormacq, (c) 2018 stormacq.com 
//

import Foundation

//
// lambda function event data
//
public typealias LambdaEvent = [String:Any]

//
// lambda function response
//
public typealias LambdaResponse = [String:Any]

//
// Lambda handler function
//
public typealias LambdaHandler = (Context, LambdaEvent) throws -> LambdaResponse

// this is the Context object passed to the handler.
// constant values are identical accross invocation and are initialized from the container env variables
// variable values are specific to one invocation and are initialized after the call to getNext()
//
public struct Context {
    public let functionName: String
    public let functionVersion: String
    public let memoryLimitInMB: String
    public let logGroupName: String
    public let logStreamName: String
    
    // the below values are invocation specific
    public var awsRequestId: String?
    public var invokedFunctionArn: String?
    public var deadlineMs : Int?
    public var runtimeTraceId : String?
    public var identity : [String:String]?
    public var clientContext : [String:String]?

    public init() throws {
        // environment variables are documented at
        // https://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html
        let environment : [String:String] = ProcessInfo.processInfo.environment
        guard let fn = environment["AWS_LAMBDA_FUNCTION_NAME"] else {
            throw RuntimeError.MISSING_ENVIRONMENT_VARIABLE("AWS_LAMBDA_FUNCTION_NAME")
        }
        self.functionName = fn
        
        guard let fv = environment["AWS_LAMBDA_FUNCTION_VERSION"] else {
            throw RuntimeError.MISSING_ENVIRONMENT_VARIABLE("AWS_LAMBDA_FUNCTION_VERSION")
        }
        self.functionVersion = fv
        
        guard let lgn = environment["AWS_LAMBDA_LOG_GROUP_NAME"] else {
            throw RuntimeError.MISSING_ENVIRONMENT_VARIABLE("AWS_LAMBDA_LOG_GROUP_NAME")
        }
        self.logGroupName = lgn
        
        guard let lsn = environment["AWS_LAMBDA_LOG_STREAM_NAME"] else {
            throw RuntimeError.MISSING_ENVIRONMENT_VARIABLE("AWS_LAMBDA_LOG_STREAM_NAME")
        }
        self.logStreamName =  lsn
        
        guard let ml =  environment["AWS_LAMBDA_FUNCTION_MEMORY_SIZE"] else {
            throw RuntimeError.MISSING_ENVIRONMENT_VARIABLE("AWS_LAMBDA_FUNCTION_MEMORY_SIZE")
        }
        self.memoryLimitInMB = ml
    }
    
    // used when testing with docker
    // mockup environment variables
    public init(environment: [String:String]) {
        self.functionName = environment["AWS_LAMBDA_FUNCTION_NAME"]!
        self.functionVersion = environment["AWS_LAMBDA_FUNCTION_VERSION"]!
        self.logGroupName = environment["AWS_LAMBDA_LOG_GROUP_NAME"]!
        self.logStreamName = environment["AWS_LAMBDA_LOG_STREAM_NAME"]!
        self.memoryLimitInMB = environment["AWS_LAMBDA_FUNCTION_MEMORY_SIZE"]!
    }
    
    public mutating func invocationSpecificInit(headers: [AnyHashable:Any]) throws {
        // headers are documented at
        // https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html#runtimes-api-next
        guard let ar = headers["Lambda-Runtime-Aws-Request-Id"] as? String else {
            throw RuntimeError.MISSING_RUNTIME_HEADER("Lambda-Runtime-Aws-Request-Id")
        }
        self.awsRequestId = ar
        
        guard let farn = headers["Lambda-Runtime-Invoked-Function-Arn"] as? String else {
            throw RuntimeError.MISSING_RUNTIME_HEADER("Lambda-Runtime-Invoked-Function-Arn")
        }
        self.invokedFunctionArn = farn
        
        guard let d = headers["Lambda-Runtime-Deadline-Ms"] as? String else {
            throw RuntimeError.MISSING_RUNTIME_HEADER("Lambda-Runtime-Deadline-Ms")
        }
        self.deadlineMs = Int(d)
        
        guard let t = headers["Lambda-Runtime-Trace-Id"] as? String else {
            throw RuntimeError.MISSING_RUNTIME_HEADER("Lambda-Runtime-Aws-Request-Id")
        }
        self.runtimeTraceId = t

        // TODO certainly need more processing to loop over subvalues
//        guard let cc = headers["Lambda-Runtime-Client-Context"] as? [String:String] else {
//            throw RuntimeError.MISSING_RUNTIME_HEADER("Lambda-Runtime-Client-Context")
//        }
//        self.clientContext = cc
//
//        guard let ci = headers["Lambda-Runtime-Cognito-Identity"] as? [String:String] else {
//            throw RuntimeError.MISSING_RUNTIME_HEADER("Lambda-Runtime-Cognito-Identity")
//        }
//        self.identity = ci
    }

    // return true when the current time is before deadline for this function invocation
    public func isBeforedeadline() -> Bool {
        // TODO
        return true
    }
}

struct Paths  {
    private let awsRequestId : String?
    
    init() {
        awsRequestId = nil
    }
    
    init(awsRequestId: String) {
        self.awsRequestId = awsRequestId
    }
    
    let next = "/2018-06-01/runtime/invocation/next"
    
    var invocationSuccess : String  {
        get {
            guard let ar = self.awsRequestId else {
                return "missing aws request id"
            }
            return "/2018-06-01/runtime/invocation/\(ar)/response"
        }
    }
    
    var invocationError : String {
        get {
            guard let ar = self.awsRequestId else {
                return "missing aws request id"
            }
            return "/2018-06-01/runtime/invocation/\(ar)/error"
        }
    }
    
    let initError = "/2018-06-01/runtime/init/error"
}

enum RuntimeError : Error {
    case NEXT_EVENT_ERROR(String)
    case NEXT_EVENT_NO_DATA
    case MISSING_RUNTIME_HEADER(String)
    case MISSING_ENVIRONMENT_VARIABLE(String)
    case MISSING_AWS_REQUEST_ID
    case MISSING_HTTP_HEADERS
    case INVALID_HANDLER_RESPONSE // JSON Serialization failed on Lambda Handler Response
}


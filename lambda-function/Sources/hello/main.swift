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
    Log.debug("from handler")

    let url = URL(string: "https://www.amazon.com")!
    
    let semaphore = DispatchSemaphore(value: 0)
    
    print("Connecting to \(url)")
    let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
        if let e = error {
            print("\(e)")
        } else {
            guard let resp = response as! HTTPURLResponse? else { return print("A")}
            print("Response = \(resp.statusCode)")
            guard let data = data else { return print("B") }
            print("Received data = \(data)")
            print(String(data: data, encoding: .utf8)!)
        }
        semaphore.signal()
    }
    
    task.resume()
    _ = semaphore.wait(timeout: .distantFuture)


    return [
        "result": event["key1"] ?? "unknown key : key1"
    ]
}

try LambdaRuntime(handler).run()


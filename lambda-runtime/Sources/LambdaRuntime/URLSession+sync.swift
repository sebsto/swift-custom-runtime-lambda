//
// LambdaRuntime API implementation for Swift 5
//
// Published under Apache 2.0 License
// https://www.apache.org/licenses/LICENSE-2.0
// Sebastien Stormacq, (c) 2018 stormacq.com
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import LoggerAPI

/* 
 * Add synchronous capabilities to URLSession.
 * shamelessy copied from (and slightly modified)
 * https://stackoverflow.com/questions/26784315/can-i-somehow-do-a-synchronous-http-request-via-nsurlsession-in-swift
 */

extension URLSession {

    public func synchronousDataTask(with url: String) -> (Data?, HTTPURLResponse?, Error?) {
        if let realUrl = URL(string: url) {
            let urlRequest = URLRequest(url: realUrl)
            let (data, response, error) = synchronousDataTask(with: urlRequest)
            return (data, response as? HTTPURLResponse, error)
        } else {
            let error = NSError(domain: NSURLErrorDomain, code: URLError.badURL.rawValue, userInfo: nil)
            return (nil, nil, error)
        }
    }

    public func synchronousDataTask(with url: URL) -> (Data?, HTTPURLResponse?, Error?) {
        let urlRequest = URLRequest(url: url)
        let (data, response, error) = synchronousDataTask(with: urlRequest)
        return (data, response as? HTTPURLResponse, error)
    }

    public func synchronousDataTask(with urlrequest: URLRequest) -> (data: Data?, response: URLResponse?, error: Error?) {
        
        var data: Data?
        var response: URLResponse?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

//        Log.debug("Going to invoke dataTask with: \(urlrequest)")
        let dataTask = self.dataTask(with: urlrequest) {
            data = $0
            response = $1
            error = $2
        
//            Log.debug("Got response from URL :  \(String(describing: data)), \(String(describing: response)), \(String(describing: error))")
            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)

        return (data, response, error)
    }
}

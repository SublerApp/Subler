//
//  NetworkUtilities.swift
//  Subler
//
//  Created by Damiano Galassi on 04/08/2017.
//

import Foundation

public protocol Runnable {
    @discardableResult func runAsync() -> Runnable
    @discardableResult func run() -> Runnable
    func cancel()
}

public protocol Cancellable {
    func cancel()
    var sessionTask: URLSessionTask? { get set }
}

class RunnableTask<T> : Runnable {

    private var queue: DispatchQueue
    private var cancelled: Bool = false
    private let search: () -> T
    private let completionHandler: (T) -> Void

    init(search: @escaping @autoclosure () -> T, completionHandler: @escaping (T) -> Void) {
        self.search = search
        self.completionHandler = completionHandler
        self.queue = DispatchQueue(label: "SearchTaskQueue")
    }

    @discardableResult public func runAsync() -> Runnable {
        DispatchQueue.global().async {
            self.run()
        }
        return self
    }

    @discardableResult public func run() -> Runnable {
        let results = self.search()
        queue.sync {
            if self.cancelled == false {
                self.completionHandler(results)
            }
        }
        return self
    }

    public func cancel() {
        queue.sync {
            self.cancelled = true
        }
    }
}

// MARK: - URL Utilities

private let allowedChars: CharacterSet = {
    var chars = CharacterSet.urlQueryAllowed
    chars.remove(charactersIn: "&+=?;")
    return chars
}()

extension String {

    func urlEncoded() -> String {
        return self.precomposedStringWithCompatibilityMapping.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? ""
    }

}

extension URLSession {

    static func data(from url: URL, httpMethod: String = "GET", httpBody: Data? = nil, header: [String:String] = [:], cachePolicy: URLRequest.CachePolicy = URLRequest.CachePolicy.useProtocolCachePolicy) -> Data? {

        let sem = DispatchSemaphore(value: 0)
        var downloadData : Data? = nil

        URLSession.dataTask(with: url, httpMethod: httpMethod, httpBody: httpBody, header: header, cachePolicy: cachePolicy) { (data, response) in
            downloadData = data
            sem.signal()
            }.resume()

        sem.wait()

        return downloadData
    }

    static func dataAndResponse(from url: URL, httpMethod: String = "GET", httpBody: Data? = nil, header: [String:String] = [:], cachePolicy: URLRequest.CachePolicy = URLRequest.CachePolicy.useProtocolCachePolicy) -> (Data?, URLResponse?) {

        let sem = DispatchSemaphore(value: 0)
        var downloadData : Data? = nil
        var downloadResponse: URLResponse? = nil

        URLSession.dataTask(with: url, httpMethod: httpMethod, httpBody: httpBody, header: header, cachePolicy: cachePolicy) { (data, response) in
            downloadData = data
            downloadResponse = response
            sem.signal()
            }.resume()

        sem.wait()

        return (downloadData, downloadResponse)
    }

    static func dataTask(with url: URL, httpMethod: String = "GET", httpBody: Data? = nil, header: [String:String] = [:], cachePolicy: URLRequest.CachePolicy = URLRequest.CachePolicy.useProtocolCachePolicy, completionHandler: @escaping (Data?, URLResponse?) -> Void) -> URLSessionTask {

        var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: 30.0)
        request.httpMethod = httpMethod
        request.httpBody = httpBody
        for (key, value) in header {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in

            if let data = data {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

                if statusCode == 200 {
                    completionHandler(data, response)
                }
                else {
                    completionHandler(nil, response)
                }
            }
            else {
                completionHandler(nil, response)
            }
        }

        return task
    }

}

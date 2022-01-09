//
//  CachingFetcher.swift
//  
//
//  Created by Janis Kirsteins on 09/01/2022.
//

//import Foundation
//#if os(Linux)
//import FoundationNetworking
//#endif
import NIO
import Logging
import ServerFramework
import AsyncHTTPClient

public enum CachingFetcherError : Error
{
    case httpRequestFailed(statusCode: UInt, reasonPhrase: String)
}

public class CachingFetcher {
    let cache: Cache
    let logger: Logger
    let cacheExpiry: TimeAmount
    let client: HTTPClient
    
    public init(
        client: HTTPClient,
        cache: Cache,
        name: String?,
        cacheExpiry: TimeAmount) {
        self.client = client
        self.cache = cache
        self.cacheExpiry = cacheExpiry
        self.logger = Logger(label: "\(String(describing: CachingFetcher.self))[\(name ?? "untitled")]")
    }
    
    public func fetch(url: URL, key: String, requestCallback: ((inout HTTPClient.Request)->())? = nil) -> EventLoopFuture<ByteBuffer?>
    {
        return self.cache.get(key).flatMap { (cached: ByteBuffer?) -> EventLoopFuture<ByteBuffer?> in
            do {
                // Try fetch cached
                if let result = cached {
                    self.logger.debug("Returning cached data")
                    return self.client.eventLoopGroup.next().makeSucceededFuture(result)
                }
                self.logger.info("No cached data found")
                
                var request = try HTTPClient.Request(url: url.serialized(), method: .GET)
                requestCallback?(&request)
                
                let httpExec = self.client.execute(request: request)
                
                // Fetch
                let res = httpExec.flatMapResult { response -> Result<ByteBuffer?, Error> in
                    if response.status == .ok {
                        return .success(response.body)
                    } else {
                        return .failure(CachingFetcherError.httpRequestFailed(statusCode: response.status.code, reasonPhrase: response.status.reasonPhrase))
                    }
                }
                
                // Cache result
                return res.flatMap { (byteBuffer: ByteBuffer?) -> EventLoopFuture<ByteBuffer?> in
                    
                    if let buffer = byteBuffer {
                        let seconds = Int(self.cacheExpiry.nanoseconds / 1_000_000_000)
                        return self.cache.put(buffer, at: key, expiresIn: seconds ).map {
                            return buffer
                        }
                    } else {
                        return self.cache.clear(at: key).map {
                            return nil
                        }
                    }
                }
            } catch {
                return self.client.eventLoopGroup.next().makeFailedFuture(error)
            }
        }
    }
}

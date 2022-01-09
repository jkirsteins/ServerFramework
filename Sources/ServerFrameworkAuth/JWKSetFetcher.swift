//
//  JWKSetFetcher.swift
//  
//
//  Created by Janis Kirsteins on 09/01/2022.
//

import ServerFramework
import Logging
import ExtrasJSON

public class AppleJWKSetFetcher : JWKSetFetcher
{
    override var url: URL {
        URL("https://appleid.apple.com/auth/keys")!
    }
    class override var cacheKey: String {
        String(reflecting: AppleJWKSetFetcher.self)
    }
}

public class Auth0JWKSetFetcher : JWKSetFetcher
{
    override var url: URL {
        URL("https://\(self.domain)/.well-known/jwks.json")!
    }
    class override var cacheKey: String {
        String(reflecting: AppleJWKSetFetcher.self)
    }
    
    let domain: String
    
    public init(domain: String, fetcher: CachingFetcher) {
        self.domain = domain
        super.init(fetcher: fetcher)
    }
}

public enum JWKSetFetcherError : Error, CustomStringConvertible
{
    case noDataFound(at: URL)
    
    public var description: String {
        switch(self) {
        case .noDataFound(let url):
            return "No data was returned from \(url)"
        }
    }
}

public class JWKSetFetcher
{
    var url: URL {
        URL("https://appleid.apple.com/auth/keys")!
    }
    
    class var cacheKey: String {
        String(reflecting: JWKSetFetcher.self)
    }
    
    let logger = Logger(label: String(describing: JWKSetFetcher.self))
    let fetcher: CachingFetcher
    
    public init(fetcher: CachingFetcher) {
        self.fetcher = fetcher
    }
    
    public func fetch() async throws -> JWKSet
    {
        guard var byteBuffer = try await self.fetcher.fetch(url: self.url, key: Self.cacheKey).get() else {
            throw JWKSetFetcherError.noDataFound(at: self.url)
        }
        
        return try XJSONDecoder().decode(JWKSet.self, from: byteBuffer.readBytes(length: byteBuffer.readableBytes)!)
    }
}


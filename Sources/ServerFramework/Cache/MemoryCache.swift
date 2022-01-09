//
//  MemoryCache.swift
//
//
//  Created by Janis Kirsteins on 13/12/2021.
//

import Foundation
import NIO
import Logging

/// A `Cache` implementation that wraps `NSCache` from Foundation.
public class MemoryCache : Cache
{
    public func namespaced(_ ns: String) -> Cache {
        let newpath = "\(nspath).\(ns)"
        return MemoryCache(elg: self.elg, cache: self.cache, nspath: newpath)
    }
    
    let logger = Logger.create(for: MemoryCache.self)
    
    private class CacheItem : NSObject {
        internal init(data: ByteBuffer, expiresAt: Int?) {
            self.data = data
            self.expiresAt = expiresAt
        }
        
        let data: ByteBuffer
        let expiresAt: Int?
    }
    
    public func put(_ value: ByteBuffer, at key: String, expiresIn: Int?) -> EventLoopFuture<Void> {
        let realKey = makeKey(key)
        
        let expiresAt: Int?
        if let expiresIn = expiresIn {
            expiresAt = self.now() + expiresIn
        } else {
            expiresAt = nil
        }
        
        let item = CacheItem(data: value, expiresAt: expiresAt)
        self.cache.setObject(item, forKey: realKey)
        
        return elg.next().makeSucceededVoidFuture()
    }
    
    fileprivate func now() -> Int {
        time(nil)*1000
    }
    
    public func get(_ key: String) -> EventLoopFuture<ByteBuffer?> {
        let realKey = makeKey(key)
        let result = self.cache.object(forKey: realKey) as CacheItem?
        
        if let expiresAt = result?.expiresAt {
            guard expiresAt > self.now() else {
                self.logger.debug("Found expired result for key \(realKey)")
                return elg.next().makeSucceededFuture(nil as ByteBuffer?)
            }
        }
        
        self.logger.debug("Found result \(String(describing: result)) for key \(realKey)")
        return elg.next().makeSucceededFuture(result?.data)
    }
    
    public func clear(at key: String) -> EventLoopFuture<Void> {
        let realKey = makeKey(key)
        self.cache.removeObject(forKey: realKey)
        return elg.next().makeSucceededVoidFuture()
    }
    
    
    private func makeKey(_ key: String) -> NSString {
        return "\(self.nspath).\(key)" as NSString
    }
    
    private let cache: NSCache<NSString, CacheItem>
    private let nspath: String
    let elg: EventLoopGroup
    
    public convenience init(elg: EventLoopGroup) {
        self.init(elg: elg, cache: Self.createCache(), nspath: "root")
    }
    
    private init(elg: EventLoopGroup, cache: NSCache<NSString, CacheItem>, nspath: String) {
        self.cache = cache
        self.elg = elg
        self.nspath = nspath
    }
    
    private static func createCache() -> NSCache<NSString, CacheItem> {
        let result = NSCache<NSString, CacheItem>()
        result.name = "Timed cache"
        result.countLimit = 10
        return result
    }
}

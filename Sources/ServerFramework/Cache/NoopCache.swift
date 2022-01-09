//
//  NoopCache.swift
//  
//
//  Created by Janis Kirsteins on 09/01/2022.
//

import NIO

/// Cache implementation that does nothing.
public class NoopCache : Cache
{
    let elg: EventLoopGroup
    
    public init(elg: EventLoopGroup)
    {
        self.elg = elg
    }
    
    public func namespaced(_ ns: String) -> Cache {
        self
    }
    
    public func put(_ value: ByteBuffer, at key: String, expiresIn: Int?) -> EventLoopFuture<Void> {
        return self.elg.next().makeSucceededVoidFuture()
    }
    
    public func clear(at key: String) -> EventLoopFuture<Void> {
        return self.elg.next().makeSucceededVoidFuture()
    }
    
    public func get(_ key: String) -> EventLoopFuture<ByteBuffer?> {
        return self.elg.next().makeSucceededFuture(nil)
    }
}

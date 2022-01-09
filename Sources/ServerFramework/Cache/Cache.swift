//
//  Cache.swift
//  
//
//  Created by Janis Kirsteins on 09/01/2022.
//

import NIO

public protocol Cache
{
    func namespaced(_ ns: String) -> Cache
    func get(_ key: String) -> EventLoopFuture<ByteBuffer?>
    func put(_ value: ByteBuffer, at key: String, expiresIn: Int?) -> EventLoopFuture<Void>
    func clear(at key: String) -> EventLoopFuture<Void>
}

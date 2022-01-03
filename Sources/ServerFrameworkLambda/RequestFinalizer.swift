//
//  RequestFinalizer.swift
//  
//
//  Created by Janis Kirsteins on 03/01/2022.
//

import NIO

public protocol RequestFinalizer
{
    func beforeRequestTerminates() -> EventLoopFuture<Void>
}

//
//  Middleware.swift
//  
//
//  Created by Janis Kirsteins on 04/12/2021.
//

public typealias Next = ( Any... ) async throws -> Void

public typealias Middleware =
(
    // req
    HttpRequest,
    
    // res
    ResponseHandler,
    
    // dependencies
    ScopedDependencies,
    
    @escaping Next ) async throws -> Void


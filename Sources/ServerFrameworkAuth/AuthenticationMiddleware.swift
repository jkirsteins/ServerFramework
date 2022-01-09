//
//  AuthenticationMiddleware.swift
//
//
//  Created by Janis Kirsteins on 18/12/2021.
//

import ServerFramework
import Logging

fileprivate let logger = Logger(label: "AuthenticationMiddleware")

@available(macOS 12.0.0, *)
public func authentication(req  : HttpRequest,
                    res  : ResponseHandler,
                    deps : ScopedDependencies,
                    next : @escaping Next) async throws
{
    guard let verifier: UserProvider = deps.resolve() else {
        logger.error("Could not resolve UserProvider. Authentication will never be successful")
        try await next()
        return
    }
    
    logger.debug("Using UserProvider \(String(reflecting: verifier))")
    
    let user: User?
    
    do {
        user = try await verifier.extract(from: req)
    } catch {
        logger.error("Unexpected error while authenticating the user: \(String(describing: error))")
        res.internalServerError()
        return
    }
    
    if let user = user {
        logger.debug("Registering user in request scope: \(String(describing: user))")
        deps.register(instance: user)
    } else {
        logger.debug("User not determined")
    }
    
    try await next()
}

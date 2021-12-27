////
////  AuthenticationMiddleware.swift
////  
////
////  Created by Janis Kirsteins on 18/12/2021.
////
//
//import Logging
//import SwiftJWT
//
//fileprivate let logger = Logger(label: "AuthenticationMiddleware")
//
//@available(macOS 12.0.0, *)
//func authentication(req  : HttpRequest,
//                    res  : ServerResponse,
//                    deps : ScopedDependencies,
//                    next : @escaping Next) async throws
//{
//    guard let verifier: ApiUserProvider = deps.resolve() else {
//        logger.error("Could not resolve ApiUserProvider. authentication will never be successful")
//        try await next()
//        return
//    }
//    
//    logger.debug("Resolved ApiUserProvider \(String(reflecting: verifier))")
//    
//    let user: User?
//    
//    if let token = verifier.extractToken(from: req) {
//        do {
//            user = try await verifier.verify(token: token)
//        } catch JWTError.failedVerification {
//            user = nil
//        } catch {
//            logger.error("Failed to verify authentication token", error: error)
//            user = nil
//        }
//    } else {
//        user = nil
//    }
//    
//    if let user = user {
//        logger.debug("Registering user in request scope: \(user.description)")
//        deps.register(instance: user)
//    } else {
//        logger.debug("User not determined")
//    }
//    
//    try await next()
//}

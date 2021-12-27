//
//  Router.swift
//  
//
//  Created by Janis Kirsteins on 04/12/2021.
//

import Logging

open class Router {
    
    fileprivate let logger = Logger.create(for: Router.self)
    
    /// The sequence of Middleware functions.
    private var middleware = [ Middleware ]()
    
    /// Add another middleware (or many) to the list
    open func use(_ middleware: Middleware...) {
        self.middleware.append(contentsOf: middleware)
    }
    
    public init()
    {
        
    }
    
    /// Request handler. Calls its middleware list
    /// in sequence until one doesn't call `next()`.
    open func handle(request        : HttpRequest,
                response       : ResponseHandler,
                dependencies   : Dependencies) async throws
    {
        let upperNext: Next = {
            (items : Any...) in // the final handler
            
            response.json(NotFoundResponse("No middleware handled the request"))
        }
        
        try await dependencies.scoped { scopedDependencies async throws in
            let stack = self.middleware
            guard !stack.isEmpty else { return try await upperNext() }
            
            var next : Next? = { ( args : Any... ) async throws in }
            var i = stack.startIndex
            next = { (args : Any...) async throws in
                // grab next item from matching middleware array
                let middleware = stack[i]
                i = stack.index(after: i)
                
                let isLast = i == stack.endIndex
                
                do {
                    try await middleware(request, response, scopedDependencies, isLast ? upperNext : next!)
                } catch {
                    response.json(ErrorResponse(error))
                    return
                }
            }
            
            try await next!()
        }
    }
    
    /// Register a middleware which triggers on a `GET`
    /// with a specific path prefix.
    public func get(_ path: String = "",
             middleware: @escaping Middleware)
    {
        use { req, res, deps, next in
            
//            guard let reqUrl = URL(string: req.head.uri) else {
//                print("Error: failed to parse request URI \(req.head.uri)")
//                return try await next()
//            }
            
            self.logger.debug("Comparing \(req.method) \(req.url.path) to GET \(path)")
            
            guard req.method == .get,
                  req.url.path == path
            else { return try await next() }
            
            try await middleware(req, res, deps, next)
        }
    }
    
    /// Register a middleware which triggers on a `POST`
    /// with a specific path prefix.
    public func post(_ path: String = "",
             middleware: @escaping Middleware)
    {
        use { req, res, deps, next in
            
            self.logger.debug("Comparing \(req.method) \(req.url.path) to POST \(path)")
            
            guard req.method == .post,
                  req.url.path == path
            else { return try await next() }
            
            try await middleware(req, res, deps, next)
        }
    }
}

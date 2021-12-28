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
                } catch HttpRequestError.couldNotDeserializeRequest {
                    response.json(ErrorResponse(HttpRequestError.couldNotDeserializeRequest, statusCode: 400))
                    return
                } catch {
                    response.json(ErrorResponse(error))
                    return
                }
            }
            
            try await next!()
        }
    }
    
    // TODO: unify method handlers
    // TODO: add test for handling urldecoding in paths
    
    /// Register a middleware which triggers on a `GET`
    /// with a specific path prefix.
    public func get(_ path: String = "",
             middleware: @escaping Middleware)
    {
        // TODO: middlewares should be throwing
        let pattern = try! PathPatternParser(path)
        use { req, res, deps, next in
                        
            let decodedPath = req.url.path.percentDecoded()
            
            self.logger.debug("Comparing \(req.method) \(decodedPath) to GET \(path)")
            let patternMatch = pattern.match(against: decodedPath)
            
            guard req.method == .get, let pathComponents = patternMatch.components
            else {
                return try await next()
            }
            
            req.populatePathItems(pathComponents)
            
            try await middleware(req, res, deps, next)
        }
    }
    
    /// Register a middleware which triggers on a `DELETE`
    /// with a specific path prefix.
    public func delete(_ path: String = "",
             middleware: @escaping Middleware)
    {
        // TODO: middlewares should be throwing
        let pattern = try! PathPatternParser(path)
        use { req, res, deps, next in
            
            let decodedPath = req.url.path.percentDecoded()
                        
            self.logger.debug("Comparing \(req.method) \(decodedPath) to DELETE \(path)")
            let patternMatch = pattern.match(against: decodedPath)
            
            guard req.method == .delete, let pathComponents = patternMatch.components
            else {
                return try await next()
            }
            
            req.populatePathItems(pathComponents)
            
            try await middleware(req, res, deps, next)
        }
    }
    
    /// Register a middleware which triggers on a `POST`
    /// with a specific path prefix.
    public func post(_ path: String = "",
             middleware: @escaping Middleware)
    {
        // TODO: middlewares should be throwing
        let pattern = try! PathPatternParser(path)
        use { req, res, deps, next in
            
            let decodedPath = req.url.path.percentDecoded()
            
            self.logger.debug("Comparing \(req.method) \(decodedPath) to POST \(path)")
            let patternMatch = pattern.match(against: decodedPath)
            
            guard req.method == .post, let pathComponents = patternMatch.components
            else {
                return try await next()
            }
            
            req.populatePathItems(pathComponents)
            
            try await middleware(req, res, deps, next)
        }
    }
}

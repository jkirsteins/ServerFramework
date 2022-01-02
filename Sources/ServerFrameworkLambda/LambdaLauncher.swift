//
//  LambdaLauncher.swift
//  
//
//  Created by Janis Kirsteins on 13/12/2021.
//

import AWSLambdaRuntime
import AWSLambdaEvents
import NIO
import Logging
import Lifecycle
import Foundation

import ServerFramework

/// Launcher that provides a lambda event loop to the application
public class LambdaLauncher : Launcher
{
    let logger = Logger.create(for: LambdaLauncher.self)
    
    public func run(dependencyProvider: DependencyProvider, factory appFactory: @escaping (Dependencies)->Router) {
        Lambda.run { (ctx: Lambda.InitializationContext) throws -> Lambda.Handler in
            let deps = dependencyProvider.dependencies
            
            // ELG
            deps.register(instance: ctx.eventLoop as EventLoopGroup)
            
            // BTS
            let bgTaskScheduler = BackgroundTaskScheduler(eventLoopGroup: ctx.eventLoop)
            deps.register(instance: bgTaskScheduler)
            
            // LIFECYCLE (not using Service because we don't want to hook into signals manually)
            let lifecycle: ServiceLifecycle
            if let existingLifecycle: ServiceLifecycle = deps.resolve() {
                self.logger.info("Using pre-existing ServiceLifecycle")
                lifecycle = existingLifecycle
            } else {
                self.logger.info("Creating and registering a new ServiceLifecycle")
                lifecycle = ServiceLifecycle()
                deps.register(instance: lifecycle)
            }
            
            // LIFECYCLE CONFIG
            lifecycle.register(label: String(describing: BackgroundTaskScheduler.self),
                               start: .none, // .async(bgTaskScheduler.start),
                               shutdown: .async(bgTaskScheduler.waitAndShutdown)
            )
            
            let app = appFactory(deps)
            
            self.logger.info("Starting the lifecycle...")
            
            var error: Error? = nil
            lifecycle.start {
                error = $0
            }
            
            if let error = error {
                self.logger.error("Lifecycle start failed: \(String(describing: error))")
                throw error
            }
            
            self.logger.info("Creating the Lambda handler...")
            return LambdaHandler(app: app, dependencies: deps, lifecycle: lifecycle)
        }
    }
    
    public init() {
        
    }
}

public enum LambdaHandlerError : Error, CustomStringConvertible
{
    case invalidConfiguration(_ message: String)
    case invalidEvent(_ message: String)
    
    public var description: String {
        switch(self) {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .invalidEvent(let message):
            return "Invalid event: \(message)"
        }
    }
}

/// Processes Lambda requests. Turns incoming APIGateway requests into HTTP requests, and turns
/// the HTTP responses back into APIGateway responses
struct LambdaHandler: EventLoopLambdaHandler {
    typealias In = APIGateway.V2.Request
    typealias Out = APIGateway.V2.Response
    
    let logger = Logger.create(for: LambdaHandler.self)
    
    let app: Router
    let dependencies: Dependencies
    let lifecycle: ServiceLifecycle
    
    init(app: Router, dependencies: Dependencies, lifecycle: ServiceLifecycle) {
        self.app = app
        self.dependencies = dependencies
        self.lifecycle = lifecycle
    }
    
    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        self.logger.info("Shutting down via handler shutdown callback...")
        return context.eventLoop.submit {
            self.logger.debug("Cleaning up lifecycle...")
            lifecycle.shutdown()
        }
    }

    func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out> {
        
        let promise = context.eventLoop.makePromise(of: APIGateway.V2.Response.self)
        
        let resp = LambdaServerResponse(promise: promise)
        
        guard let url = URL("https://lambda-unknown\(event.rawPath)?\(event.rawQueryString)") else {
            let message = "Could not construct an invocation URL from \(event.rawPath) and \(event.rawQueryString)"
            self.logger.error(Logger.Message(stringLiteral: message))
            return context.eventLoop.makeFailedFuture(LambdaHandlerError.invalidEvent(message))
        }
        // ^ NOTE: important to not have slash after host
        
        let bodyBuffer: ByteBuffer?
        if let bodyStr = event.body {
            bodyBuffer = ByteBuffer(string: bodyStr)
        } else {
            bodyBuffer = nil
        }
        
        let request = HttpRequest(
            headers: event.headers.map({ HttpHeaderKeyValuePair(name: $0, value: $1) }),
            method: HttpMethod.parse(event.context.http.method.rawValue),
            body: bodyBuffer,
            url: url)
        
        self.logger.debug("Handling request \(request)")
        Task {
            do {
                // promise.success will be invoked on the `resp`
                try await app.handle(request: request, response: resp, dependencies: dependencies)
            } catch {
                self.logger.error("Error in LambdaLauncher.handle: \(String(describing: error))")
                promise.fail(error)
            }
        }
        
        return promise.futureResult
    }
}

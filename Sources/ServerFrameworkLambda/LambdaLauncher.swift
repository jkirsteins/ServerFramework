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

import ServerFramework

/// Launcher that provides a lambda event loop to the application
class LambdaLauncher : Launcher
{
    let logger = Logger.create(for: LambdaLauncher.self)
    
    func run(dependencyProvider: DependencyProvider, factory appFactory: @escaping (Dependencies)->Router) {
        Lambda.run { (ctx: Lambda.InitializationContext) throws -> Lambda.Handler in
            let deps = dependencyProvider.dependencies
            deps.register(instance: ctx.eventLoop as EventLoopGroup)
        
            let app = appFactory(deps)
            self.logger.info("Launching app \(app)")
            return LambdaHandler(app: app, dependencies: deps)
        }
    }
}

/// Processes Lambda requests. Turns incoming APIGateway requests into HTTP requests, and turns
/// the HTTP responses back into APIGateway responses
struct LambdaHandler: EventLoopLambdaHandler {
    typealias In = APIGateway.V2.Request
    typealias Out = APIGateway.V2.Response
    
    let app: Router
    let dependencies: Dependencies
    
    init(app: Router, dependencies: Dependencies) {
        self.app = app
        self.dependencies = dependencies
    }

    func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out> {
        
        let promise = context.eventLoop.makePromise(of: APIGateway.V2.Response.self)
        
        let resp = LambdaServerResponse(promise: promise)
        
        guard let url = URL("https://lambda-unknown\(event.rawPath)?\(event.rawQueryString)") else {
            fatalError("Failed to determine url for lambda invocation")
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
        
        Task {
            do {
                try await app.handle(request: request, response: resp, dependencies: dependencies)
            } catch {
                fatalError("Error in LambdaLauncher.handle \(error)")
            }
        }
                
        return promise.futureResult
    }
}

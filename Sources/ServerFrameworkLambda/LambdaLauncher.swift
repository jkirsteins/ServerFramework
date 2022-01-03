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

enum LambdaLauncherError: Error, CustomStringConvertible {
    case initTimedOut
    
    var description: String {
        switch(self) {
        case .initTimedOut:
            return "Initialization timed out."
        }
    }
}

/// Launcher that provides a lambda event loop to the application
public class LambdaLauncher : Launcher
{
    let logger = Logger.create(for: LambdaLauncher.self)
    
    public func run(dependencyProvider: DependencyProvider, factory appFactory: @escaping (Dependencies)->Router) {
        Lambda.run { (ctx: Lambda.InitializationContext) throws -> Lambda.Handler in
            let deps = dependencyProvider.dependencies
            
            // ELG
            deps.register(instance: ctx.eventLoop as EventLoopGroup)
            
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
            
            let app = appFactory(deps)
            
            self.logger.info("Starting the lifecycle...")
            
            var error: Error? = nil
            
            let semaphore = DispatchSemaphore(value: 0)

            lifecycle.start {
                error = $0
                semaphore.signal()
            }
            
            guard .success == semaphore.wait(timeout: .now() + .seconds(15)) else {
                throw LambdaLauncherError.initTimedOut
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

//public struct LambdaProxy: Codable {
//    /// Context contains the information to identify the AWS account and resources invoking the Lambda function.
//    public struct Context: Codable {
//        public struct HTTP: Codable {
//            public let method: HTTPMethod
//            public let path: String
//            public let `protocol`: String
//            public let sourceIp: String
//            public let userAgent: String
//        }
//
//        /// Authorizer contains authorizer information for the request context.
//        public struct Authorizer: Codable {
//            /// JWT contains JWT authorizer information for the request context.
//            public struct JWT: Codable {
//                public let claims: [String: String]
//                public let scopes: [String]?
//            }
//
//            public let jwt: JWT
//        }
//
//        public let accountId: String
//        public let apiId: String
//        public let domainName: String
//        public let domainPrefix: String
//        public let stage: String
//        public let requestId: String
//
//        public let http: HTTP
//        public let authorizer: Authorizer?
//
//        /// The request time in format: 23/Apr/2020:11:08:18 +0000
//        public let time: String
//        public let timeEpoch: UInt64
//    }
//
//    public let version: String
//    public let routeKey: String
//    public let rawPath: String
//    public let rawQueryString: String
//
//    public let cookies: [String]?
//    public let headers: HTTPHeaders
//    public let queryStringParameters: [String: String]?
//    public let pathParameters: [String: String]?
//
//    public let context: Context
//    public let stageVariables: [String: String]?
//
//    public let body: String?
//    public let isBase64Encoded: Bool
//
//    enum CodingKeys: String, CodingKey {
//        case version
//        case routeKey
//        case rawPath
//        case rawQueryString
//
//        case cookies
//        case headers
//        case queryStringParameters
//        case pathParameters
//
//        case context = "requestContext"
//        case stageVariables
//
//        case body
//        case isBase64Encoded
//    }
//}

protocol LambdaHandlerRestAPI: EventLoopLambdaHandler where In == APIGateway.Request, Out == APIGateway.Response {
    
}

protocol LambdaHandlerHttpAPI: EventLoopLambdaHandler where In == APIGateway.V2.Request, Out == APIGateway.V2.Response {
    
}

/// Processes Lambda requests. Turns incoming APIGateway requests into HTTP requests, and turns
/// the HTTP responses back into APIGateway responses
struct LambdaHandler: LambdaHandlerRestAPI {
    typealias In = APIGateway.Request
    typealias Out = APIGateway.Response
    
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
        
        let promise = context.eventLoop.makePromise(of: Out.self)
        
        if let eventData = try? JSONEncoder().encode(event), let eventDataStr = String(data: eventData, encoding: .utf8) {
            self.logger.debug("Processing \(String(describing: eventDataStr))")
        } else {
            self.logger.debug("Can't log request")
        }
        
        
        let resp = LambdaServerResponse_RestApi(promise: promise)
        
//        guard let url = URL("https://lambda-unknown\(event.rawPath)?\(event.rawQueryString)") else {
//            let message = "Could not construct an invocation URL from \(event.rawPath) and \(event.rawQueryString)"
//            self.logger.error(Logger.Message(stringLiteral: message))
//            return context.eventLoop.makeFailedFuture(LambdaHandlerError.invalidEvent(message))
//        }
//        // ^ NOTE: important to not have slash after host
        
        let rawQueryString = (event.queryStringParameters ?? [:]).map { "\($0)=\($1)" }.joined(separator: "&")
        
        let host = event.headers["Host"] ?? "lambda-unknown"
        let portPart = event.headers["X-Forwarded-Port"] != nil ? ":\(String(describing: event.headers["X-Forwarded-Port"]))" : ""
        let scheme = event.headers["X-Forwarded-Proto"] ?? "https"
        guard let url = URL("\(scheme)://\(host)\(portPart)\(event.path)?\(rawQueryString)") else {
            let message = "Could not construct an invocation URL from \(event.path) and \(rawQueryString)"
            self.logger.error(Logger.Message(stringLiteral: message))
            return context.eventLoop.makeFailedFuture(LambdaHandlerError.invalidEvent(message))
        }
        
        let bodyBuffer: ByteBuffer?
        if let bodyStr = event.body {
            bodyBuffer = ByteBuffer(string: bodyStr)
        } else {
            bodyBuffer = nil
        }
        
        let request = HttpRequest(
            headers: event.headers.map({ HttpHeaderKeyValuePair(name: $0, value: $1) }),
            method: HttpMethod.parse(event.httpMethod.rawValue),
            body: bodyBuffer,
            url: url)
        
        self.logger.debug("Handling request \(request)")
        Task {
            do {
                // promise.success will be invoked on the `resp`
                try await app.handle(request: request, response: resp, dependencies: dependencies)
            } catch {
                self.logger.error("Error in LambdaLauncher.handle: \(String(describing: error))")
                resp.json(ErrorResponse(error))
            }
        }
        
        if let finalizer: RequestFinalizer = self.dependencies.resolve() {
            self.logger.debug("Performing tasks before request finishes")
            return promise.futureResult.and(finalizer.beforeRequestTerminates()).map { $0.0 }
        }
        
        self.logger.debug("Request is terminating without cleanup tasks")
        return promise.futureResult
    }
}

//
//  SwiftNioLauncher.swift
//  
//
//  Created by Janis Kirsteins on 13/12/2021.
//

import NIO
import NIOHTTP1
import Logging
import Lifecycle

import ServerFramework

fileprivate final class HTTPHandler : ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
    var activeMessage: IncomingMessage? = nil
    
    let router : Router
    let dependencies: Dependencies
    let logger = Logger.create(for: HTTPHandler.self)
    
    init(router: Router, dependencies: Dependencies) {
        self.router = router
        self.dependencies = dependencies
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let head):
            activeMessage = IncomingMessage(head: head)
        case .end(let headers):
            
            guard let activeMessage = activeMessage else {
                logger.critical("Received HTTP request end but there's no active message. Closing channel...")
                _ = context.channel.close()
                return
            }
            
            if let _ = headers {
                logger.fatalAndDie("Why are we receiving headers here? Not implemented. Assuming they come from .head")
            }
            
            let response = NIOServerResponse(channel: context.channel)
            
            Task {
                do {
                    let req = try activeMessage.createRequest()
                    try await router.handle(request: req, response: response, dependencies: self.dependencies)
                } catch {
                    response.handleError_nio(error)
                }
            }
        case .body(let buffer):
            guard let activeMessage = activeMessage else {
                logger.fatalAndDie("ERROR: received HTTP request body but there's no active message")
            }
            
            activeMessage.buffer = buffer
        }
    }
}

/// Launch the application using SwiftNIO 
public class SwiftNioLauncher : Launcher {
    let port: Int
    let host: String
    
    let logger = Logger.create(for: SwiftNioLauncher.self)
    
    public init(host: String = "0.0.0.0", port: Int = 8080) {
        self.port = port
        self.host = host
    }
    
    func createManagedEventLoopOrGroup(lifecycle: ServiceLifecycle) -> EventLoopGroup
    {
        let realElg = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        lifecycle.registerShutdown(
            label: "eventLoopGroup",
            .sync({
                self.logger.debug("Shutting down event loop group gracefully")
                try realElg.syncShutdownGracefully()
            })
        )
        return realElg
    }
    
    public func run(dependencyProvider: DependencyProvider, factory: @escaping (Dependencies) -> Router) {
        
        let deps = Dependencies(parent: dependencyProvider.dependencies)
        
        let lifecycle: ServiceLifecycle
        
        if let existingLifecycle: ServiceLifecycle = deps.resolveRequired() {
            self.logger.info("Using pre-existing ServiceLifecycle")
            lifecycle = existingLifecycle
        } else {
            self.logger.info("Creating and registering a new ServiceLifecycle")
            lifecycle = ServiceLifecycle()
            deps.register(instance: lifecycle)
        }
        
        let elg = createManagedEventLoopOrGroup(lifecycle: lifecycle)
        
        deps.register(instance: elg)
        
        let bgTaskScheduler = BackgroundTaskScheduler()
        deps.register(instance: bgTaskScheduler)
        
        lifecycle.register(label: "BackgroundTaskScheduler",
                           start: .async(bgTaskScheduler.start),
                           shutdown: .async(bgTaskScheduler.waitAndShutdown)
        )
        
        let app = factory(deps)
        
        let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR)
        let bootstrap = ServerBootstrap(group: elg)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(reuseAddrOpt, value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(router: app, dependencies: deps))
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(reuseAddrOpt, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        do {
            let serverChannel =
            try bootstrap.bind(host: self.host, port: self.port)
                .wait()
            self.logger.info("Server running on: \(serverChannel.localAddress!)")
            
            try lifecycle.startAndWait()
            self.logger.info("Shutting down")
        }
        catch {
            self.logger.fatalAndDie("Failed to start server: \(String(describing: error))")
        }
    }
}

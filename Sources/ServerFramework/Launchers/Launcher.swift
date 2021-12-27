//
//  Launcher.swift
//  
//
//  Created by Janis Kirsteins on 13/12/2021.
//

/// Interface for running the application. Implementations
/// can spin up an HTTP server, or proxy Lambda invocations,
/// or provide a test-interface
public protocol Launcher {
    func run(dependencyProvider: DependencyProvider, factory: @escaping (Dependencies)->Router)
}

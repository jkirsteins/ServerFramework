//
//  Dependencies.swift
//
//
//  Created by Janis Kirsteins on 08/12/2021.
//

import Swinject
import Logging

public protocol DependencyProvider {
    var dependencies: Dependencies { get }
}

public protocol DepResolver
{
    func resolve<T>() -> T?
    func resolveRequired<T>() -> T
}

public extension DepResolver
{
    func resolveRequired<T>() -> T
    {
        guard let res: T = self.resolve() else {
            fatalError("Could not resolve required instance \(T.self)")
        }
        
        return res
    }
}

public class ResolverOnly : DepResolver
{
    let resolver: Resolver
    
    init(resolver: Resolver) {
        self.resolver = resolver
    }
    
    public func resolve<T>() -> T? {
        return self.resolver.resolve(T.self)
    }
}

public class DependencyEntry<T>
{
    let serviceEntry: ServiceEntry<T>
    
    fileprivate init(serviceEntry: ServiceEntry<T>)
    {
        self.serviceEntry = serviceEntry
    }
    
    public func asSingleton() {
        self.serviceEntry.inObjectScope(.container)
    }
}

//public class DependencyScope
//{
//    fileprivate let internalScope: ObjectScope
//
//    fileprivate init()
//    {
//        self.internalScope = ObjectScope(storageFactory: PermanentStorage.init)
//    }
//}

public class ScopedDependencies : DepResolver, DepRegistry
{
    public func register<T>(factory: @escaping (ResolverOnly) -> T) -> DependencyEntry<T> {
        self.dependencies.register(factory: factory)
    }
    
    public func register<T>(instance: T) {
        return self.dependencies.register(instance: instance)
    }
    
    public func resolve<T>() -> T? {
        self.dependencies.resolve()
    }
    
    internal init(dependencies: Dependencies) {
        self.dependencies = Dependencies(parent: dependencies)
    }
    
    /// The dependency container that is a request-specific child of the global dependency container
    let dependencies: Dependencies
}

public protocol DepRegistry
{
    func register<T>(instance: T)
    func register<T>(factory: @escaping (ResolverOnly)->T) -> DependencyEntry<T>
}

public extension DepRegistry
{
    func register<T>(factory: @escaping ()->T) -> DependencyEntry<T> {
        return self.register { _ in factory() }
    }
}

public class Dependencies : DepResolver, DepRegistry, DependencyProvider
{
    let container: Container
    let logger = Logger.create(for: Dependencies.self)
    
    public var dependencies: Dependencies { self }
    
    public required init(parent: Dependencies?)
    {
        if let parent = parent {
            self.container = Container(parent: parent.container)
        } else {
            self.container = Container()
        }
    }
    
    public convenience init() {
        self.init(parent: nil)
    }
    
    public func register<T>(instance: T) {
        let entry = self.container.register(T.self) { _ in instance }
        entry.inObjectScope(.container)
    }
    
    public func register<T>(factory: @escaping (ResolverOnly)->T) -> DependencyEntry<T> {
        let res = self.container.register(T.self) { r in
            factory(ResolverOnly(resolver: r))
        }
        
        return DependencyEntry(serviceEntry: res)
    }
    
    func scoped(_ callback: (ScopedDependencies) async throws->()) async throws {
        let scoped = ScopedDependencies(dependencies: self)
        try await callback(scoped)
    }
    
    func register<T>(factory: @escaping ()->T) -> DependencyEntry<T> {
        return self.register { _ in factory() }
    }
    
    public func resolve<T>() -> T? {
        return self.container.resolve(T.self)
    }
}

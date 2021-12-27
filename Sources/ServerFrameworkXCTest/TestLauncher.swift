//
//  TestLauncher.swift
//
//
//  Created by Janis Kirsteins on 20/12/2021.
//

import ServerFramework
import ExtrasJSON
import Dispatch

fileprivate class TestServerResponse<DataType> : ResponseHandler where DataType: Codable
{
    var headers = HttpHeaders()
    
    func setHeader(_ name: String, to value: String) {
        self.headers[name] = value
    }
    
    var sentResponse: ApiResponse<DataType>? = nil
    
    func json<T>(_ content: T?, status: Int) where T : Encodable {
        guard self.sentResponse == nil else {
            fatalError("Can't send response twice")
        }
        
        if let content = content {
            let encoded = try! XJSONEncoder().encode(content)
            let decoded: DataType? = try! XJSONDecoder().decode(DataType.self, from: encoded)
            
            self.sentResponse = ApiResponse<DataType>(data: decoded, status: status)
        } else {
            self.sentResponse = ApiResponse<DataType>(body: nil, status: status)
        }
    }
}

class TestLauncher<Response> : Launcher where Response: Codable
{
    let request: HttpRequest
    fileprivate let responseHandler = TestServerResponse<Response>()
    
    var nothingHandled = false
    var timedOut = false
    var globalError: Error? = nil
    
    init(request: HttpRequest)
    {
        self.request = request
    }
    
    var sentResponse: ApiResponse<Response>? { responseHandler.sentResponse }
    
    static func simulate(path: String, deps: DependencyProvider, headers: HttpHeaders = HttpHeaders(), appFactory: ((Dependencies)->Router)) -> ApiResponse<Response>? {
        
        let testRequest = HttpRequest(headers: headers, method: .get, body: nil, url: URL("http://test-server:8080\(path)")!)
        
        let runner = TestLauncher<Response>(request: testRequest)
        
        runner.run(dependencyProvider: deps) {
            deps -> Router in
            
            let locallyOverridableDeps = Dependencies(parent: deps)
            
            return appFactory(locallyOverridableDeps)
        }
        
        return runner.sentResponse
    }
    
    func run(dependencyProvider: DependencyProvider, factory: (Dependencies) -> Router) {
        
        // Child dependencies will be empty, and anything we register in there will override
        // the base dependencies.
        let childDependencies = Dependencies(parent: dependencyProvider.dependencies)
        
        let app = factory(childDependencies)
        
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            defer {
                semaphore.signal()
            }
            
            do {
                try await app.handle(
                    request: self.request,
                    response: self.responseHandler,
                    dependencies: childDependencies)
            } catch {
                globalError = error
            }
        }
         
        self.timedOut = semaphore.wait(timeout: .now() + 15) == .timedOut
    }
}

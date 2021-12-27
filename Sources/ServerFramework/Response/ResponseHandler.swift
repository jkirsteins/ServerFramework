//
//  ResponseHandler.swift
//  
//
//  Created by Janis Kirsteins on 27/12/2021.
//

public protocol ResponseHandler
{
    var headers: HttpHeaders { get }
    
    /// Send a Codable object as JSON to the client.
    func json<T: Encodable>(_ content: T?, status: Int)
    
    func setHeader(_ name: String, to value: String)
}
    
public extension ResponseHandler {
    func json<T: Encodable>(_ response: ApiResponse<T>) {
        self.json(response.body, status: response.status)
    }
    
    func empty() {
        self.json(NoContentResponse())
    }
}


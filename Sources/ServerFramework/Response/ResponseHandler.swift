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
    func internalServerError() {
        self.json(ApiResponseBody(data: "Internal Server Error", status: 500), status: 500)
    }
    
    func notAuthorized() {
        self.json(ApiResponseBody(data: "Not authorized", status: 403), status: 403)
    }
    
    func json<T: Encodable>(_ response: ApiResponse<T>) {
        self.json(response.body, status: response.status)
    }
    
    func empty() {
        self.json(NoContentResponse())
    }
    
    func badRequest(_ message: String) {
        self.json(BadRequestResponse(message))
    }
}


//
//  ApiResponse.swift
//  
//
//  Created by Janis Kirsteins on 20/12/2021.
//

public struct ApiResponseBody<T> : Encodable where T: Encodable
{
    public let data: T?
    public let status: Int
}

public class ApiResponse<T> : Encodable where T: Encodable
{
    public init(body: ApiResponseBody<T>?, status: Int) {
        self.body = body
        self.status = status
    }
    
    public convenience init(data: T?, status: Int) {
        self.init(body: ApiResponseBody(data: data, status: status), status: status)
    }
    
    public let body: ApiResponseBody<T>?
    public let status: Int
}

public struct Nothing : Codable
{
}

public class NoContentResponse : ApiResponse<Nothing> {
    public init() {
        super.init(body: nil, status: 204)
    }
}

public class AcceptedResponse : ApiResponse<Nothing> {
    public init() {
        super.init(body: nil, status: 202)
    }
}

public class BadRequestResponse : ApiResponse<String?> {
    public init(_ message: String = "Invalid request") {
        super.init(body: ApiResponseBody(data: message, status: 400), status: 400)
    }
}

public class OkResponse<T> : ApiResponse<T> where T: Encodable {
    public init(_ data: T?) {
        super.init(body: ApiResponseBody(data: data, status: 200), status: 200)
    }
}

public class NotFoundResponse : ApiResponse<NotFoundResponse.ResponseData> {
    
    static let statusCode = 404
    
    public struct ResponseData : Codable {
        let message: String
    }
    
    public init(_ message: String? = nil) {
        if let message = message {
            super.init(body: ApiResponseBody(data: ResponseData(message: message), status: Self.statusCode), status: Self.statusCode)
        } else {
            super.init(body: ApiResponseBody(data: nil, status: Self.statusCode), status: Self.statusCode)
        }
    }
}

public class ErrorResponse : ApiResponse<ErrorResponse.ErrorData>
{
    public struct ErrorData : Encodable
    {
        let message: String
        
        public init(_ error: Error) {
            // localizedDescription comes from Foundation
            self.message = String(describing: error)
        }
    }
    
    public init(_ error: Error, statusCode: Int = 500)
    {
        super.init(body: ApiResponseBody(data: ErrorData(error), status: statusCode), status: statusCode)
    }
}

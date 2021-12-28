//
//  HttpRequest.swift
//  
//
//  Created by Janis Kirsteins on 20/12/2021.
//

import NIO
import Logging
import ExtrasJSON

public enum HttpRequestError : Error
{
    case couldNotDeserializeRequest
}

public class HttpRequest
{
    let logger = Logger.create(for: HttpRequest.self)
    public init(headers: HttpHeaders, method: HttpMethod, body: ByteBuffer?, url: URL) {
        self.headers = headers
        self.method = method
        self.body = body
        self.url = url
    }
    
    public let headers: HttpHeaders
    public let method: HttpMethod
    public let body: ByteBuffer?
    public let url: URL
    private var pathComponents: [String: String]? = nil
    
    public func queryItem(_ id: String) -> String? {
        return self.url.formParams.get(id)
    }
    
    public func pathItem(_ id: String) -> String? {
        guard let components = self.pathComponents else {
            return nil
        }
        return components[id]
    }
    
    public func populatePathItems(_ components: [String: String]) {
        self.pathComponents = components
    }
    
    public func json<T: Decodable>() throws -> T {

        guard var buffer = self.body, let bytes = buffer.readBytes(length: buffer.readableBytes) else {
            throw HttpRequestError.couldNotDeserializeRequest
        }
        
        do {
            return try XJSONDecoder().decode(
                T.self,
                from: bytes)
        } catch {
            self.logger.error("Failed deserializing body to object: \(String(describing: error))")
            throw HttpRequestError.couldNotDeserializeRequest
        }
    }
}


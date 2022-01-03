//
//  LambdaServerResponse.swift
//  
//
//  Created by Janis Kirsteins on 27/12/2021.
//

import NIO
import AWSLambdaEvents
import ExtrasJSON
import Logging

import ServerFramework

class LambdaServerResponse_HttpApi : ResponseHandler {
    var headers: HttpHeaders = HttpHeaders()
    fileprivate let logger = Logger.create(for: LambdaServerResponse_HttpApi.self)
    
    func setHeader(_ name: String, to value: String) {
        self.headers[name] = value
    }
    
    public  let promise : EventLoopPromise<APIGateway.V2.Response>
    
    public init(promise: EventLoopPromise<APIGateway.V2.Response>) {
        self.promise = promise
    }
    
    func handleError(_ error: Error) {
        promise.succeed(APIGateway.V2.Response(statusCode: .internalServerError, headers: nil, body: "Internal error \(error)", isBase64Encoded: false, cookies: nil))
    }
    
    enum LambdaResponseHandlerError : Error {
        case failedToSerializeUTF8String(bytes: [UInt8])
    }
    
    /// Send a Codable object as JSON to the client.
    public func json<T: Encodable>(_ model: T?, status: Int = 200) {
        // create a Data struct from the Codable object
        let responseString: String
        let responseSize: Int
        do {
            let bytes = try XJSONEncoder().encode(model)
            responseSize = bytes.count
            
            guard let responseStringCandidate = String(bytes: bytes, encoding: .utf8) else {
                throw LambdaResponseHandlerError.failedToSerializeUTF8String(bytes: bytes)
            }
            
            responseString = responseStringCandidate
        }
        catch {
            self.logger.error("Failed to serialize response to an UTF-8 string: \(error.localizedDescription)")
            promise.fail(error)
            return
        }
        
        // setup JSON headers
        self.headers["Content-Type"]   = "application/json"
        self.headers["Content-Length"] = String(describing: responseSize)
        
        let cookies: [String]? = nil
        
        let awsHeaders: AWSLambdaEvents.HTTPHeaders = Dictionary(uniqueKeysWithValues: self.headers.map { ($0.name, $0.value) })
        
        promise.succeed(
            APIGateway.V2.Response(
                statusCode: AWSLambdaEvents.HTTPResponseStatus(
                    code: UInt(status)
                ),
                headers: awsHeaders,
                body: responseString,
                isBase64Encoded: false,
                cookies: cookies
            )
        )
        return
    }
}

class LambdaServerResponse_RestApi : ResponseHandler {
    var headers: HttpHeaders = HttpHeaders()
    fileprivate let logger = Logger.create(for: LambdaServerResponse_RestApi.self)
    
    func setHeader(_ name: String, to value: String) {
        self.headers[name] = value
    }
    
    public  let promise : EventLoopPromise<APIGateway.Response>
    
    public init(promise: EventLoopPromise<APIGateway.Response>) {
        self.promise = promise
    }
    
    func handleError(_ error: Error) {
        promise.succeed(APIGateway.Response(statusCode: .internalServerError, headers: nil, multiValueHeaders: nil, body: "Internal error \(error)", isBase64Encoded: false))
    }
    
    enum LambdaResponseHandlerError : Error {
        case failedToSerializeUTF8String(bytes: [UInt8])
    }
    
    /// Send a Codable object as JSON to the client.
    public func json<T: Encodable>(_ model: T?, status: Int = 200) {
        // create a Data struct from the Codable object
        let responseString: String
        let responseSize: Int
        do {
            let bytes = try XJSONEncoder().encode(model)
            responseSize = bytes.count
            
            guard let responseStringCandidate = String(bytes: bytes, encoding: .utf8) else {
                throw LambdaResponseHandlerError.failedToSerializeUTF8String(bytes: bytes)
            }
            
            responseString = responseStringCandidate
        }
        catch {
            self.logger.error("Failed to serialize response to an UTF-8 string: \(error.localizedDescription)")
            promise.fail(error)
            return
        }
        
        // setup JSON headers
        self.headers["Content-Type"]   = "application/json"
        self.headers["Content-Length"] = String(describing: responseSize)
        
        let awsHeaders: AWSLambdaEvents.HTTPHeaders = Dictionary(uniqueKeysWithValues: self.headers.map { ($0.name, $0.value) })
        
        promise.succeed(
            APIGateway.Response(
                statusCode: AWSLambdaEvents.HTTPResponseStatus(
                    code: UInt(status)
                ),
                headers: awsHeaders,
                multiValueHeaders: nil,
                body: responseString,
                isBase64Encoded: false
            )
        )
        return
    }
}



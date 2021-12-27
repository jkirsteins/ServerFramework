//
//  IncomingMessage.swift
//  
//
//  Created by Janis Kirsteins on 04/12/2021.
//

import NIO
import NIOHTTP1
import Logging
import ServerFramework

final class IncomingMessage {
    
    let logger = Logger.create(for: IncomingMessage.self)
    
    public let head   : HTTPRequestHead // <= from NIOHTTP1
    public var userInfo = [ String : Any ]()
    public let headers: HTTPHeaders
    public var buffer: ByteBuffer? = nil
    
    init(head: HTTPRequestHead) {
        self.head = head
        self.headers = head.headers
    }
    
    enum IncomingMessageError : Swift.Error {
        case invalidUrlInHead(_ uri: String)
        case unknownMethod(_ method: String)
    }
    
    func createRequest() throws -> HttpRequest {
        let method: HttpMethod
        switch(self.head.method) {
        case .GET:
            method = .get
        case .DELETE:
            method = .delete
        case .POST:
            method = .post
        case .PUT:
            method = .put
        case .HEAD:
            method = .head
        case .OPTIONS:
            method = .options
        default:
            throw IncomingMessageError.unknownMethod(self.head.method.rawValue)
        }
        
        let url: URL
        let host = head.headers["Host"].first ?? "localhost"
        
        let fallbackGuess = "http://\(host)\(head.uri)"
        if let urlCandidate = URL(head.uri) {
            url = urlCandidate
        } else if let urlCandidate_fallback = URL(fallbackGuess) {
            logger.warning("Using fallback URL detection")
            url = urlCandidate_fallback
        } else {
            logger.error("Could not determine URL from \(head.uri) and fallback \(fallbackGuess)")
            throw IncomingMessageError.invalidUrlInHead(head.uri)
        }
        
        logger.info("Processing \(String(describing: url))")
        
        let mappedHeaders = self.headers.map { HttpHeaderKeyValuePair(name: $0, value: $1) }
        return HttpRequest(headers: mappedHeaders, method: method, body: buffer, url: url)
    }
}

//
//  ServerResponse.swift
//  
//
//  Created by Janis Kirsteins on 04/12/2021.
//

import NIO
import NIOHTTP1
import Logging
import ExtrasJSON

import ServerFramework

open class NIOServerResponse : ResponseHandler {
    public var headers = HttpHeaders()
    
    public func setHeader(_ name: String, to value: String) {
        self.headers[name] = value
    }
    
    let logger = Logger.create(for: NIOServerResponse.self)
    
    public  var nioHeaders     = NIOHTTP1.HTTPHeaders()
    public  let channel        : Channel
    
    private var didWriteHeader = false
    private var didEnd         = false
    
    public init(channel: Channel) {
        self.channel = channel
    }
    
    
    /// Check whether we already wrote the response header.
    /// If not, do so.
    func flushHeader_nio(status: Int) {
        guard !didWriteHeader else { return } // done already
        didWriteHeader = true
        
        let head = NIOHTTP1.HTTPResponseHead(version: .init(major:1, minor:1),
                                             status: HTTPResponseStatus(statusCode: status), headers: nioHeaders)
        let part = NIOHTTP1.HTTPServerResponsePart.head(head)
        _ = channel.writeAndFlush(part).recover(self.handleError_nio)
    }
    
    func handleError_nio(_ error: Error) {
        self.logger.error("Unexpected error: \(error.localizedDescription)")
        if !didWriteHeader {
            flushHeader_nio(status: 500)
        }
        end_nio()
    }
    
    func end_nio() {
        guard !didEnd else { return }
        self.channel.eventLoop.execute {
            _ = self.channel.writeAndFlush(HTTPServerResponsePart.end(nil))
                .map { self.channel.close() }
        }
        didEnd = true
    }
    
    /// Send a Codable object as JSON to the client.
    public func json<T: Encodable>(_ model: T?, status: Int = 200) {
        // create a Data struct from the Codable object
        var responseBuffer: ByteBuffer
        let responseSize: Int
        do {
            let bytes = try XJSONEncoder().encode(model)
            responseSize = bytes.count
            
            responseBuffer = channel.allocator.buffer(capacity: responseSize)
            responseBuffer.writeBytes(bytes)
        }
        catch {
            self.logger.error("Failed to serialize response to a byte buffer: \(error.localizedDescription)")
            handleError_nio(error)
            return
        }
        
        // setup JSON headers
        self.headers["Content-Type"]   = "application/json"
        self.headers["Content-Length"] = String(describing: responseSize)
        
        // send the headers and the data
        flushHeader_nio(status: status)
        
        let part = HTTPServerResponsePart.body(.byteBuffer(responseBuffer))
        
        _ = channel.writeAndFlush(part)
            .recover(self.handleError_nio)
            .map(self.end_nio)
    }
}


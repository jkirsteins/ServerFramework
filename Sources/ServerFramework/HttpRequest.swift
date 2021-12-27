//
//  HttpRequest.swift
//  
//
//  Created by Janis Kirsteins on 20/12/2021.
//

import NIO
 
public struct HttpRequest
{
    public init(headers: HttpHeaders, method: HttpMethod, body: ByteBuffer?, url: URL) {
        self.headers = headers
        self.method = method
        self.body = body
        self.url = url
    }
    
    let headers: HttpHeaders
    let method: HttpMethod
    let body: ByteBuffer?
    let url: URL
    
    func queryItem(_ id: String) -> String? {
        return self.url.formParams.get(id)
    }
}


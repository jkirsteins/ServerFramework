//
//  HttpHeaderKeyValuePair.swift
//  
//
//  Created by Janis Kirsteins on 20/12/2021.
//

public struct HttpHeaderKeyValuePair : Encodable {
    public init(name: String, value: String) {
        self.name = name
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public let name: String
    public let value: String
}

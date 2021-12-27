//
//  HttpHeaders.swift
//  
//
//  Created by Janis Kirsteins on 20/12/2021.
//

public typealias HttpHeaders = [HttpHeaderKeyValuePair]

public extension HttpHeaders {
    subscript(_ name: String) -> String? {
        get {
            self.first(where: { $0.name == name })?.value
        }
        set(newValue) {
            self.removeAll(where: { $0.name == name })
            
            if let newValue = newValue {
                self.append(HttpHeaderKeyValuePair(name: name, value: newValue))
            }
        }
    }
}

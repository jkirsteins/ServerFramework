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
            return self.first(where: { $0.name.range(of: name, options: .caseInsensitive) != nil })?.value
        }
        set(newValue) {
            self.removeAll(where: { $0.name.range(of: name, options: .caseInsensitive) != nil })
            
            if let newValue = newValue {
                self.append(HttpHeaderKeyValuePair(name: name, value: newValue))
            }
        }
    }
}

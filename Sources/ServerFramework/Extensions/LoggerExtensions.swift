//
//  LoggerExtensions.swift
//  
//
//  Created by Janis Kirsteins on 27/12/2021.
//

import Logging

public extension Logger {
    static func create(for klass: Any, name: String? = nil, factory: ((String)->LogHandler)? = nil) -> Logger {
        let realName: String
        if let name = name {
            realName = "\(String(reflecting: klass))[\(name)]"
        } else {
            realName = String(reflecting: klass)
        }
        
        if let factory = factory {
            return Logger(label: realName, factory: factory)
        } else {
            return Logger(label: realName)
        }
    }
    
    func fatalAndDie(_ message: String) -> Never {
        self.critical(Logger.Message.init(stringLiteral: message))
        fatalError(message)
    }
}

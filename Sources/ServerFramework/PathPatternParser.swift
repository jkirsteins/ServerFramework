//
//  PathPatternParser.swift
//  
//
//  Created by Janis Kirsteins on 27/12/2021.
//

import Foundation

struct PathPatternParser {
    
    enum Error: Swift.Error, Equatable {
        case closeUnopened
        case doubleOpen
        case unterminatedVariable(name: String)
    }
    
    struct MatchResult {
        var successful: Bool {
            self.components != nil
        }
        let components: [String:String]?
    }
    
    let pattern: String
    
    enum PatternPart : Equatable {
        case literal(value: String)
        case variable(name: String)
    }
    
    let patternParts: [PatternPart]
    
    init(_ pattern: String) throws {
        self.pattern = pattern
        
        var parts: [PatternPart] = []
        
        var currentOpt: PatternPart? = nil
        
        for i in self.pattern {
            
            // No match?
            guard let current = currentOpt else {
                if i == "{" {
                    currentOpt = .variable(name: "")
                } else if i == "}" {
                    throw Error.closeUnopened
                } else {
                    currentOpt = .literal(value: String(i))
                }
                continue
            }
            
            switch(current) {
            case .variable(let name):
                guard i != "}" else {
                    parts.append(current)
                    currentOpt = nil
                    continue
                }
                guard i != "{" else {
                    throw Error.doubleOpen
                }
                currentOpt = .variable(name: name.appending(String(i)))
                break
            case .literal(let value):
                guard i != "}" else {
                    throw Error.closeUnopened
                }
                
                guard i != "{" else {
                    parts.append(current)
                    currentOpt = .variable(name: "")
                    continue
                }
                
                currentOpt = .literal(value: value.appending(String(i)))
                break
            }
        }
        
        if let current = currentOpt {
            switch(current) {
            case .variable(let name): throw Error.unterminatedVariable(name: name)
            case .literal(_): parts.append(current)
            }
        }
        
        self.patternParts = parts
    }
    
    struct VariableMatch {
        let startInPattern: String.Index
        let startIn: String.Index
        var endInPattern: String.Index?
        var name: String?
    }
    
    var currentVariable: VariableMatch?
    
    func match(against: String) -> MatchResult {
        var valueParts: [String] = []
        var keyParts: [String] = []
        
        var remainderCheck: String = against
        
        // {123}/abc/def
        // /abc/xxxxxxxx/abc/def
        
        for part in self.patternParts {
            switch (part) {
            case .variable(let name):
                keyParts.append(name)
                break
            case .literal(let expectedValue):
                guard
                    let substrRange = remainderCheck.range(of: expectedValue),
                    substrRange.lowerBound < remainderCheck.endIndex else {
                    return MatchResult(components: nil)
                }
                
                let valueBeforeLiteral = remainderCheck[..<substrRange.lowerBound]
                if !valueBeforeLiteral.isEmpty {
                    valueParts.append(String(valueBeforeLiteral))
                }
                
                remainderCheck = String(remainderCheck[substrRange.upperBound..<remainderCheck.endIndex])
            }
        }
        
        if !remainderCheck.isEmpty {
            valueParts.append(remainderCheck)
        }
        
        // Drop empty variables
        if keyParts.count > valueParts.count {
            keyParts = Array(keyParts[0..<valueParts.count])
        }
        
        guard keyParts.count == valueParts.count else {
            return MatchResult(components: nil)
        }
        
        let components = Dictionary(uniqueKeysWithValues: zip(keyParts, valueParts))
        
        return MatchResult(components: components)
    }
    
}

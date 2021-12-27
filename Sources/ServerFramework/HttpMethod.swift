//
//  HttpMethod.swift
//  
//
//  Created by Janis Kirsteins on 20/12/2021.
//

public enum HttpMethod
{
    case get
    case post
    case put
    case options
    case head
    case delete
    
    public static func parse(_ val: String) -> HttpMethod
    {
        switch(val.uppercased()) {
        case "GET": return .get
        case "POST": return .post
        case "PUT": return .put
        case "OPTIONS": return .options
        case "HEAD": return .head
        case "DELETE": return .delete
        default:
            fatalError("Unknown method \(val)")
        }
    }
}


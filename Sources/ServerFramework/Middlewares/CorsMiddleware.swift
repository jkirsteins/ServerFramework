//
//  CorsMiddleware.swift
//  
//
//  Created by Janis Kirsteins on 05/12/2021.
//

public func cors(allowOrigin origin: String)
-> Middleware
{
    return { req, res, _, next in
        res.setHeader("Access-Control-Allow-Origin", to: origin)
        res.setHeader("Access-Control-Allow-Headers", to: "Accept, Content-Type")
        res.setHeader("Access-Control-Allow-Methods", to: "GET, OPTIONS")
        
        // we handle the options
        if req.method == .options {
            res.setHeader("Allow", to: "GET, OPTIONS")
            res.empty()
        }
        else { // we set the proper headers
            try await next()
        }
    }
}

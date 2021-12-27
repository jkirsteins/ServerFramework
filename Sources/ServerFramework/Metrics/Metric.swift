//
//  File.swift
//  
//
//  Created by Janis Kirsteins on 27/12/2021.
//

public protocol Metric 
{
    var name: String { get }
    var extraDimensions: [(String, String)] { get }
}

public extension Metric {
    var extraDimensions: [(String, String)] {
        []
    }
}

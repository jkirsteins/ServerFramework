//
//  UserProvider.swift
//  
//
//  Created by Janis Kirsteins on 27/12/2021.
//

public protocol UserProvider
{
    func extract(from request: HttpRequest) async throws -> User?
}

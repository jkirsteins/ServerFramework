//
//  JWKSet.swift
//  
//
//  Created by Janis Kirsteins on 09/01/2022.
//

import Foundation

/// JWT keyset structure
public struct JWKSet : Codable
{
    public struct Key: Codable, CustomStringConvertible {
        public var description: String {
            "{alg: \(alg); e: \(e); kid: \(kid); kty: \(kty); n: \(n); use: \(use) }"
        }
        
        /// The encryption algorithm used to encrypt the token.
        public let alg: String
        
        /// The exponent value for the RSA public key.
        public let e: String
        
        /// A 10-character identifier key, obtained from your developer account.
        public let kid: String
        
        /// The key type parameter setting. You must set to "RSA".
        public let kty: String
        
        /// The modulus value for the RSA public key.
        public let n: String
        
        /// The intended use for the public key.
        public let use: String
    }
    
    public let keys: [Key]
}
